# Phase 6: 交互配置

## 目标

通过问答确认部署参数：Namespace、模型路径、性能参数。

## 输入

- Phase 2-5 的结果
- Phase 3 提取的默认参数

## 问答流程

使用 AskUserQuestion 工具：

### Q1: Namespace 名称

建议值：`vllm-{model-name}`（如 `vllm-glm5`）

让用户确认或修改。

### Q2: 模型路径

让用户输入模型在宿主机的路径（如 `/data/models/GLM-5`）。

### Q3: 性能参数确认

展示 Phase 3 提取的默认参数，让用户确认或修改：
- `max_model_len`
- `max_num_seqs`
- `tensor_parallel_size`（基于 NPU 数量建议）

### Q4: PD 分离配置（如适用）

如果 deploy_mode 为 `pd_separate`：
- Prefill 节点数量
- Decode 节点数量

## 输出

完整配置 JSON，合并 Phase 2-6 所有参数：

```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 8,
  "master_addr": "待填充",
  "master_port": 29500
}
```

## AI 执行指南

1. 使用 AskUserQuestion 逐个询问
2. 合并所有参数生成完整配置
3. 保存到 `.vllm-deploy/config.json`
4. 进入 Phase 7