#!/bin/bash
# vLLM 单机启动脚本
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
# 手动输入时可预先填充，Skill 2 探测时用占位符

MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-256}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.9}"

# ============ 服务端口配置 ============
SERVICE_PORT="${SERVICE_PORT:-8000}"

# ============ 可选参数 ============
TRUST_REMOTE_CODE="${TRUST_REMOTE_CODE:-true}"
ENFORCE_EAGER="${ENFORCE_EAGER:-false}"

# ============ 启动命令构建 ============
echo "Starting vLLM serve on single node..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "Max Model Len: ${MAX_MODEL_LEN}"
echo "Max Num Seqs: ${MAX_NUM_SEQS}"

TRUST_REMOTE_CODE_FLAG=""
if [ "${TRUST_REMOTE_CODE}" = "true" ]; then
    TRUST_REMOTE_CODE_FLAG="--trust-remote-code"
fi

ENFORCE_EAGER_FLAG=""
if [ "${ENFORCE_EAGER}" = "true" ]; then
    ENFORCE_EAGER_FLAG="--enforce-eager"
fi

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
    --port "${SERVICE_PORT}" \
    ${TRUST_REMOTE_CODE_FLAG} \
    ${ENFORCE_EAGER_FLAG}

echo "vLLM service started on port ${SERVICE_PORT}"