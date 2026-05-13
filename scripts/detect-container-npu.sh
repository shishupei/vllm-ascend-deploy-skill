#!/bin/bash

# 在 Pod 内探测 NPU 设备映射情况
# 输出格式：JSON

set -e

POD_NAME="$1"
NAMESPACE="$2"

if [ -z "$POD_NAME" ] || [ -z "$NAMESPACE" ]; then
    echo '{"error": "POD_NAME and NAMESPACE are required"}'
    exit 1
fi

# 检查 Pod 状态
POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>&1)
if [ $? -ne 0 ]; then
    echo '{"error": "Pod not found"}'
    exit 1
fi

if [ "$POD_STATUS" != "Running" ]; then
    echo '{"error": "Pod is not running", "pod_status": "' "$POD_STATUS" '"}'
    exit 1
fi

# 在 Pod 内执行 npu-smi 探测 NPU 设备
NPU_DEVICES=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ls /dev/davinci* 2>/dev/null | sort -u)

# 计算设备数量
NPU_COUNT=$(echo "$NPU_DEVICES" | wc -l)

echo '{'
echo '"pod_name": "' "$POD_NAME" '",'
echo '"pod_status": "' "$POD_STATUS" '",'
echo '"container_npu_count": ' "$NPU_COUNT" ','
echo '"devices_mapped": ['

DEVICE_COUNT=0
for DEVICE in $NPU_DEVICES; do
    DEVICE_NAME=$(basename "$DEVICE")
    if [ $DEVICE_COUNT -gt 0 ]; then
        echo ','
    fi
    echo '"' "$DEVICE_NAME" '"'
    DEVICE_COUNT=$((DEVICE_COUNT + 1))
done

echo ']'
echo '}'