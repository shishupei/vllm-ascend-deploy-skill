#!/bin/bash
# 容器内 NPU 环境探测脚本
# 在 Pod 内执行，检测 NPU 设备映射

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: required command 'jq' not found" >&2
    exit 1
fi

echo "=== Container NPU Detection ===" >&2

# 检查 /dev 目录下的 NPU 设备
NPU_DEVICES=""
# 支持扫描 0-15，覆盖 A3 16 卡环境
for i in $(seq 0 15); do
    if [ -e "/dev/davinci$i" ]; then
        NPU_DEVICES="$NPU_DEVICES /dev/davinci$i"
    fi
done

# 检查其他设备
for dev in /dev/davinci_manager /dev/devmm_svm /dev/hisi_hdc; do
    if [ -e "$dev" ]; then
        NPU_DEVICES="$NPU_DEVICES $dev"
    fi
done

NPU_DEVICES=$(echo "$NPU_DEVICES" | tr ' ' '\n' | grep -v '^$' | sort -u)
NPU_COUNT=$(echo "$NPU_DEVICES" | grep '/dev/davinci[0-9]' | wc -l)

echo "NPU Devices found:" >&2
echo "$NPU_DEVICES" >&2
echo "NPU Count: $NPU_COUNT" >&2

# 检查 npu-smi
NPU_SMI_AVAILABLE=false
if command -v npu-smi &> /dev/null; then
    NPU_SMI_AVAILABLE=true
    echo "" >&2
    echo "=== NPU-SMI Info ===" >&2
    npu-smi info 2>/dev/null >&2 || echo "npu-smi info failed" >&2
fi

# 输出 JSON（使用 jq 安全构建）
NPU_DEVICES_JSON=$(echo "$NPU_DEVICES" | jq -R -s 'split("\n") | map(select(length > 0))')

jq -n \
    --arg pod_name "${HOSTNAME:-unknown}" \
    --argjson devices "$NPU_DEVICES_JSON" \
    --argjson count "$NPU_COUNT" \
    --argjson smi "$NPU_SMI_AVAILABLE" \
    '{pod_name: $pod_name, npu_devices: $devices, npu_count: $count, npu_smi_available: $smi}'

echo "" >&2
echo "=== Detection Complete ===" >&2