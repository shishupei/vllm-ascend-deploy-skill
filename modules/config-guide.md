# Phase 6: 交互配置模块

## 概述

通过 AskUserQuestion 工具收集部署所需的配置参数：Namespace、模型路径、性能参数等。

## 输入

- Phase 2-5 结果
- Phase 3 提取的参数模板（如有）

## 处理步骤

1. 通过 AskUserQuestion 收集 Namespace 名称
2. 通过 AskUserQuestion 收集模型路径
3. 通过 AskUserQuestion 确认性能参数（max-model-len、max_num_seqs）
4. 如适用（PD分离），收集 Prefill 和 Decode 节点配置
5. 等待用户确认配置参数

## 输出

```json
{
  "namespace": "vllm-deploy",
  "model_path": "/data/models/GLM-5",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 8,
  "prefill_nodes": ["node-1"],
  "decode_nodes": ["node-2"]
}
```

## 交互工具

使用 AskUserQuestion 工具，每次一个问题：

### Q1: Namespace 名称

```json
{
  "question": "请输入 K8s Namespace 名称（用于隔离部署环境）",
  "header": "Namespace",
  "options": [
    {"label": "vllm-deploy", "description": "默认命名空间"},
    {"label": "自定义", "description": "手动输入命名空间名称"}
  ],
  "multiSelect": false
}
```

### Q2: 模型路径

```json
{
  "question": "请输入模型在宿主机的存储路径",
  "header": "模型路径",
  "options": [],
  "multiSelect": false
}
```

### Q3: 性能参数确认

```json
{
  "question": "请确认性能参数：max-model-len=8192, max_num_seqs=256",
  "header": "性能参数",
  "options": [
    {"label": "确认使用", "description": "使用文档推荐的默认参数"},
    {"label": "自定义参数", "description": "手动输入参数值"}
  ],
  "multiSelect": false
}
```

### Q4: PD分离配置（如适用）

```json
{
  "question": "请配置 PD分离节点：选择 Prefill 节点和 Decode 节点",
  "header": "PD分离",
  "options": [
    {"label": "node-1 作为 Prefill", "description": "Prefill 节点"},
    {"label": "node-2 作为 Decode", "description": "Decode 节点"}
  ],
  "multiSelect": true
}
```

## 错误处理

此模块为纯交互模块，不涉及技术性操作，无特殊错误场景。

用户输入无效参数时（如空的 Namespace 或不存在的模型路径），提示用户重新输入。

## 用户确认

展示配置参数后，询问用户是否继续进入 Phase 7（K8s YAML 生成）。