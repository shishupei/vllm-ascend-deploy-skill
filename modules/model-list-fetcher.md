# Phase 1: 获取模型列表

## 目的
从 vLLM-Ascend 文档站点快速获取可用模型列表，供用户选择部署目标。

## 输入
- 默认 URL：https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html
- 用户可手动指定替代 URL

## 执行位置
- 管理节点或本地终端（需网络访问）

## 步骤
1. 调用 `scripts/fetch-model-list.sh` 抓取模型列表页 HTML
2. 解析 HTML，提取所有模型名称和对应的文档链接
3. 过滤并整理模型列表
4. 向用户展示可用模型列表（序号 + 模型名）

## 输出
```json
{
  "source_url": "https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html",
  "models": [
    {"name": "GLM-5", "url": "GLM5.html"},
    {"name": "Qwen2.5-7B", "url": "Qwen2.5-7B.html"},
    {"name": "DeepSeek-V3.1", "url": "DeepSeek-V3.1.html"}
  ],
  "fetch_time": "2024-01-15T10:30:00Z"
}
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| 默认 URL 无法访问 | 提示检查网络或 vLLM-Ascend 文档站点状态，建议用户手动指定模型教程 URL |
| 模型列表提取失败 | 建议用户手动提供模型名称和文档 URL |
| 网络超时 | 重试一次，若仍失败则建议检查代理设置或网络环境 |

## 关联资源
- 脚本：`scripts/fetch-model-list.sh`
- 模板：无
- 下一阶段：`modules/user-selector.md`