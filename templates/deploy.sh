#!/bin/bash

# vLLM serve 启动脚本模板
# 在 Pod 内执行

set -e

MODEL_PATH="${MODEL_PATH}"
MAX_MODEL_LEN="${MAX_MODEL_LEN}"
MAX_NUM_SEQS="${MAX_NUM_SEQS}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE}"
MASTER_ADDR="${MASTER_ADDR}"
MASTER_PORT="${MASTER_PORT}"
RANK="${RANK}"

# 构建 vllm serve 命令
CMD="vllm serve ${MODEL_PATH}"
CMD="${CMD} --tensor-parallel-size ${TENSOR_PARALLEL_SIZE}"
CMD="${CMD} --max-model-len ${MAX_MODEL_LEN}"
CMD="${CMD} --max-num-seqs ${MAX_NUM_SEQS}"
CMD="${CMD} --trust-remote-code"

# 多节点分布式配置（如有）
if [ -n "${MASTER_ADDR}" ]; then
    CMD="${CMD} --master-addr ${MASTER_ADDR}"
fi
if [ -n "${MASTER_PORT}" ]; then
    CMD="${CMD} --master-port ${MASTER_PORT}"
fi
if [ -n "${RANK}" ]; then
    CMD="${CMD} --rank ${RANK}"
fi

echo "Starting vLLM with command: ${CMD}"
exec ${CMD}