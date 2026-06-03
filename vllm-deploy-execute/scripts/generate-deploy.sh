#!/bin/bash
set -euo pipefail

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' not found" >&2
        exit 1
    fi
}

require_cmd jq

CONFIG_FILE="${1:-.vllm-deploy/config.json}"
CONTAINER_DETECTION_FILE="${2:-.vllm-deploy/container-detection-result.json}"
OUTPUT_DIR="${3:-.vllm-deploy/k8s}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found at $CONFIG_FILE" >&2
    exit 1
fi

if [ ! -f "$CONTAINER_DETECTION_FILE" ]; then
    echo "Error: container-detection-result.json not found at $CONTAINER_DETECTION_FILE" >&2
    echo "Please run Phase 9 container NPU detection first" >&2
    exit 1
fi

DEPLOY_MODE=$(jq -r '.deploy_mode' "$CONFIG_FILE")
NAMESPACE=$(jq -r '.namespace' "$CONFIG_FILE")
MODEL_PATH=$(jq -r '.model_path' "$CONFIG_FILE")
MODEL_NAME=$(jq -r '.selected_model' "$CONFIG_FILE")
MAX_MODEL_LEN=$(jq -r '.max_model_len' "$CONFIG_FILE")
MAX_NUM_SEQS=$(jq -r '.max_num_seqs' "$CONFIG_FILE")

CONTAINER_NPU_COUNT=$(jq -r '.npu_count // 0' "$CONTAINER_DETECTION_FILE")

slugify_k8s_name() {
    local input="$1"
    printf '%s' "$input" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
        | cut -c1-63 \
        | sed -E 's/-+$//'
}

export MODEL_RESOURCE_NAME=$(slugify_k8s_name "$MODEL_NAME")
if [ -z "$MODEL_RESOURCE_NAME" ]; then
    echo "Error: selected_model '$MODEL_NAME' cannot be converted to a Kubernetes resource name" >&2
    exit 1
fi

if [ "$CONTAINER_NPU_COUNT" -le 0 ]; then
    echo "Error: container NPU count is 0 or missing in $CONTAINER_DETECTION_FILE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [ "$DEPLOY_MODE" = "single_node" ]; then
    cat <<EOF > "$OUTPUT_DIR/deploy.sh"
#!/bin/bash
set -e
echo "=== Starting vLLM Service ==="
vllm serve "${MODEL_PATH}" \
  --served-model-name "${MODEL_NAME}" \
  --tensor-parallel-size "${CONTAINER_NPU_COUNT}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --port 8000 \
  --trust-remote-code
EOF
    chmod +x "$OUTPUT_DIR/deploy.sh"
    echo "Generated: $OUTPUT_DIR/deploy.sh (tensor-parallel-size=$CONTAINER_NPU_COUNT from container detection)"

elif [ "$DEPLOY_MODE" = "multi_node" ]; then
    cat <<EOF > "$OUTPUT_DIR/deploy.sh"
#!/bin/bash
# vLLM 分布式部署脚本（多节点 Master 专用）
# Worker Pod 只通过容器启动命令加入 Ray 集群，不执行此脚本。
set -e
echo "=== Starting vLLM Service (Master) ==="
vllm serve "${MODEL_PATH}" \
  --served-model-name "${MODEL_NAME}" \
  --tensor-parallel-size "${CONTAINER_NPU_COUNT}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --distributed-executor-backend ray \
  --port 8000 \
  --trust-remote-code
EOF
    chmod +x "$OUTPUT_DIR/deploy.sh"
    echo "Generated: $OUTPUT_DIR/deploy.sh (tensor-parallel-size=$CONTAINER_NPU_COUNT from container detection)"
    echo "Note: deploy.sh is for Master Pod only. Worker Pods join the Ray cluster via ray start."

else
    echo "deploy_mode '$DEPLOY_MODE' does not require a separate deploy.sh (startup command is embedded in the template)"
fi
