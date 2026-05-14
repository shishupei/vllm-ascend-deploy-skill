# Phase 3: 针对性文档解析

## 目标

解析文档获取部署信息：
1. 从模型文档提取启动脚本和镜像版本
2. 从 K8s 部署指南动态获取 YAML 配置模板

## 输入

- Phase 2 用户选择结果
- 模型文档 URL（基于 model_url）

## 完整 URL 构建

模型文档：
```
https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/{model_url}
```

K8s 部署指南：
```
https://docs.vllm.ai/projects/vllm-ascend-cn/zh-cn/latest/user_guide/deployment_guide/using_volcano_kthena.html
```

## 执行方式

调用辅助脚本：
- `scripts/parse-model-doc.sh` - 解析模型文档
- `scripts/fetch-k8s-config.sh` - 获取 K8s 配置模板

## 参数

传递给 parse-model-doc.sh：
- `--url`: 完整文档 URL
- `--hw-spec`: A3 或 A2
- `--deploy-mode`: single_node / multi_node / pd_separate

传递给 fetch-k8s-config.sh：
- `--url`: K8s 部署指南 URL（可选，有默认值）

## 输出

```json
{
  "image_version": "v0.6.0",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "script_template": "vllm serve ...",
  "extracted_params": {
    "max_model_len": 8192,
    "tensor_parallel_size": 8
  },
  "k8s_config": {
    "npu_resource_type": "huawei.com/Ascend910",
    "volumes": [...],
    "env_vars": {...},
    "resources": {...}
  }
}
```

## 错误处理

| 场景 | 处理 |
|------|------|
| 脚本块未找到 | 建议用户手动提供启动脚本 |
| 镜像版本未找到 | 提示用户手动指定镜像版本 |
| K8s 配置获取失败 | 使用默认配置模板 |

## AI 执行指南

1. 构建完整文档 URL
2. 执行 `bash scripts/parse-model-doc.sh --url <URL> --hw-spec <SPEC> --deploy-mode <MODE>`
3. 执行 `bash scripts/fetch-k8s-config.sh` 获取 K8s 配置模板
4. 解析脚本输出，合并结果
5. 展示提取的脚本模板供用户确认
6. 进入 Phase 5