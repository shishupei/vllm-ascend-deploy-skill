# Phase 2: 用户选择模块

## 概述

通过 AskUserQuestion 工具让用户选择模型、硬件规格、部署方式和目标镜像仓库地址。

## 输入

- Phase 1 输出的模型列表 JSON

## 处理步骤

1. 展示模型列表，让用户选择目标模型
2. 让用户选择硬件规格（A3/A2）
3. 让用户选择部署方式：
   - 单节点：使用 1 个节点部署
   - 多节点：使用多个节点进行分布式部署
   - PD分离：Prefill 和 Decode 节点分离部署
4. 让用户输入目标镜像仓库地址（如 `harbor.example.com/library`）
5. 等待用户确认选择结果

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

## 交互工具

使用 AskUserQuestion 工具，每次一个问题：

### Q1: 选择模型

```json
{
  "question": "请选择要部署的模型",
  "header": "模型选择",
  "options": [
    {"label": "GLM-5", "description": "智谱 GLM-5 大语言模型"},
    {"label": "Qwen2.5-7B", "description": "阿里 Qwen2.5 7B 模型"}
  ],
  "multiSelect": false
}
```

### Q2: 选择硬件规格

```json
{
  "question": "请选择硬件规格",
  "header": "硬件规格",
  "options": [
    {"label": "A3", "description": "16 卡 NPU 配置"},
    {"label": "A2", "description": "8 卡 NPU 配置"}
  ],
  "multiSelect": false
}
```

### Q3: 选择部署方式

```json
{
  "question": "请选择部署方式",
  "header": "部署方式",
  "options": [
    {"label": "单节点", "description": "使用 1 个节点部署"},
    {"label": "多节点", "description": "使用多个节点分布式部署"},
    {"label": "PD分离", "description": "Prefill 和 Decode 节点分离部署"}
  ],
  "multiSelect": false
}
```

### Q4: 输入镜像仓库地址

```json
{
  "question": "请输入目标镜像仓库地址（如 harbor.example.com/library）",
  "header": "镜像仓库",
  "options": [],
  "multiSelect": false
}
```

## 用户确认

展示选择结果后，询问用户是否继续进入 Phase 3（文档解析）。