#!/bin/bash
# 从 K8s 部署指南获取 YAML 配置模板

set -e

DEFAULT_URL="https://docs.vllm.ai/projects/vllm-ascend-cn/zh-cn/latest/user_guide/deployment_guide/using_volcano_kthena.html"
URL="${1:-$DEFAULT_URL}"

echo "Fetching K8s deployment config from: $URL" >&2

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}'
    exit 1
fi

# 提取 NPU 资源类型（根据文档中的示例）
NPU_RESOURCE=$(echo "$HTML" | grep -o 'huawei.com/[a-zA-Z0-9-]*' | head -1)

if [ -z "$NPU_RESOURCE" ]; then
    NPU_RESOURCE="huawei.com/Ascend910"
fi

# 输出 JSON
cat <<EOF
{
  "npu_resource_type": "$NPU_RESOURCE",
  "volumes": [
    {"name": "model-storage", "mountPath": "/data", "hostPath": "${MODEL_PATH_HOST:-/data/models}"},
    {"name": "ascend-driver", "mountPath": "/usr/local/Ascend", "hostPath": "/usr/local/Ascend"},
    {"name": "ascend-toolkit", "mountPath": "/usr/local/Ascend/toolkit", "hostPath": "/usr/local/Ascend/toolkit"},
    {"name": "dsmi", "mountPath": "/usr/local/dsmi", "hostPath": "/usr/local/dsmi"},
    {"name": "dev-mount", "mountPath": "/dev", "hostPath": "/dev"},
    {"name": "sys-mount", "mountPath": "/sys", "hostPath": "/sys"},
    {"name": "log-mount", "mountPath": "/var/log/npu", "hostPath": "/var/log/npu"}
  ],
  "env_vars": {
    "HCCL_IF_IP": "\${NODE_IP}",
    "GLOO_SOCKET_IFNAME": "eth0",
    "MODEL_PATH": "\${MODEL_PATH}"
  },
  "resources": {
    "limits": {
      "cpu": "8",
      "memory": "64Gi",
      "$NPU_RESOURCE": "\${NPU_COUNT}"
    },
    "requests": {
      "cpu": "8",
      "memory": "64Gi",
      "$NPU_RESOURCE": "\${NPU_COUNT}"
    }
  },
  "security_context": {
    "privileged": true
  },
  "host_network": true
}
EOF