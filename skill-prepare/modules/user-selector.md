# Phase 2: 用户选择

## 目标

通过问答收集用户选择：模型、硬件规格、部署方式、镜像仓库。

## 输入

Phase 1 的模型列表。

## 问答流程

使用 AskUserQuestion 工具，逐个询问：

### Q1: 选择模型

展示模型列表，让用户选择一个模型。

### Q2: 硬件规格

选项：
- A3（16 卡）
- A2（8 卡）

### Q3: 部署方式

选项：
- 单节点：使用 1 个节点部署
- 多节点：使用多个节点分布式部署
- PD分离：Prefill 和 Decode 节点分离

### Q4: 目标镜像仓库

让用户输入镜像仓库地址（如 `harbor.example.com/library`）。

## 输出

```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library"
}
```

## AI 执行指南

1. 使用 AskUserQuestion 逐个询问
2. 记录用户选择到临时变量
3. 进入 Phase 3