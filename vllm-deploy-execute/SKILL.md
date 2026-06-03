---
name: vllm-deploy-execute
description: vLLM-Ascend 部署执行 - K8s 环境探测、生成 YAML、执行部署
---

vLLM-Ascend 部署执行阶段，在 K8s 管理节点执行。

## 前置条件

- 已运行 `/vllm-deploy-prepare` 并生成 `.vllm-deploy/` 目录
- `kubectl` 已安装并有集群管理权限
- kubeconfig 已正确配置
- `jq` 已安装
- `envsubst` 已安装（通常来自 gettext 包）

## 触发方式

- `/vllm-deploy-execute`
- `vllm 部署执行`

## 执行流程

按顺序读取以下模块并执行：

1. **Phase 4**: `modules/k8s-env-detector.md` - K8s 环境探测
2. **Phase 7（补）**: `modules/yaml-generator.md` - 填充模板生成 YAML
3. **Phase 8**: `modules/k8s-apply-guide.md` - K8s Apply 指导（等待用户确认）
4. **Phase 9**: `modules/container-env-detector.md` - 容器内 NPU 探测
5. **Phase 10**: `modules/deploy-generator.md` - 生成部署脚本
6. **Phase 11**: `modules/deploy-execution-guide.md` - 部署执行指导（等待用户确认）
7. **Phase 12**: `modules/output-guide.md` - 输出交付

## 输入

读取 `.vllm-deploy/config.json`：
```json
{
  "selected_model": "GLM-5",
  "deploy_mode": "multi_node",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  ...
}
```

## 输出

生成 `.vllm-deploy/k8s/` 目录，包含：
- `all.yaml` - 合并的 K8s 资源清单（Namespace、ConfigMap、Deployment、Service）
- `master.yaml` - 仅多节点模式：Master 节点清单
- `worker-*.yaml` - 仅多节点模式：Worker 节点清单（按节点编号）
- `apply-all.sh` - 一键部署脚本
- `README.md` - 部署指南

以及：
- `detection-result.json` - K8s 环境探测结果

## 用户确认点

| 确认点 | 用户操作 |
|--------|---------|
| Phase 4 结束 | 确认节点选择 |
| Phase 8 结束 | 执行 `bash apply-all.sh` |
| Phase 11 结束 | 在 Pod 内执行部署脚本 |

## 错误处理

- `config.json` 不存在 → 提示先运行 `/vllm-deploy-prepare`
- `kubectl` 不可用 → 提示安装 kubectl 并配置 kubeconfig
- K8s 集群连接失败 → 提示检查 kubeconfig 和网络
- NPU 资源未注册 → 提示检查 Ascend Device Plugin