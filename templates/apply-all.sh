#!/usr/bin/env bash
set -euo pipefail

# Kubernetes Apply All Script
# This script applies all Kubernetes resources in the correct order.
# Namespace: ${NAMESPACE}
#
# Usage:
#   1. Substitute placeholders with actual values
#   2. Run this script to deploy all resources
#   3. Script will wait for pods to become ready

echo "Applying Kubernetes resources to namespace: ${NAMESPACE}"

# Apply resources in order
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment-node1.yaml

echo "Waiting for pods to become ready in namespace: ${NAMESPACE}"
kubectl wait --for=condition=ready pods -l "app.kubernetes.io/name=${MODEL_NAME}" -n "${NAMESPACE}" --timeout=300s

echo "All resources applied successfully!"