#!/bin/bash

# 解析指定模型的文档页面，提取脚本内容和镜像版本
# 输出格式：JSON

MODEL_URL="$1"
HW_SPEC="$2"      # A3 或 A2
DEPLOY_MODE="$3"  # single_node, multi_node, pd_disagg

BASE_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/"

if [ -z "$MODEL_URL" ]; then
    echo '{"error": "MODEL_URL is required"}'
    exit 1
fi

# 参数验证
if [ -n "$HW_SPEC" ] && [ "$HW_SPEC" != "A3" ] && [ "$HW_SPEC" != "A2" ]; then
    echo '{"error": "HW_SPEC must be A3 or A2"}'
    exit 1
fi

if [ -n "$DEPLOY_MODE" ] && [ "$DEPLOY_MODE" != "single_node" ] && [ "$DEPLOY_MODE" != "multi_node" ] && [ "$DEPLOY_MODE" != "pd_disagg" ]; then
    echo '{"error": "DEPLOY_MODE must be single_node, multi_node, or pd_disagg"}'
    exit 1
fi

# 构建完整 URL
FULL_URL="${BASE_URL}${MODEL_URL}"

# 检查 curl 是否可用
if ! command -v curl &> /dev/null; then
    echo '{"error": "curl not available"}'
    exit 1
fi

# 抓取页面
HTML=$(curl -s "$FULL_URL" 2>&1) || {
    echo '{"error": "Failed to fetch URL: ' "$FULL_URL" '"}'
    exit 1
}

# 提取镜像版本（查找 quay.io/vllm-ascend/vllm-ascend:xxx）
IMAGE_VERSION=$(echo "$HTML" | grep -oP 'quay\.io\/vllm-ascend\/vllm-ascend:v[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# 提取脚本块（根据硬件规格和部署方式定位）
# 简化处理：查找 code block 并根据标题匹配
SCRIPT_BLOCK=$(echo "$HTML" | grep -A 50 "## ${HW_SPEC}" | grep -A 30 "${DEPLOY_MODE}" | \
    sed -n '/```bash/,/```/p' | sed '1d;$d')

# 输出 JSON
echo '{'
echo '"image_version": "' "$IMAGE_VERSION" '",'
echo '"script_content": "' "$SCRIPT_BLOCK" '",'
echo '"parameters": {}'
echo '}'