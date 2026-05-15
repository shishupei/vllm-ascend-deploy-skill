#!/bin/bash
# vLLM 多机分布式 Worker 启动脚本（Rank 1-N）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-256}"

# ============ 分布式配置（Skill 2 探测填充）============
RANK="${RANK:-${WORKER_RANK_PLACEHOLDER}}"        # Worker Rank 编号
WORLD_SIZE="${WORLD_SIZE:-${WORLD_SIZE_PLACEHOLDER}}"
MASTER_ADDR="${MASTER_ADDR:-${MASTER_ADDR_PLACEHOLDER}}"  # Master 节点 IP
MASTER_PORT="${MASTER_PORT:-29500}"

# ============ 网络配置（Skill 2 探测填充）============
HCCL_IF_IP="${HCCL_IF_IP:-${NODE_IP_PLACEHOLDER}}"  # 本节点 IP
GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"
TP_SOCKET_IFNAME="${TP_SOCKET_IFNAME:-eth0}"

# 导出环境变量
export HCCL_IF_IP
export GLOO_SOCKET_IFNAME
export TP_SOCKET_IFNAME
export RANK
export WORLD_SIZE
export MASTER_ADDR
export MASTER_PORT

# ============ Ray Worker 连接到 Head ============
echo "Connecting to Ray cluster at ${MASTER_ADDR}:${MASTER_PORT}..." >&2
ray start --address=${MASTER_ADDR}:${MASTER_PORT} --node-ip-address=${HCCL_IF_IP}

# 等待连接稳定
sleep 3

# ============ 启动 vLLM Worker ============
echo "Starting vLLM serve as Worker (Rank ${RANK})..." >&2
echo "Model: ${MODEL_PATH}" >&2
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}" >&2
echo "World Size: ${WORLD_SIZE}" >&2
echo "Master Addr: ${MASTER_ADDR}" >&2
echo "Connecting to Master..." >&2

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --distributed-executor-backend ray \
    --port 8000 \
    --trust-remote-code

echo "vLLM Worker service started (Rank ${RANK})" >&2