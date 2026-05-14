#!/usr/bin/env bash
set -euo pipefail

# vLLM Serve Script
# This script starts the vLLM server with the configured parameters.
# For distributed deployment, PD separation uses the following environment variables:
#   - ${MASTER_ADDR}: Master node address for distributed coordination
#   - ${MASTER_PORT}: Master node port for distributed coordination
#   - ${RANK}: Rank of this node in the distributed setup

vllm serve "${MODEL_PATH}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}"