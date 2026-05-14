#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# fetch-model-list.sh - Extract model list from vLLM-Ascend documentation
# =============================================================================
# This script fetches the model list from vLLM-Ascend documentation pages
# and outputs structured JSON with model names and URLs.
#
# Usage:
#   fetch-model-list.sh --url <documentation_url>
#   fetch-model-list.sh --help
#
# Output:
#   JSON array with objects containing: name, href, description
# =============================================================================

usage() {
  cat <<'EOF'
Usage: fetch-model-list.sh [OPTIONS]

Extract model list from vLLM-Ascend documentation pages.

Options:
  --url URL           Documentation URL to fetch model list from
                      (e.g., https://vllm-ascend.readthedocs.io/en/latest/supported_models/)
  --output FILE       Write output to FILE instead of stdout
  --format FORMAT     Output format: json (default), plain
  --help              Show this help message

Examples:
  fetch-model-list.sh --url https://vllm-ascend.readthedocs.io/en/latest/supported_models/
  fetch-model-list.sh --url https://example.com/models --output models.json

Output Format (JSON):
  [
    {
      "name": "Model Name",
      "href": "/path/to/model/doc",
      "url": "https://full.url/to/model/doc",
      "description": "Brief description"
    }
  ]

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

# Parse HTML and extract model entries
# Looks for anchor tags within model list sections
parse_model_entries() {
  local html_content="$1"
  local base_url="$2"

  # Extract anchor tags that appear to be model references
  # Pattern: look for links in typical documentation structures
  echo "$html_content" | grep -oP '<a[^>]*href="[^"]*"[^>]*>[^<]*</a>' | while read -r anchor; do
    # Extract href
    href=$(echo "$anchor" | sed -n 's/.*href="\([^"]*\)".*/\1/p')
    # Extract text
    text=$(echo "$anchor" | sed 's/<[^>]*>//g' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Filter for model-like entries (skip navigation, etc.)
    if [[ -n "$text" && -n "$href" && ! "$href" =~ ^# && ! "$href" =~ ^javascript: ]]; then
      # Build full URL
      if [[ "$href" =~ ^https?:// ]]; then
        full_url="$href"
      else
        # Handle relative URLs
        full_url="${base_url%/}/$href"
      fi

      # Output as JSON-like format
      printf '{"name":"%s","href":"%s","url":"%s"}\n' \
        "$(echo "$text" | sed 's/"/\\"/g')" \
        "$(echo "$href" | sed 's/"/\\"/g')" \
        "$(echo "$full_url" | sed 's/"/\\"/g')"
    fi
  done
}

# Output as JSON array
output_json_array() {
  local entries=()
  while IFS= read -r line; do
    entries+=("$line")
  done

  if [[ ${#entries[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi

  echo "["
  for i in "${!entries[@]}"; do
    if [[ $i -lt $((${#entries[@]} - 1)) ]]; then
      echo "  ${entries[$i]},"
    else
      echo "  ${entries[$i]}"
    fi
  done
  echo "]"
}

main() {
  local url=""
  local output_file=""
  local format="json"

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
      --output)
        if [[ -z "${2:-}" ]]; then
          log_error "--output requires a FILE argument"
          exit 1
        fi
        output_file="$2"
        shift 2
        ;;
      --format)
        if [[ -z "${2:-}" ]]; then
          log_error "--format requires a FORMAT argument"
          exit 1
        fi
        format="$2"
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

  # Check for required commands
  require_cmd curl
  require_cmd grep

  log_info "Fetching model list from: $url"

  # Fetch the page
  local http_status
  local html_content

  http_status=$(curl -s -o /tmp/vllm-fetch-$$.html -w "%{http_code}" -L "$url" 2>&1) || {
    log_error "Failed to fetch URL: $url"
    exit 2
  }

  if [[ "$http_status" != "200" ]]; then
    log_error "HTTP request failed with status: $http_status"
    rm -f /tmp/vllm-fetch-$$.html
    exit 2
  fi

  html_content=$(cat /tmp/vllm-fetch-$$.html)
  rm -f /tmp/vllm-fetch-$$.html

  log_info "Parsing model entries..."

  # Parse and output
  local result
  if [[ "$format" == "json" ]]; then
    result=$(parse_model_entries "$html_content" "$url" | output_json_array)
  else
    result=$(parse_model_entries "$html_content" "$url")
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