#!/bin/bash

# K8s 一键 apply 脚本模板
# 按顺序 apply 所有 YAML 文件

set -e

NAMESPACE="${NAMESPACE}"

echo "Applying K8s resources in namespace: ${NAMESPACE}"

# 1. Apply Namespace
echo "Creating namespace..."
kubectl apply -f namespace.yaml

# 2. Apply ConfigMap
echo "Creating configmap..."
kubectl apply -f configmap.yaml

# 3. Apply Deployments
echo "Creating deployments..."
for DEPLOYMENT in deployment-*.yaml; do
    echo "Applying ${DEPLOYMENT}..."
    kubectl apply -f "${DEPLOYMENT}"
done

# 4. Apply Service
echo "Creating service..."
kubectl apply -f service.yaml

# 5. 等待 Pod 就绪
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=vllm-deploy -n ${NAMESPACE} --timeout=300s

echo "All resources applied successfully."
echo "Pods status:"
kubectl get pods -n ${NAMESPACE}