#!/bin/bash
# vLLM PD 分离 Decode 启动脚本（KV Consumer）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${DECODE_TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-${DECODE_MAX_TOKENS_PLACEHOLDER:-16384}}"

# ============ KV Transfer 配置 ============
KV_CONNECTOR="${KV_CONNECTOR:-MooncakeConnectorV1}"
KV_ROLE="kv_consumer"
KV_PORT="${KV_PORT:-20002}"
ENGINE_ID="${ENGINE_ID:-1}"
KV_RANK="${KV_RANK:-1}"
KV_PARALLEL_SIZE="${KV_PARALLEL_SIZE:-1}"

# Prefill 服务地址（Skill 2 探测填充）
PREFILL_ADDR="${PREFILL_ADDR:-${PREFILL_ADDR_PLACEHOLDER}}"
PREFILL_PORT="${PREFILL_PORT:-8100}"

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
echo "Starting vLLM Decode instance (KV Consumer)..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "KV Role: ${KV_ROLE}"
echo "KV Port: ${KV_PORT}"
echo "Prefill Addr: ${PREFILL_ADDR}:${PREFILL_PORT}"

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
    --gpu-memory-utilization 0.8 \
    --port 8200 \
    --trust-remote-code \
    --enforce-eager \
    --no-enable-prefix-caching \
    --kv-transfer-config "${KV_TRANSFER_CONFIG}"

echo "vLLM Decode service started on port 8200"