# Phase 8: K8s Apply 执行指南

## 概述

此阶段为用户手动操作阶段。用户需要执行 Phase 7 生成的 K8s YAML 文件，创建部署资源。

## 触发时机

Phase 7 完成后，系统展示生成的文件列表和内容摘要。

## 用户操作步骤

### 方式一：一键执行

```bash
cd .vllm-deploy/k8s
bash apply-all.sh
```

### 方式二：手动逐个执行

```bash
cd .vllm-deploy/k8s
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment-node1.yaml
kubectl apply -f service.yaml
```

### 验证 Pod 状态

```bash
kubectl get pods -n <namespace>
kubectl wait --for=condition=ready pod -l app=vllm-deploy -n <namespace> --timeout=300s
kubectl logs <pod-name> -n <namespace>
```

## 完成条件

用户确认 Pod 状态为 `Running` 后，进入 Phase 9。