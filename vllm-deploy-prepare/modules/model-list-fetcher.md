# Phase 1: 快速获取模型列表

## 目标

从 vLLM-Ascend 文档抓取支持的模型列表。

## 默认 URL

```
https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html
```

## 执行方式

调用辅助脚本 `scripts/fetch-model-list.sh`。

## 输入

无（使用默认 URL）。

## 输出

JSON 格式的模型列表：

```json
{
  "models": [
    {"name": "GLM-5", "url": "GLM5.html"},
    {"name": "Qwen2.5-7B", "url": "Qwen2.5-7B.html"}
  ]
}
```

## 错误处理

| 场景 | 处理 |
|------|------|
| URL 无法访问 | 提示检查网络或文档站点状态 |
| 提取失败 | 建议用户手动指定模型教程 URL |

## AI 执行指南

1. 告知用户正在获取模型列表
2. 执行 `bash scripts/fetch-model-list.sh`
3. 解析脚本输出，展示模型列表
4. 进入 Phase 2