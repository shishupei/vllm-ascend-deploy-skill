#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# detect-container-npu.sh - Detect NPU devices in a container/Pod
# =============================================================================
# This script inspects NPU device mapping inside a Kubernetes Pod
# or Docker container.
#
# Usage:
#   detect-container-npu.sh --namespace NAMESPACE --pod POD [--container CONTAINER]
#   detect-container-npu.sh --help
#
# Output:
#   JSON object with NPU device information
# =============================================================================

usage() {
  cat <<'EOF'
Usage: detect-container-npu.sh [OPTIONS]

Detect NPU devices mapped to a container/Pod.

Options:
  --namespace NAMESPACE   Kubernetes namespace (required for k8s mode)
  --pod POD               Pod name to inspect (required)
  --container CONTAINER   Container name (optional, uses first container if not specified)
  --mode MODE             Inspection mode: k8s (default), docker
  --output FILE           Write output to FILE instead of stdout
  --verbose               Show detailed information
  --help                  Show this help message

Kubernetes Mode:
  Uses kubectl exec to inspect devices inside the Pod.

  Example:
    detect-container-npu.sh --namespace vllm --pod llama-7b-server-0

Docker Mode:
  Uses docker exec to inspect devices inside the container.

  Example:
    detect-container-npu.sh --mode docker --pod llama-7b-container

Output Format (JSON):
  {
    "mode": "k8s",
    "namespace": "vllm",
    "pod": "llama-7b-server-0",
    "container": "vllm",
    "devices": {
      "npu_available": true,
      "npu_count": 2,
      "npu_devices": ["/dev/davinci0", "/dev/davinci1"],
      "device_files": ["/dev/davinci0", "/dev/davinci1", "/dev/dvpp0", "/dev/dvpp1"],
      "driver_version": "23.0.0"
    },
    "environment": {
      "ASCEND_DEVICE_ID": "0",
      "NPU_NUM": "2"
    }
  }

Exit Codes:
  0 - Success
  1 - Missing arguments or dependencies
  2 - Pod/container not found
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

# Detect NPU devices by checking common device files
detect_npu_devices() {
  local exec_cmd="$1"

  # List of common NPU device patterns
  local npu_devices=()
  local all_devices=()

  # Check for davinci devices (Ascend NPU)
  while IFS= read -r device; do
    if [[ -n "$device" ]]; then
      all_devices+=("$device")
      if [[ "$device" =~ davinci ]]; then
        npu_devices+=("$device")
      fi
    fi
  done < <($exec_cmd ls -1 /dev/davinci* /dev/dvpp* /dev/hisi_hdc* 2>/dev/null || true)

  local npu_count=${#npu_devices[@]}
  local all_count=${#all_devices[@]}

  printf '{"npu_available":%s,"npu_count":%d,"npu_devices":%s,"device_files":%s}' \
    "$([ "$npu_count" -gt 0 ] && echo 'true' || echo 'false')" \
    "$npu_count" \
    "$(printf '%s\n' "${npu_devices[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')" \
    "$(printf '%s\n' "${all_devices[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')"
}

# Get driver version
get_driver_version() {
  local exec_cmd="$1"

  # Try to get NPU driver version
  local version
  version=$($exec_cmd cat /usr/local/Ascend/version.info 2>/dev/null | grep -i version | head -1 | awk '{print $NF}' || echo "unknown")

  if [[ "$version" == "unknown" ]]; then
    # Alternative: check npu-smi
    version=$($exec_cmd npu-smi info 2>/dev/null | grep -i version | head -1 | awk '{print $NF}' || echo "unknown")
  fi

  echo "$version"
}

# Get NPU-related environment variables
get_npu_env() {
  local exec_cmd="$1"

  local env_vars
  env_vars=$($exec_cmd env 2>/dev/null | grep -iE '(npu|ascend|davinci|huawei)' || true)

  if [[ -n "$env_vars" ]]; then
    echo "$env_vars" | jq -Rs 'split("\n") | map(select(length > 0)) | map(split("=")) | map({(.[0]): .[1]}) | add // {}' 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

# Kubernetes mode detection
detect_k8s() {
  local namespace="$1"
  local pod="$2"
  local container="$3"

  # Build kubectl exec command
  local exec_cmd="kubectl exec -n $namespace"
  if [[ -n "$container" ]]; then
    exec_cmd="$exec_cmd -c $container"
  fi
  exec_cmd="$exec_cmd $pod --"

  log_info "Checking Pod: $namespace/$pod"
  if [[ -n "$container" ]]; then
    log_info "Container: $container"
  fi

  # Check if pod exists
  if ! kubectl get pod -n "$namespace" "$pod" &>/dev/null; then
    log_error "Pod not found: $namespace/$pod"
    exit 2
  fi

  # Detect devices
  local devices
  devices=$(detect_npu_devices "$exec_cmd")

  local driver_version
  driver_version=$(get_driver_version "$exec_cmd")

  local env_info
  env_info=$(get_npu_env "$exec_cmd")

  # Build result
  printf '{
    "mode": "k8s",
    "namespace": "%s",
    "pod": "%s",
    "container": "%s",
    "devices": %s,
    "driver_version": "%s",
    "environment": %s
  }' "$namespace" "$pod" "${container:-}" "$devices" "$driver_version" "$env_info"
}

# Docker mode detection
detect_docker() {
  local container="$1"

  # Build docker exec command
  local exec_cmd="docker exec $container"

  log_info "Checking container: $container"

  # Check if container exists
  if ! docker inspect "$container" &>/dev/null; then
    log_error "Container not found: $container"
    exit 2
  fi

  # Detect devices
  local devices
  devices=$(detect_npu_devices "$exec_cmd")

  local driver_version
  driver_version=$(get_driver_version "$exec_cmd")

  local env_info
  env_info=$(get_npu_env "$exec_cmd")

  # Build result
  printf '{
    "mode": "docker",
    "container": "%s",
    "devices": %s,
    "driver_version": "%s",
    "environment": %s
  }' "$container" "$devices" "$driver_version" "$env_info"
}

main() {
  local namespace=""
  local pod=""
  local container=""
  local mode="k8s"
  local output_file=""
  local verbose="false"

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
      --pod)
        if [[ -z "${2:-}" ]]; then
          log_error "--pod requires a POD argument"
          exit 1
        fi
        pod="$2"
        shift 2
        ;;
      --container)
        if [[ -z "${2:-}" ]]; then
          log_error "--container requires a CONTAINER argument"
          exit 1
        fi
        container="$2"
        shift 2
        ;;
      --mode)
        if [[ -z "${2:-}" ]]; then
          log_error "--mode requires a MODE argument"
          exit 1
        fi
        mode="$2"
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

  # Validate required arguments
  if [[ -z "$pod" ]]; then
    log_error "Missing required argument: --pod"
    usage
    exit 1
  fi

  # Validate mode
  case "$mode" in
    k8s|docker) ;;
    *)
      log_error "Invalid mode: $mode (must be: k8s or docker)"
      exit 1
      ;;
  esac

  # For k8s mode, namespace is required
  if [[ "$mode" == "k8s" && -z "$namespace" ]]; then
    log_error "Missing required argument for k8s mode: --namespace"
    usage
    exit 1
  fi

  # Check for required commands
  if [[ "$mode" == "k8s" ]]; then
    require_cmd kubectl
  else
    require_cmd docker
  fi
  require_cmd jq

  local result

  if [[ "$mode" == "k8s" ]]; then
    result=$(detect_k8s "$namespace" "$pod" "$container")
  else
    result=$(detect_docker "$pod")
  fi

  # Output to file or stdout
  if [[ -n "$output_file" ]]; then
    echo "$result" > "$output_file"
    log_info "Output written to: $output_file"
  else
    echo "$result"
  fi

  log_info "Done."
}

main "$@"