#!/bin/bash
# vLLM PD 分离 Prefill 启动脚本（KV Producer）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${PREFILL_TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-${MAX_MODEL_LEN}}"

# ============ KV Transfer 配置 ============
KV_CONNECTOR="${KV_CONNECTOR:-MooncakeConnectorV1}"
KV_ROLE="kv_producer"
KV_PORT="${KV_PORT:-20001}"
ENGINE_ID="${ENGINE_ID:-0}"
KV_RANK="${KV_RANK:-0}"
KV_PARALLEL_SIZE="${KV_PARALLEL_SIZE:-1}"

# ============ 网络配置（Skill 2 探测填充）============
HCCL_IF_IP="${HCCL_IF_IP:-${NODE_IP_PLACEHOLDER}}"
GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"

export HCCL_IF_IP
export GLOO_SOCKET_IFNAME

# ============ 构建 KV Transfer Config ============
KV_TRANSFER_CONFIG=$(cat <<EOF
{
    "kv_connector": "${KV_CONNECTOR}",
    "kv_buffer_device": "npu",
    "kv_role": "${KV_ROLE}",
    "kv_parallel_size": ${KV_PARALLEL_SIZE},
    "kv_port": "${KV_PORT}",
    "engine_id": "${ENGINE_ID}",
    "kv_rank": ${KV_RANK}
}
EOF
)

# ============ 启动命令构建 ============
echo "Starting vLLM Prefill instance (KV Producer)..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "KV Role: ${KV_ROLE}"
echo "KV Port: ${KV_PORT}"

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
    --gpu-memory-utilization 0.8 \
    --port 8100 \
    --trust-remote-code \
    --enforce-eager \
    --kv-transfer-config "${KV_TRANSFER_CONFIG}"

echo "vLLM Prefill service started on port 8100"