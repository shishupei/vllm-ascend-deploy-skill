# Phase 7: K8s YAML 生成模块

## 概述

根据模板和配置参数生成完整的 K8s YAML 文件集，包括 Namespace、ConfigMap、Deployment、Service 和一键执行脚本。

## 输入

- Phase 2-6 配置结果
- Phase 3 脚本模板
- Phase 5 目标镜像地址

## 处理步骤

1. 根据硬件规格选择模板参数（A3/A2）
2. 使用用户仓库的镜像地址替换模板中的 `${IMAGE}`
3. 生成 Namespace YAML
4. 生成 ConfigMap YAML（存储配置参数）
5. 根据部署方式生成 Deployment YAML：
   - 单节点：1 个 Deployment
   - 多节点：多个 Deployment + 分布式配置
   - PD分离：Prefill Deployment + Decode Deployment
6. 生成 Service YAML（暴露服务端口，默认 8000，NodePort 方式）
7. 生成 `apply-all.sh` 一键执行脚本
8. 等待用户确认生成的文件

## 输出文件

```
.vllm-deploy/k8s/
├── namespace.yaml
├── configmap.yaml
├── deployment-node1.yaml
├── deployment-node2.yaml
├── service.yaml
└── apply-all.sh
```

## 模板替换参数

| 模板文件 | 替换参数 |
|---------|---------|
| k8s-namespace.yaml | `${NAMESPACE}`、`${MODEL_NAME}` |
| k8s-configmap.yaml | `${NAMESPACE}`、`${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}` |
| k8s-deployment.yaml | `${NODE_NAME}`、`${NAMESPACE}`、`${IMAGE}`、`${NPU_RESOURCE_TYPE}`、`${NPU_COUNT}`、`${MODEL_MOUNT_PATH}`、`${MODEL_PATH_HOST}` |
| k8s-service.yaml | `${NAMESPACE}`、`${SERVICE_PORT}` |
| apply-all.sh | `${NAMESPACE}` |

## 错误处理

此模块为纯文本生成模块，不涉及技术性操作，无特殊错误场景。

生成的 YAML 文件语法错误时，提示用户手动修正。

## 用户确认

展示生成的文件列表和内容摘要后，询问用户是否手动执行 `apply-all.sh`。