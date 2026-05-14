#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# parse-model-doc.sh - Parse model documentation for deployment parameters
# =============================================================================
# This script fetches and parses a single model's documentation page
# to extract deployment parameters like hardware requirements, serving
# arguments, and supported features.
#
# Usage:
#   parse-model-doc.sh --url <model_doc_url> --hardware <spec> --mode <mode>
#   parse-model-doc.sh --help
#
# Output:
#   JSON object with deployment configuration
# =============================================================================

usage() {
  cat <<'EOF'
Usage: parse-model-doc.sh [OPTIONS]

Parse model documentation to extract deployment parameters.

Options:
  --url URL           Model documentation URL (required)
  --hardware SPEC     Hardware specification: npu, gpu, cpu (default: npu)
  --mode MODE         Deployment mode: k8s, docker, bare-metal (default: k8s)
  --output FILE       Write output to FILE instead of stdout
  --help              Show this help message

Hardware Specifications:
  npu         - Ascend NPU (default for vLLM-Ascend)
  gpu         - NVIDIA GPU (fallback)
  cpu         - CPU-only deployment

Deployment Modes:
  k8s         - Kubernetes deployment with resource limits
  docker      - Docker container deployment
  bare-metal  - Direct host deployment

Examples:
  parse-model-doc.sh --url https://vllm-ascend.readthedocs.io/en/latest/models/llama/
  parse-model-doc.sh --url https://example.com/model --hardware npu --mode k8s

Output Format (JSON):
  {
    "model": "model-name",
    "url": "https://...",
    "hardware": "npu",
    "mode": "k8s",
    "requirements": {
      "min_memory": "16Gi",
      "recommended_memory": "32Gi",
      "min_npu_count": 1,
      "recommended_npu_count": 2
    },
    "serving_args": {
      "tensor_parallel_size": 2,
      "max_model_len": 4096,
      "dtype": "auto"
    },
    "notes": ["Additional deployment notes..."]
  }

Exit Codes:
  0 - Success
  1 - Missing arguments or dependencies
  2 - Network or parsing error
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

log_info() {
  echo "[INFO] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

# Extract text between patterns
extract_section() {
  local content="$1"
  local start_pattern="$2"
  local end_pattern="$3"

  echo "$content" | sed -n "/$start_pattern/,/$end_pattern/p" | head -n -1 | tail -n +2
}

# Parse memory requirements from text
parse_memory() {
  local text="$1"
  local mem=""

  # Look for patterns like "16GB", "32 GiB", etc.
  mem=$(echo "$text" | grep -oiE '[0-9]+\s*(GB|GiB|Gi)' | head -1 | tr -d ' ')
  if [[ -n "$mem" ]]; then
    # Normalize to Gi format
    mem=$(echo "$mem" | sed 's/GB/Gi/g; s/GiB/Gi/g; s/Gi/Gi/g')
  fi
  echo "$mem"
}

# Parse NPU count from text
parse_npu_count() {
  local text="$1"
  local count=""

  # Look for patterns like "2 NPU", "1x NPU", etc.
  count=$(echo "$text" | grep -oiE '[0-9]+\s*(NPU|npu|Ascend|ascend)' | grep -oE '[0-9]+' | head -1)
  echo "${count:-1}"
}

# Parse serving arguments from documentation
parse_serving_args() {
  local content="$1"
  local args="{}"

  # Look for common vLLM arguments
  local tp_size
  tp_size=$(echo "$content" | grep -oiE 'tensor_parallel_size[=:\s]+[0-9]+' | grep -oE '[0-9]+' | head -1)

  local max_len
  max_len=$(echo "$content" | grep -oiE 'max_model_len[=:\s]+[0-9]+' | grep -oE '[0-9]+' | head -1)

  local dtype
  dtype=$(echo "$content" | grep -oiE 'dtype[=:\s]+[a-z_]+' | grep -oE '(auto|float16|bfloat16|float32)' | head -1)

  # Build JSON
  local parts=()
  [[ -n "$tp_size" ]] && parts+=("\"tensor_parallel_size\": $tp_size")
  [[ -n "$max_len" ]] && parts+=("\"max_model_len\": $max_len")
  [[ -n "$dtype" ]] && parts+=("\"dtype\": \"$dtype\"")

  if [[ ${#parts[@]} -gt 0 ]]; then
    args="{"
    args+=$(IFS=, ; echo "${parts[*]}")
    args+="}"
  fi

  echo "$args"
}

# Extract model name from URL
extract_model_name() {
  local url="$1"
  # Get last path segment, strip trailing slashes
  basename "$url" | sed 's/[?#].*//' | sed 's/\.[^.]*$//'
}

main() {
  local url=""
  local hardware="npu"
  local mode="k8s"
  local output_file=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        exit 0
        ;;
      --url)
        if [[ -z "${2:-}" ]]; then
          log_error "--url requires a URL argument"
          exit 1
        fi
        url="$2"
        shift 2
        ;;
      --hardware)
        if [[ -z "${2:-}" ]]; then
          log_error "--hardware requires a SPEC argument"
          exit 1
        fi
        hardware="$2"
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
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$url" ]]; then
    log_error "Missing required argument: --url"
    usage
    exit 1
  fi

  # Validate hardware specification
  case "$hardware" in
    npu|gpu|cpu) ;;
    *)
      log_error "Invalid hardware specification: $hardware (must be: npu, gpu, or cpu)"
      exit 1
      ;;
  esac

  # Validate deployment mode
  case "$mode" in
    k8s|docker|bare-metal) ;;
    *)
      log_error "Invalid deployment mode: $mode (must be: k8s, docker, or bare-metal)"
      exit 1
      ;;
  esac

  # Check for required commands
  require_cmd curl

  local model_name
  model_name=$(extract_model_name "$url")

  log_info "Parsing documentation for model: $model_name"
  log_info "Hardware: $hardware, Mode: $mode"
  log_info "Fetching from: $url"

  # Fetch the page
  local http_status
  local html_content

  http_status=$(curl -s -o /tmp/vllm-parse-$$.html -w "%{http_code}" -L "$url" 2>&1) || {
    log_error "Failed to fetch URL: $url"
    exit 2
  }

  if [[ "$http_status" != "200" ]]; then
    log_error "HTTP request failed with status: $http_status"
    rm -f /tmp/vllm-parse-$$.html
    exit 2
  fi

  html_content=$(cat /tmp/vllm-parse-$$.html)
  rm -f /tmp/vllm-parse-$$.html

  log_info "Extracting deployment parameters..."

  # Extract sections (convert HTML to plain text first)
  local text_content
  text_content=$(echo "$html_content" | sed 's/<[^>]*>/ /g' | tr -s ' \n')

  # Parse requirements
  local min_memory=""
  local rec_memory=""
  local min_npu=1
  local rec_npu=1

  # Look for memory requirements
  min_memory=$(parse_memory "$(echo "$text_content" | grep -i 'minimum\|min\|required' | head -5)")
  rec_memory=$(parse_memory "$(echo "$text_content" | grep -i 'recommended\|rec\|suggested' | head -5)")

  # Look for NPU requirements
  min_npu=$(parse_npu_count "$(echo "$text_content" | grep -i 'minimum\|min\|required' | head -5)")
  rec_npu=$(parse_npu_count "$(echo "$text_content" | grep -i 'recommended\|rec\|suggested' | head -5)")

  # Parse serving arguments
  local serving_args
  serving_args=$(parse_serving_args "$text_content")

  # Build output JSON
  local result
  result=$(cat <<EOF
{
  "model": "$model_name",
  "url": "$url",
  "hardware": "$hardware",
  "mode": "$mode",
  "requirements": {
    "min_memory": "${min_memory:-unknown}",
    "recommended_memory": "${rec_memory:-unknown}",
    "min_npu_count": $min_npu,
    "recommended_npu_count": $rec_npu
  },
  "serving_args": $serving_args,
  "notes": []
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
}

main "$@"