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
IMAGE_VERSION=$(echo "$HTML" | grep -o 'vllm-ascend:v[0-9.]*' | head -1 | sed 's/vllm-ascend://')

if [ -z "$IMAGE_VERSION" ]; then
    IMAGE_VERSION="unknown"
fi

SOURCE_IMAGE="quay.io/vllm-ascend/vllm-ascend:$IMAGE_VERSION"

# 提取默认参数（从文档中提取常见参数值）
MAX_MODEL_LEN=$(echo "$HTML" | grep -o 'max-model-len[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")
TENSOR_PARALLEL=$(echo "$HTML" | grep -o 'tensor-parallel-size[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")

# 提取启动脚本块（简化版）
SCRIPT_BLOCK=$(echo "$HTML" | grep -A 20 'vllm serve' | head -20 | tr '\n' ' ' | sed 's/"/\\"/g')

# 输出 JSON（使用 jq 或正确拼接）
if command -v jq &> /dev/null; then
    jq -n \
        --arg img_ver "$IMAGE_VERSION" \
        --arg src_img "$SOURCE_IMAGE" \
        --arg hw "$HW_SPEC" \
        --arg mode "$DEPLOY_MODE" \
        --arg script "$SCRIPT_BLOCK" \
        --arg max_len "$MAX_MODEL_LEN" \
        --arg tp "$TENSOR_PARALLEL" \
        '{
            image_version: $img_ver,
            source_image: $src_img,
            hw_spec: $hw,
            deploy_mode: $mode,
            script_template: $script,
            extracted_params: {
                max_model_len: (if $max_len == "" then null else ($max_len | tonumber) end),
                tensor_parallel_size: (if $tp == "" then null else ($tp | tonumber) end)
            }
        }'
else
    # 手动构建 JSON（需要转义）
    printf '{\n'
    printf '  "image_version": "%s",\n' "$IMAGE_VERSION"
    printf '  "source_image": "%s",\n' "$SOURCE_IMAGE"
    printf '  "hw_spec": "%s",\n' "$HW_SPEC"
    printf '  "deploy_mode": "%s",\n' "$DEPLOY_MODE"
    printf '  "script_template": "%s",\n' "$SCRIPT_BLOCK"
    printf '  "extracted_params": {\n'
    if [ -n "$MAX_MODEL_LEN" ]; then
        printf '    "max_model_len": %s,\n' "$MAX_MODEL_LEN"
    else
        printf '    "max_model_len": null,\n'
    fi
    if [ -n "$TENSOR_PARALLEL" ]; then
        printf '    "tensor_parallel_size": %s\n' "$TENSOR_PARALLEL"
    else
        printf '    "tensor_parallel_size": null\n'
    fi
    printf '  }\n'
    printf '}\n'
fi