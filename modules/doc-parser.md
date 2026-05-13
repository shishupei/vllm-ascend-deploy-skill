# Phase 3: 针对性文档解析模块

## 概述

只抓取用户选择的模型页面，只解析用户选择的硬件规格和部署方式的脚本内容。

## 输入

- Phase 2 输出的选择结果 JSON
- 模型文档基础 URL：`https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/`

## 处理步骤

1. 根据选择的模型 URL 构建完整文档地址
2. **自动执行** `scripts/parse-model-doc.sh` 抓取模型文档页面
3. 根据硬件规格（A3/A2）定位对应脚本块
4. 根据部署方式（单节点/多节点/PD分离）提取对应脚本
5. 提取镜像版本信息
6. **Phase 3 完成**，等待用户确认进入 Phase 4

## 输出

```json
{
  "script_content": "#!/bin/bash\n...",
  "image_version": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "parameters": {
    "max_model_len": 8192,
    "max_num_seqs": 256
  }
}
```

## 调用脚本

```bash
scripts/parse-model-doc.sh <model_url> <hw_spec> <deploy_mode>
```

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| 脚本块未找到 | 建议用户手动提供脚本内容 |
| 镜像版本提取失败 | 提示用户手动指定镜像版本 |

## 用户确认

展示解析结果（脚本内容、镜像版本）后，询问用户是否继续进入 Phase 4（K8s 环境探测）。