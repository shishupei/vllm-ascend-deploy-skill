#!/bin/bash

# 探测 K8s 集群节点信息、NPU 数量、硬件规格
# 输出格式：JSON

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo '{"error": "kubectl not available", "kubectl_available": false}'
    exit 1
fi

# 检查集群连接状态
if ! kubectl cluster-info &> /dev/null; then
    echo '{"error": "Cannot connect to K8s cluster", "cluster_connected": false}'
    exit 1
fi

# 获取节点列表
NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

echo '{'
echo '"kubectl_available": true,'
echo '"cluster_connected": true,'
echo '"nodes": ['

NODE_COUNT=0
for NODE in $NODES; do
    # 获取节点 IP
    NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

    # 获取 NPU 数量（通过资源容量）
    NPU_COUNT=$(kubectl get node "$NODE" -o jsonpath='{.status.capacity.davinci}' 2>/dev/null || echo "0")
    if [ "$NPU_COUNT" == "0" ] || [ -z "$NPU_COUNT" ]; then
        # 尝试另一种资源名称
        NPU_COUNT=$(kubectl get node "$NODE" -o jsonpath='{.status.capacity.huawei\.com/Ascend910}' 2>/dev/null || echo "0")
    fi

    # 验证 NPU_COUNT 是否为数字
    if ! [[ "$NPU_COUNT" =~ ^[0-9]+$ ]]; then
        NPU_COUNT=0
    fi

    # 判断硬件规格
    if [ "$NPU_COUNT" -ge 16 ]; then
        HW_SPEC="A3"
    elif [ "$NPU_COUNT" -ge 8 ]; then
        HW_SPEC="A2"
    else
        HW_SPEC="unknown"
    fi

    # 输出节点信息
    if [ $NODE_COUNT -gt 0 ]; then
        echo ','
    fi
    echo '{"name": "' "$NODE" '", "ip": "' "$NODE_IP" '", "npu_count": ' "$NPU_COUNT" ', "hw_spec": "' "$HW_SPEC" '"}'

    NODE_COUNT=$((NODE_COUNT + 1))
done

echo '],'
echo '"recommended_nodes": []'
echo '}'