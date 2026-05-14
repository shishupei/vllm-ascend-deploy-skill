#!/usr/bin/env bash
set -euo pipefail

# vLLM Serve Script
# This script starts the vLLM server with the configured parameters.
# For distributed deployment (PD separation), the following environment variables are used:
#   - ${MASTER_ADDR}: Master node address for distributed coordination
#   - ${MASTER_PORT}: Master node port for distributed coordination
#   - ${RANK}: Rank of this node in the distributed setup

# Distributed deployment parameters (set these for multi-node setups)
MASTER_ADDR="${MASTER_ADDR:-}"
MASTER_PORT="${MASTER_PORT:-}"
RANK="${RANK:-}"

# Build vllm serve command with distributed parameters if configured
if [[ -n "${MASTER_ADDR}" && -n "${MASTER_PORT}" ]]; then
  vllm serve "${MODEL_PATH}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --distributed-executor-backend ray \
    --pipeline-parallel-size "${PIPELINE_PARALLEL_SIZE:-1}"
else
  vllm serve "${MODEL_PATH}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}"
fi