# Phase 10: 部署脚本生成

## 目标

根据容器内 NPU 探测结果生成 Pod 内执行的 vLLM 启动脚本（仅 `single_node` 和 `multi_node` 模式需要）。

`pd_separate` 和 `ha_active_standby` 模式的模板已内嵌启动命令，不需要生成独立的 deploy.sh。

## 输入

- `.vllm-deploy/config.json` - 用户配置
- `.vllm-deploy/container-detection-result.json` - Phase 9 容器内 NPU 探测结果

## 脚本生成逻辑

执行 `scripts/generate-deploy.sh`，该脚本：

1. 读取 `config.json` 获取 `deploy_mode`、`model_path`、`selected_model`、`max_model_len`、`max_num_seqs`
2. 读取 `container-detection-result.json` 获取容器内实际 NPU 数量
3. 使用容器内探测到的 NPU 数量设置 `--tensor-parallel-size`
4. 仅在 `single_node` 或 `multi_node` 模式下生成 `deploy.sh`

| deploy_mode | 是否生成 deploy.sh | tensor-parallel-size 来源 |
|-------------|---------------------|--------------------------|
| `single_node` | 生成 | 容器内探测 `npu_count` |
| `multi_node` | 生成（仅 Master 使用） | 容器内探测 `npu_count` |
| `pd_separate` | 不生成 | 模板内嵌 |
| `ha_active_standby` | 不生成 | 模板内嵌 |

## 输出

仅在 `single_node` 或 `multi_node` 模式下生成 `.vllm-deploy/k8s/deploy.sh`：

```bash
#!/bin/bash
# Pod 内 vLLM 启动脚本
# tensor-parallel-size 来自容器内 NPU 探测结果

vllm serve "${MODEL_PATH}" \
  --served-model-name "${MODEL_NAME}" \
  --tensor-parallel-size "${CONTAINER_NPU_COUNT}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --port 8000 \
  --trust-remote-code
```

## AI 执行指南

1. 确认 Phase 9 已完成，`.vllm-deploy/container-detection-result.json` 存在
2. 执行 `scripts/generate-deploy.sh .vllm-deploy/config.json .vllm-deploy/container-detection-result.json .vllm-deploy/k8s`
3. 展示生成的脚本内容
4. 进入 Phase 11

## 多节点说明

多节点模式下，`deploy.sh` 仅在 Master Pod 内执行。Worker Pod 必须已处于 Running 状态并通过 `ray start --address=...` 加入 Ray 集群，之后才能在 Master Pod 执行 deploy.sh。

```bash
# 仅在 Master Pod 执行
kubectl cp deploy.sh -n <namespace> <master-pod>:/tmp/deploy.sh
kubectl exec -n <namespace> <master-pod> -- bash /tmp/deploy.sh
```