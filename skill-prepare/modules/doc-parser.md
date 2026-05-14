# Phase 3: 针对性文档解析

## 目标

只解析用户选择的模型文档，提取启动脚本和镜像版本。

## 输入

- Phase 2 用户选择结果
- 模型文档 URL（基于 model_url）

## 完整 URL 构建

```
https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/{model_url}
```

## 执行方式

调用辅助脚本 `scripts/parse-model-doc.sh`。

## 参数

传递给脚本：
- `--url`: 完整文档 URL
- `--hw-spec`: A3 或 A2
- `--deploy-mode`: single_node / multi_node / pd_separate

## 输出

```json
{
  "image_version": "v0.6.0",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "script_template": "vllm serve ...",
  "extracted_params": {
    "max_model_len": 8192,
    "tensor_parallel_size": 8
  }
}
```

## 错误处理

| 场景 | 处理 |
|------|------|
| 脚本块未找到 | 建议用户手动提供启动脚本 |
| 镜像版本未找到 | 提示用户手动指定镜像版本 |

## AI 执行指南

1. 构建完整文档 URL
2. 执行 `bash scripts/parse-model-doc.sh --url <URL> --hw-spec <SPEC> --deploy-mode <MODE>`
3. 解析脚本输出
4. 展示提取的脚本模板供用户确认
5. 进入 Phase 5