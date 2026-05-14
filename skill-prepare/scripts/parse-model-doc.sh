#!/bin/bash
# Phase 3: 解析模型文档，提取启动脚本和镜像版本

set -e

usage() {
    echo "Usage: $0 --url <URL> --hw-spec <A3|A2> --deploy-mode <single_node|multi_node|pd_separate>"
    exit 1
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --url) URL="$2"; shift 2 ;;
        --hw-spec) HW_SPEC="$2"; shift 2 ;;
        --deploy-mode) DEPLOY_MODE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$URL" ] || [ -z "$HW_SPEC" ] || [ -z "$DEPLOY_MODE" ]; then
    usage
fi

echo "Parsing: $URL"
echo "HW Spec: $HW_SPEC"
echo "Deploy Mode: $DEPLOY_MODE"

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}'
    exit 1
fi

# 提取镜像版本（查找 vllm-ascend:v* 格式）
IMAGE_VERSION=$(echo "$HTML" | grep -oP 'vllm-ascend:v[0-9.]+' | head -1 | sed 's/vllm-ascend://')

if [ -z "$IMAGE_VERSION" ]; then
    IMAGE_VERSION="unknown"
fi

SOURCE_IMAGE="quay.io/vllm-ascend/vllm-ascend:$IMAGE_VERSION"

# 提取启动脚本块（查找 bash 代码块）
# 根据硬件规格和部署模式定位对应脚本
SCRIPT_BLOCK=$(echo "$HTML" | sed -n "/$HW_SPEC/,/\`\`\`/p" | grep -A 50 "vllm serve" | head -20)

# 输出 JSON
cat <<EOF
{
  "image_version": "$IMAGE_VERSION",
  "source_image": "$SOURCE_IMAGE",
  "hw_spec": "$HW_SPEC",
  "deploy_mode": "$DEPLOY_MODE",
  "script_template": "$SCRIPT_BLOCK"
}
EOF