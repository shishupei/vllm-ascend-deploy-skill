# Phase 1: 模型列表获取模块

## 概述

抓取 vLLM-Ascend 模型列表页，提取所有模型名称和链接，供用户选择。

## 输入

- 默认 URL：`https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html`
- 用户可自定义 URL

## 处理步骤

1. **自动执行** `scripts/fetch-model-list.sh` 抓取模型列表页
2. 解析 HTML，提取模型名称和对应的文档链接
3. 展示模型列表供用户选择
4. **Phase 1 完成**，等待用户确认进入 Phase 2

## 输出

```json
{
  "models": [
    {"name": "GLM-5", "url": "GLM5.html"},
    {"name": "Qwen2.5-7B", "url": "Qwen2.5-7B.html"}
  ]
}
```

## 调用脚本

```bash
scripts/fetch-model-list.sh [URL]
```

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| 默认 URL 无法访问 | 提示检查网络或文档站点状态，允许用户自定义 URL |
| 模型列表提取失败 | 建议用户手动指定模型教程 URL |

## 用户确认

展示模型列表后，询问用户是否继续进入 Phase 2（用户选择）。