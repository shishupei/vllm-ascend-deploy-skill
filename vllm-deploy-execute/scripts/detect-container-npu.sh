#!/bin/bash
# 容器内 NPU 环境探测脚本
# 在 Pod 内执行，检测 NPU 设备映射

set -e

echo "=== Container NPU Detection ===" >&2

# 检查 /dev 目录下的 NPU 设备
NPU_DEVICES=""
for i in 0 1 2 3 4 5 6 7; do
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

# 输出 JSON
cat <<EOF
{
  "pod_name": "${HOSTNAME:-unknown}",
  "npu_devices": [$(echo "$NPU_DEVICES" | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')],
  "npu_count": $NPU_COUNT,
  "npu_smi_available": $NPU_SMI_AVAILABLE
}
EOF

echo "" >&2
echo "=== Detection Complete ===" >&2