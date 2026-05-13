# Phase 11: 部署脚本执行指南

## 概述

此阶段为用户手动操作阶段。用户需要确认并执行 Phase 10 生成的 deploy.sh 脚本。

## 触发时机

Phase 10 完成后，系统展示 deploy.sh 脚本内容。

## 用户操作步骤

### 步骤 1：查看脚本内容

```bash
cat .vllm-deploy/k8s/deploy.sh
```

### 步骤 2：进入 Pod 执行脚本

```bash
kubectl exec -n <namespace> <pod-name> -it -- bash
# 在 Pod 内执行 deploy.sh
```

### 步骤 3：验证服务启动

```bash
kubectl logs -n <namespace> <pod-name> --tail=100 -f
curl http://<pod-ip>:8000/v1/models
```

## 完成条件

用户确认 vLLM 服务已启动后，进入 Phase 12。