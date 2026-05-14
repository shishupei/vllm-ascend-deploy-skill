#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# detect-k8s-env.sh - Detect Kubernetes environment information
# =============================================================================
# This script inspects the Kubernetes environment including cluster
# connectivity, node information, IP addresses, and NPU-related resources.
#
# Usage:
#   detect-k8s-env.sh [--namespace NAMESPACE]
#   detect-k8s-env.sh --help
#
# Output:
#   JSON object with cluster and node information
# =============================================================================

usage() {
  cat <<'EOF'
Usage: detect-k8s-env.sh [OPTIONS]

Detect and report Kubernetes environment information.

Options:
  --namespace NAMESPACE   Kubernetes namespace to inspect (default: default)
  --output FILE          Write output to FILE instead of stdout
  --check-npu            Check for NPU-related resources (devices, drivers)
  --verbose              Show detailed information
  --help                 Show this help message

Examples:
  detect-k8s-env.sh
  detect-k8s-env.sh --namespace kube-system
  detect-k8s-env.sh --check-npu --verbose

Output Format (JSON):
  {
    "kubectl": {
      "available": true,
      "version": "v1.28.0",
      "context": "my-cluster"
    },
    "cluster": {
      "reachable": true,
      "server": "https://10.0.0.1:6443",
      "version": "v1.28.0"
    },
    "nodes": [
      {
        "name": "node-1",
        "status": "Ready",
        "ips": ["10.0.0.1", "192.168.1.1"],
        "npus": 2
      }
    ],
    "npu_resources": {
      "available": true,
      "device_plugin": "ascend",
      "total_npus": 4
    }
  }

Exit Codes:
  0 - Success
  1 - Missing dependencies
  2 - Cluster not reachable
  3 - Permission denied
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

log_info() {
  if [[ "${verbose:-false}" == "true" ]]; then
    echo "[INFO] $*" >&2
  fi
}

log_error() {
  echo "[ERROR] $*" >&2
}

# Check if kubectl is available
check_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    local version
    version=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | sed 's/"gitVersion":"//;s/"//')
    local context
    context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    printf '{"available":true,"version":"%s","context":"%s"}' "$version" "$context"
  else
    printf '{"available":false,"version":"unknown","context":"unknown"}'
  fi
}

# Check cluster connectivity
check_cluster() {
  if ! command -v kubectl >/dev/null 2>&1; then
    printf '{"reachable":false,"server":"unknown","version":"unknown"}'
    return
  fi

  local server
  server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "unknown")

  if kubectl cluster-info &>/dev/null; then
    local version
    version=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | sed 's/"gitVersion":"//;s/"//')
    printf '{"reachable":true,"server":"%s","version":"%s"}' "$server" "$version"
  else
    printf '{"reachable":false,"server":"%s","version":"unknown"}' "$server"
  fi
}

# Get node information
get_nodes() {
  if ! command -v kubectl >/dev/null 2>&1; then
    printf '[]'
    return
  fi

  local nodes_json
  nodes_json=$(kubectl get nodes -o json 2>/dev/null || echo '{"items":[]}')

  echo "$nodes_json" | jq -c '.items[] | {
    name: .metadata.name,
    status: (.status.conditions[] | select(.type == "Ready") | .status),
    ips: [.status.addresses[] | .address],
    npus: ((.status.capacity["npu.com/ascend"] // .status.capacity["ascend.knp.khulnasoft.com/npu"] // "0") | tonumber? // 0)
  }' 2>/dev/null || printf '[]'
}

# Check for NPU resources
check_npu_resources() {
  if [[ "${check_npu:-false}" != "true" ]]; then
    printf '{"available":false,"device_plugin":"unknown","total_npus":0}'
    return
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    printf '{"available":false,"device_plugin":"unknown","total_npus":0}'
    return
  fi

  local total_npus=0
  local device_plugin="none"

  # Check for Ascend device plugin
  if kubectl get ds -n kube-system -o name 2>/dev/null | grep -q ascend; then
    device_plugin="ascend"
  fi

  # Count total NPUs across nodes
  total_npus=$(kubectl get nodes -o json 2>/dev/null | jq '[.items[].status.capacity["npu.com/ascend"] // .items[].status.capacity["ascend.knp.khulnasoft.com/npu"] // "0" | tonumber? // 0] | add // 0' 2>/dev/null || echo "0")

  if [[ "$total_npus" -gt 0 ]]; then
    printf '{"available":true,"device_plugin":"%s","total_npus":%d}' "$device_plugin" "$total_npus"
  else
    printf '{"available":false,"device_plugin":"%s","total_npus":0}' "$device_plugin"
  fi
}

main() {
  local namespace="default"
  local output_file=""
  local verbose="false"
  local check_npu="false"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        exit 0
        ;;
      --namespace)
        if [[ -z "${2:-}" ]]; then
          log_error "--namespace requires a NAMESPACE argument"
          exit 1
        fi
        namespace="$2"
        shift 2
        ;;
      --output)
        if [[ -z "${2:-}" ]]; then
          log_error "--output requires a FILE argument"
          exit 1
        fi
        output_file="$2"
        shift 2
        ;;
      --check-npu)
        check_npu="true"
        shift
        ;;
      --verbose)
        verbose="true"
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Check for required commands
  require_cmd kubectl
  require_cmd jq

  log_info "Detecting Kubernetes environment..."
  log_info "Namespace: $namespace"

  # Gather information
  local kubectl_info
  kubectl_info=$(check_kubectl)

  local cluster_info
  cluster_info=$(check_cluster)

  if echo "$cluster_info" | grep -q '"reachable":false'; then
    log_error "Cluster is not reachable"
    # Still output partial results
  fi

  local nodes_info
  nodes_info=$(get_nodes | jq -s '.')

  local npu_info
  npu_info=$(check_npu_resources)

  # Build output JSON
  local result
  result=$(cat <<EOF
{
  "kubectl": $kubectl_info,
  "cluster": $cluster_info,
  "namespace": "$namespace",
  "nodes": $nodes_info,
  "npu_resources": $npu_info
}
EOF
)

  # Output to file or stdout
  if [[ -n "$output_file" ]]; then
    echo "$result" > "$output_file"
    log_info "Output written to: $output_file"
  else
    echo "$result"
  fi

  log_info "Done."

  # Return appropriate exit code
  if echo "$cluster_info" | grep -q '"reachable":false'; then
    exit 2
  fi
}

main "$@"