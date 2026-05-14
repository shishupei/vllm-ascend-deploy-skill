# Phase 10: 生成部署脚本

## 目的
根据容器内探测的 NPU 数量生成 Pod 内执行的 `deploy.sh` 脚本，配置正确的 tensor-parallel-size 和其他启动参数。

## 输入
- Phase 9 容器内探测结果（NPU 数量、设备编号）
- Phase 6 用户配置参数

## 执行位置
- 管理节点或本地终端

## 步骤
1. 读取容器内 NPU 数量（从 Phase 9 结果）
2. 计算 tensor-parallel-size：
   - 单节点部署：`tensor_parallel_size = container_npu_count`
   - 多节点部署：`tensor_parallel_size = total_npu_count / node_count`
   - PD分离部署：分别计算 Prefill 和 Decode 节点的 tensor_parallel_size
3. 从 `templates/deploy.sh` 读取脚本模板
4. 替换模板中的占位符：
   - `${MODEL_PATH}` → 用户配置的模型路径
   - `${MAX_MODEL_LEN}` → 用户配置的 max-model-len
   - `${MAX_NUM_SEQS}` → 用户配置的 max-num-seqs
   - `${TENSOR_PARALLEL_SIZE}` → 计算得到的值
   - `${MASTER_ADDR}` → 分布式部署的主节点地址（如适用）
   - `${MASTER_PORT}` → 分布式部署的主节点端口（如适用）
   - `${RANK}` → 分布式部署的节点 rank（如适用）
5. 写入 `.vllm-deploy/k8s/deploy.sh`
6. 展示脚本内容供用户确认

## 输出
```
.vllm-deploy/k8s/deploy.sh
```

脚本内容示例：
```bash
#!/bin/bash

# vLLM 服务启动脚本
# 自动生成于 2024-01-15

MODEL_PATH="/data/models/GLM-5"
MAX_MODEL_LEN=8192
MAX_NUM_SEQS=256
TENSOR_PARALLEL_SIZE=8

vllm serve $MODEL_PATH \
  --tensor-parallel-size $TENSOR_PARALLEL_SIZE \
  --max-model-len $MAX_MODEL_LEN \
  --max-num-seqs $MAX_NUM_SEQS \
  --port 8000
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| 模板文件不存在 | 提示检查 templates/deploy.sh 是否存在 |
| tensor_parallel_size 计算异常 | 提示 NPU 数量可能不支持当前部署模式，建议检查配置 |
| 参数替换失败 | 检查配置参数完整性，提示缺失的参数 |

## 关联资源
- 脚本：无
- 模板：`templates/deploy.sh`
- 下一阶段：`modules/deploy-execution-guide.md`