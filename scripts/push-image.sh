#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# push-image.sh - Docker image pull, tag, and push operations
# =============================================================================
# This script handles Docker image operations including login, pull,
# re-tag, and push to target registry.
#
# Usage:
#   push-image.sh --source-image IMAGE --target-image IMAGE [--docker-username USERNAME]
#   push-image.sh --help
#
# Output:
#   JSON object with operation results
# =============================================================================

usage() {
  cat <<'EOF'
Usage: push-image.sh [OPTIONS]

Pull, re-tag, and push Docker images to target registry.

Options:
  --source-image IMAGE    Source image to pull (required)
                         Example: quay.io/vllm-ascend/vllm-ascend:latest
  --target-image IMAGE    Target image to push (required)
                         Example: my-registry.example.com/vllm:v1.0.0
  --docker-username USER Docker registry username (optional, will prompt if needed)
  --docker-password PASS Docker registry password (optional, will prompt if not provided)
  --registry URL         Target registry URL (optional, extracted from target-image)
  --no-login             Skip docker login (assume already authenticated)
  --dry-run              Show what would be done without executing
  --output FILE          Write output to FILE instead of stdout
  --verbose              Show detailed information
  --help                 Show this help message

Examples:
  # Interactive login
  push-image.sh --source-image quay.io/vllm-ascend/vllm-ascend:latest \
                --target-image my-registry/vllm:v1.0.0

  # With username (will prompt for password)
  push-image.sh --source-image quay.io/vllm-ascend/vllm-ascend:latest \
                --target-image my-registry/vllm:v1.0.0 \
                --docker-username myuser

  # Skip login (already authenticated)
  push-image.sh --source-image quay.io/vllm-ascend/vllm-ascend:latest \
                --target-image my-registry/vllm:v1.0.0 \
                --no-login

Output Format (JSON):
  {
    "status": "success",
    "source_image": "quay.io/vllm-ascend/vllm-ascend:latest",
    "target_image": "my-registry/vllm:v1.0.0",
    "operations": {
      "pull": true,
      "tag": true,
      "push": true
    },
    "digest": "sha256:...",
    "size": "2.5GB"
  }

Exit Codes:
  0 - Success
  1 - Missing arguments or dependencies
  2 - Docker operation failed (pull/tag/push)
  3 - Authentication failed
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

# Extract registry from image name
extract_registry() {
  local image="$1"
  # If image has a registry prefix (contains / and the part before / has . or :)
  if [[ "$image" =~ ^([^/]+\.[^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$image" =~ ^([^/]+:)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    # Default to Docker Hub
    echo "docker.io"
  fi
}

# Check if image exists locally
image_exists_locally() {
  local image="$1"
  docker image inspect "$image" &>/dev/null
}

# Get image digest
get_image_digest() {
  local image="$1"
  docker image inspect "$image" --format '{{index .RepoDigests 0}}' 2>/dev/null || echo "unknown"
}

# Get image size
get_image_size() {
  local image="$1"
  local size_bytes
  size_bytes=$(docker image inspect "$image" --format '{{.Size}}' 2>/dev/null || echo "0")

  if [[ "$size_bytes" -gt 1073741824 ]]; then
    echo "$(echo "scale=1; $size_bytes / 1073741824" | bc)GB"
  elif [[ "$size_bytes" -gt 1048576 ]]; then
    echo "$(echo "scale=1; $size_bytes / 1048576" | bc)MB"
  elif [[ "$size_bytes" -gt 1024 ]]; then
    echo "$(echo "scale=1; $size_bytes / 1024" | bc)KB"
  else
    echo "${size_bytes}B"
  fi
}

main() {
  local source_image=""
  local target_image=""
  local docker_username=""
  local docker_password=""
  local registry=""
  local no_login="false"
  local dry_run="false"
  local output_file=""
  local verbose="false"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        exit 0
        ;;
      --source-image)
        if [[ -z "${2:-}" ]]; then
          log_error "--source-image requires an IMAGE argument"
          exit 1
        fi
        source_image="$2"
        shift 2
        ;;
      --target-image)
        if [[ -z "${2:-}" ]]; then
          log_error "--target-image requires an IMAGE argument"
          exit 1
        fi
        target_image="$2"
        shift 2
        ;;
      --docker-username)
        if [[ -z "${2:-}" ]]; then
          log_error "--docker-username requires a USERNAME argument"
          exit 1
        fi
        docker_username="$2"
        shift 2
        ;;
      --docker-password)
        if [[ -z "${2:-}" ]]; then
          log_error "--docker-password requires a PASSWORD argument"
          exit 1
        fi
        docker_password="$2"
        shift 2
        ;;
      --registry)
        if [[ -z "${2:-}" ]]; then
          log_error "--registry requires a URL argument"
          exit 1
        fi
        registry="$2"
        shift 2
        ;;
      --no-login)
        no_login="true"
        shift
        ;;
      --dry-run)
        dry_run="true"
        shift
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
  if [[ -z "$source_image" ]]; then
    log_error "Missing required argument: --source-image"
    usage
    exit 1
  fi

  if [[ -z "$target_image" ]]; then
    log_error "Missing required argument: --target-image"
    usage
    exit 1
  fi

  # Check for required commands
  require_cmd docker

  # Extract registry from target image if not provided
  if [[ -z "$registry" ]]; then
    registry=$(extract_registry "$target_image")
  fi

  log_info "Source image: $source_image"
  log_info "Target image: $target_image"
  log_info "Target registry: $registry"

  local pull_success="false"
  local tag_success="false"
  local push_success="false"
  local digest="unknown"
  local size="unknown"

  # Docker login
  if [[ "$no_login" == "false" ]]; then
    if [[ -n "$docker_username" ]]; then
      log_info "Logging in to registry: $registry"
      if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] Would run: docker login -u *** $registry"
      else
        if [[ -n "$docker_password" ]]; then
          if ! echo "$docker_password" | docker login -u "$docker_username" --password-stdin "$registry" 2>&1; then
            log_error "Docker login failed"
            exit 3
          fi
        else
          if ! docker login -u "$docker_username" "$registry" 2>&1; then
            log_error "Docker login failed"
            exit 3
          fi
        fi
      fi
    else
      log_info "No username provided, skipping login (assuming already authenticated)"
    fi
  else
    log_info "Skipping login (--no-login specified)"
  fi

  # Pull source image
  log_info "Pulling source image: $source_image"
  if [[ "$dry_run" == "true" ]]; then
    log_info "[DRY-RUN] Would run: docker pull $source_image"
    pull_success="true"
  else
    if docker pull "$source_image" 2>&1; then
      pull_success="true"
    else
      log_error "Failed to pull source image: $source_image"
    fi
  fi

  # Tag image
  if [[ "$pull_success" == "true" ]]; then
    log_info "Tagging image: $source_image -> $target_image"
    if [[ "$dry_run" == "true" ]]; then
      log_info "[DRY-RUN] Would run: docker tag $source_image $target_image"
      tag_success="true"
    else
      if docker tag "$source_image" "$target_image" 2>&1; then
        tag_success="true"
      else
        log_error "Failed to tag image"
      fi
    fi
  fi

  # Push target image
  if [[ "$tag_success" == "true" ]]; then
    log_info "Pushing target image: $target_image"
    if [[ "$dry_run" == "true" ]]; then
      log_info "[DRY-RUN] Would run: docker push $target_image"
      push_success="true"
    else
      if docker push "$target_image" 2>&1; then
        push_success="true"
        digest=$(get_image_digest "$target_image")
        size=$(get_image_size "$target_image")
      else
        log_error "Failed to push target image: $target_image"
      fi
    fi
  fi

  # Build result
  local status="success"
  if [[ "$push_success" != "true" ]]; then
    status="failed"
  fi

  local result
  result=$(cat <<EOF
{
  "status": "$status",
  "source_image": "$source_image",
  "target_image": "$target_image",
  "registry": "$registry",
  "dry_run": $dry_run,
  "operations": {
    "pull": $pull_success,
    "tag": $tag_success,
    "push": $push_success
  },
  "digest": "$digest",
  "size": "$size"
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
  if [[ "$status" == "failed" ]]; then
    exit 2
  fi
}

main "$@"