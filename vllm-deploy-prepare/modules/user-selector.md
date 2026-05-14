# Phase 2: 用户选择

## 目标

通过问答收集用户选择：模型类型、具体模型、硬件规格、部署方式、镜像仓库。

## 输入

Phase 1 的模型列表。

## 模型分类规则

根据模型名称自动分类：

| 类型 | 匹配规则 | 示例 |
|------|----------|------|
| DeepSeek 系列 | 名称包含 `DeepSeek` | DeepSeek-R1, DeepSeek-V3.1 |
| Qwen 系列 | 名称包含 `Qwen` | Qwen2.5-7B, Qwen3-Dense |
| GLM 系列 | 名称包含 `GLM` | GLM4.x, GLM5 |
| Kimi 系列 | 名称包含 `Kimi` | Kimi-K2-Thinking |
| 其他模型 | 以上都不匹配 | MiniMax-M2.5, PaddleOCR-VL |

## 问答流程

使用 AskUserQuestion 工具，逐个询问：

### Q1: 选择模型类型

根据 Phase 1 模型列表自动分类后，展示类型选项：

```
选择模型类型：
1. DeepSeek 系列 (N 个模型)
2. Qwen 系列 (N 个模型)
3. GLM 系列 (N 个模型)
4. Kimi 系列 (N 个模型)
5. 其他模型 (N 个模型)
```

### Q2: 选择具体模型

根据 Q1 选择的类型，展示该类型下的所有模型：

```
选择具体模型（DeepSeek 系列）：
1. DeepSeek-R1 - DeepSeek 推理模型
2. DeepSeek-V3.1 - DeepSeek V3/V3.1 模型
3. DeepSeek-V3.2 - DeepSeek V3.2 模型
4. DeepSeekOCR2 - DeepSeek OCR 模型
```

### Q3: 硬件规格

选项：
- A3（16 卡）
- A2（8 卡）

### Q4: 部署方式

选项：
- 单节点：使用 1 个节点部署
- 多节点：使用多个节点分布式部署
- PD分离：Prefill 和 Decode 节点分离
- 主备高可用：Active-Standby 多副本部署

### Q5: 目标镜像仓库

让用户输入镜像仓库地址（如 `harbor.example.com/library`）。

## 输出

```json
{
  "model_type": "DeepSeek",
  "selected_model": "DeepSeek-V3.1",
  "model_url": "DeepSeek-V3.1.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library"
}
```

## AI 执行指南

1. 解析 Phase 1 模型列表，按类型分组
2. 使用 AskUserQuestion 先询问模型类型（Q1）
3. 根据用户选择的类型，过滤模型列表
4. 使用 AskUserQuestion 展示该类型的具体模型（Q2）
5. 继续询问 Q3-Q5
6. 记录所有选择结果
7. 进入 Phase 3