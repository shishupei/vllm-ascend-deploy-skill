#!/bin/bash
# K8s 环境探测脚本
# 检测 kubectl 可用性、集群连接、节点 NPU 信息

set -e

echo "=== K8s Environment Detection ===" >&2

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    cat <<EOF
{
  "cluster_connected": false,
  "error": "kubectl not found",
  "message": "Please install kubectl: apt install kubectl or download from https://kubernetes.io/docs/tasks/tools/"
}
EOF
    exit 1
fi

# 检查 kubeconfig
if ! kubectl config view --minify &> /dev/null; then
    cat <<EOF
{
  "cluster_connected": false,
  "error": "kubeconfig not configured",
  "message": "Please configure kubeconfig: export KUBECONFIG=/path/to/config"
}
EOF
    exit 1
fi

# 检查集群连接
if ! kubectl cluster-info &> /dev/null; then
    cat <<EOF
{
  "cluster_connected": false,
  "error": "cluster unreachable",
  "message": "Please check API Server address and network connectivity"
}
EOF
    exit 1
fi

echo "Cluster connected successfully!" >&2

# 获取所有节点
NODES=$(kubectl get nodes -o json)

# 支持的 NPU 资源类型
NPU_RESOURCE_TYPES="huawei.com/Ascend910 huawei.com/NPU huawei.com/Ascend310P huawei.com/Ascend910B"

# 使用临时文件收集节点 JSON，然后用 jq 合并
TEMP_NODES_FILE=$(mktemp)

for node_name in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    # 获取节点 IP
    NODE_IP=$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

    # 检测 NPU 资源
    NPU_TYPE=""
    NPU_COUNT=0

    for npu_type in $NPU_RESOURCE_TYPES; do
        count=$(kubectl get node "$node_name" -o json | jq -r ".status.allocatable.\"$npu_type\"" 2>/dev/null || echo "0")
        if [ "$count" != "null" ] && [ "$count" != "0" ] && [ -n "$count" ]; then
            NPU_TYPE="$npu_type"
            NPU_COUNT="$count"
            break
        fi
    done

    # 输出单个节点 JSON 到临时文件
    jq -n \
        --arg name "$node_name" \
        --arg ip "$NODE_IP" \
        --arg npu_type "$NPU_TYPE" \
        --argjson npu_count "$NPU_COUNT" \
        '{
            name: $name,
            ip: $ip,
            npu_type: $npu_type,
            npu_count: $npu_count,
            npu_available: $npu_count,
            labels: {}
        }' >> "$TEMP_NODES_FILE"
done

# 使用 jq 合并所有节点为数组
NODE_LIST=$(jq -s '.' "$TEMP_NODES_FILE")
rm "$TEMP_NODES_FILE"

# 推荐节点（按 NPU 数量排序）
RECOMMENDED=$(echo "$NODE_LIST" | jq -r '[.[] | select(.npu_count > 0)] | sort_by(-.npu_count) | .[].name' 2>/dev/null || echo "")

# 计算总 NPU 数量
TOTAL_NPU=$(echo "$NODE_LIST" | jq '[.[].npu_count] | add' 2>/dev/null || echo "0")

# 输出结果（仅 stdout）
cat <<EOF
{
  "cluster_connected": true,
  "nodes": $NODE_LIST,
  "recommended_nodes": $(echo "$RECOMMENDED" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]"),
  "total_npu_available": $TOTAL_NPU
}
EOF

echo "" >&2
echo "Detection completed. Total available NPU: $TOTAL_NPU" >&2