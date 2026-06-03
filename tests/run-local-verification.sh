#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/vllm-deploy-skill-tests"

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing command: $cmd" >&2
        exit 1
    fi
}

prepare_case() {
    local case_name="$1"
    local case_dir="$TMP_ROOT/$case_name"

    rm -rf "$case_dir"
    mkdir -p "$case_dir/.vllm-deploy/templates" "$case_dir/.vllm-deploy/k8s"
    cp "$ROOT_DIR/tests/fixtures/$case_name/config.json" "$case_dir/.vllm-deploy/config.json"
    cp "$ROOT_DIR/tests/fixtures/$case_name/detection-result.json" "$case_dir/.vllm-deploy/detection-result.json"
    cp "$ROOT_DIR/tests/fixtures/$case_name/selected-nodes.json" "$case_dir/.vllm-deploy/selected-nodes.json"
    cp "$ROOT_DIR/tests/fixtures/$case_name/container-detection-result.json" "$case_dir/.vllm-deploy/container-detection-result.json"
    cp "$ROOT_DIR"/vllm-deploy-prepare/templates/*.yaml "$case_dir/.vllm-deploy/templates/"

    echo "$case_dir"
}

run_case() {
    local case_name="$1"
    local case_dir
    case_dir="$(prepare_case "$case_name")"

    echo "== $case_name =="
    (
        cd "$case_dir"
        bash "$ROOT_DIR/vllm-deploy-execute/scripts/fill-template.sh" \
            .vllm-deploy/config.json \
            .vllm-deploy/detection-result.json \
            .vllm-deploy/selected-nodes.json \
            .vllm-deploy/k8s
        bash "$ROOT_DIR/vllm-deploy-execute/scripts/generate-deploy.sh" \
            .vllm-deploy/config.json \
            .vllm-deploy/container-detection-result.json \
            .vllm-deploy/k8s
        bash "$ROOT_DIR/vllm-deploy-execute/scripts/validate-generated.sh" \
            .vllm-deploy/config.json \
            .vllm-deploy/k8s
    )
}

require_cmd jq
require_cmd envsubst

run_case single-node
run_case multi-node

echo "local verification passed"