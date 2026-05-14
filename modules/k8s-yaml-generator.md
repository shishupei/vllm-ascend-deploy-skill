# Phase 7: 生成 K8s YAML

## 目的
根据用户配置和模板生成完整的 K8s YAML 文件及一键执行脚本，输出到 `.vllm-deploy/k8s/` 目录。

## 输入
- Phase 2-6 配置结果（模型、规格、部署模式、镜像、参数等）
- Phase 3 脚本模板

## 执行位置
- 管理节点或本地终端

## 步骤
1. 创建输出目录 `.vllm-deploy/k8s/`
2. 根据硬件规格选择模板（A3/A2）
3. 使用用户仓库的镜像地址替换模板中的 `${IMAGE}` 占位符
4. 生成 Namespace YAML：
   - 从 `templates/k8s-namespace.yaml` 读取模板
   - 替换 `${NAMESPACE}`、`${MODEL_NAME}` 占位符
   - 输出到 `.vllm-deploy/k8s/namespace.yaml`
5. 生成 ConfigMap YAML：
   - 从 `templates/k8s-configmap.yaml` 读取模板
   - 替换 `${NAMESPACE}`、`${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}` 占位符
   - 输出到 `.vllm-deploy/k8s/configmap.yaml`
6. 生成各节点 Deployment YAML：
   - 单节点：1 个 Deployment
   - 多节点：多个 Deployment + 分布式配置（MASTER_ADDR、MASTER_PORT、RANK）
   - PD分离：Prefill Deployment + Decode Deployment
   - 替换 `${NODE_NAME}`、`${NAMESPACE}`、`${IMAGE}`、`${NPU_RESOURCE_TYPE}`、`${NPU_COUNT}`、`${MODEL_MOUNT_PATH}`、`${MODEL_PATH_HOST}` 占位符
   - 输出到 `.vllm-deploy/k8s/deployment-node1.yaml` 等
7. 生成 Service YAML：
   - 从 `templates/k8s-service.yaml` 读取模板
   - 替换 `${NAMESPACE}`、`${SERVICE_PORT}` 占位符
   - 输出到 `.vllm-deploy/k8s/service.yaml`
8. 生成 `apply-all.sh` 一键执行脚本：
   - 从 `templates/apply-all.sh` 读取模板
   - 替换 `${NAMESPACE}` 占位符
   - 输出到 `.vllm-deploy/k8s/apply-all.sh`

## 输出
```
.vllm-deploy/k8s/
├── namespace.yaml
├── configmap.yaml
├── deployment-node1.yaml
├── deployment-node2.yaml
├── service.yaml
└── apply-all.sh
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| 模板文件不存在 | 提示检查 templates 目录，确保所有必需模板存在 |
| 目录创建权限不足 | 提示检查当前用户对工作目录的写入权限 |
| 参数替换失败 | 检查配置参数完整性，提示缺失的参数 |

## 关联资源
- 脚本：无
- 模板：
  - `templates/k8s-namespace.yaml`
  - `templates/k8s-configmap.yaml`
  - `templates/k8s-deployment.yaml`
  - `templates/k8s-service.yaml`
  - `templates/apply-all.sh`
- 下一阶段：`modules/k8s-apply-guide.md`