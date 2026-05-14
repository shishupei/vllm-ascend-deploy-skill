# Phase 3: 解析模型文档

## 目的
针对性解析用户所选模型的文档页面，只提取匹配硬件规格和部署方式的脚本模板及镜像版本。

## 输入
- Phase 2 用户选择结果（模型、硬件规格、部署方式）
- 模型文档 URL

## 执行位置
- 管理节点或本地终端（需网络访问）

## 步骤
1. 根据 Phase 2 的 `model_url` 构建完整文档 URL
2. 调用 `scripts/parse-model-doc.sh` 抓取模型文档页面
3. 根据用户选择的硬件规格（A3/A2）过滤脚本块
4. 根据用户选择的部署方式（单节点/多节点/PD分离）过滤脚本块
5. 从匹配的脚本块中提取：
   - 镜像版本（如 `quay.io/vllm-ascend/vllm-ascend:v0.6.0`）
   - 启动参数模板
   - 环境变量配置
6. 展示提取结果供用户确认

## 输出
```json
{
  "model": "GLM-5",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "script_template": {
    "image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
    "env_vars": {
      "VLLM_USE_MODELSCOPE": "false"
    },
    "startup_params": {
      "model": "/path/to/model",
      "tensor-parallel-size": 8,
      "max-model-len": 8192,
      "max-num-seqs": 256
    }
  }
}
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| 文档 URL 无法访问 | 提示检查网络，或建议用户手动提供脚本内容 |
| 指定硬件规格的脚本块未找到 | 提示该模型可能不支持此硬件规格，建议选择其他规格 |
| 指定部署方式的脚本块未找到 | 提示该模型可能不支持此部署方式，建议选择其他方式 |
| 镜像版本提取失败 | 建议用户手动指定镜像版本 |

## 关联资源
- 脚本：`scripts/parse-model-doc.sh`
- 模板：无
- 下一阶段：`modules/k8s-env-detector.md`