# Phase 10: 部署脚本生成

## 目标

根据容器内 NPU 探测结果，生成 Pod 内执行的 vLLM 启动脚本。

## 输入

- `.vllm-deploy/config.json` - 用户配置
- 容器内 NPU 探测结果（Phase 9）
- Skill 1 生成的启动脚本模板（`.vllm-deploy/scripts/`）

## 脚本选择逻辑

根据 `deploy_mode` 选择对应的启动脚本：

| deploy_mode | 脚本 |
|-------------|------|
| `single_node` | `start-single-node.sh` |
| `multi_node` | Master: `start-multi-node-master.sh`, Worker: `start-multi-node-worker.sh` |
| `pd_separate` | Prefill: `start-prefill.sh`, Decode: `start-decode.sh` |

## 占位符填充

读取 Skill 1 生成的脚本模板，填充探测获得的参数：

### 多节点脚本填充

| 占位符 | 来源 |
|--------|------|
| `${NODE_IP_PLACEHOLDER}` | Pod 的 status.podIP |
| `${WORLD_SIZE_PLACEHOLDER}` | 部署节点数量 |
| `${MASTER_ADDR_PLACEHOLDER}` | Master Pod IP |
| `${WORKER_RANK_PLACEHOLDER}` | Pod 的 Rank 标签 |

## 输出

生成 `.vllm-deploy/k8s/deploy.sh`：

```bash
#!/bin/bash
# Pod 内 vLLM 启动脚本
# 参数已填充

MODEL_PATH="/data/models/GLM-5"
TENSOR_PARALLEL_SIZE=8
...

vllm serve "$MODEL_PATH" ...
```

## AI 执行指南

1. 读取 config.json 确定 deploy_mode
2. 选择对应的启动脚本模板
3. 填充探测获得的参数
4. 生成 deploy.sh 到 `.vllm-deploy/k8s/`
5. 展示脚本内容
6. 进入 Phase 11

## 多节点脚本生成

对于多节点部署，需要为每个 Pod 生成对应的脚本：
- Master Pod: `deploy-master.sh`
- Worker Pod 1: `deploy-worker-1.sh`

每个脚本需要填充不同的 Rank 和节点 IP。