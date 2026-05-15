#!/bin/bash
# Phase 3: 解析模型文档，提取启动脚本和镜像版本

set -e

# JSON 字符串转义函数（用于手动构建 JSON 时防止注入）
escape_json_string() {
    local str="$1"
    str="${str//\\/\\\\}"      # 先转义反斜杠
    str="${str//\"/\\\"}"      # 再转义双引号
    str="${str//$'\n'/\\n}"    # 转义换行
    str="${str//$'\r'/\\r}"    # 转义回车
    str="${str//$'\t'/\\t}"    # 转义制表符
    echo "$str"
}

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

echo "Parsing: $URL" >&2
echo "HW Spec: $HW_SPEC" >&2
echo "Deploy Mode: $DEPLOY_MODE" >&2

# 根据部署模式确定搜索关键词
get_deploy_mode_pattern() {
    local mode="$1"
    case "$mode" in
        single_node)
            echo "single.*node|单机|standalone|SingleNode"
            ;;
        multi_node)
            echo "multi.*node|分布式|distributed|Ray.*cluster|MultiNode"
            ;;
        pd_separate)
            echo "PD.*分离|prefill.*decode|kv.*transfer|Mooncake|PD.*separate| disaggregated"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 根据硬件规格确定 NPU 数量提示
get_npu_count() {
    local hw="$1"
    case "$hw" in
        A3)
            echo "16"
            ;;
        A2)
            echo "8"
            ;;
        *)
            echo ""
            ;;
    esac
}

NPU_COUNT=$(get_npu_count "$HW_SPEC")
DEPLOY_PATTERN=$(get_deploy_mode_pattern "$DEPLOY_MODE")

echo "NPU Count: $NPU_COUNT" >&2
echo "Deploy Pattern: $DEPLOY_PATTERN" >&2

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}'
    exit 1
fi

# 根据部署模式定位相关章节内容
if [ -n "$DEPLOY_PATTERN" ]; then
    # 提取匹配部署模式的章节内容（扩展搜索范围以提高匹配率）
    SECTION_CONTENT=$(echo "$HTML" | grep -ziE -A 100 "$DEPLOY_PATTERN" | head -200)

    # 如果找到匹配章节，使用该章节；否则使用整个页面
    if [ -n "$SECTION_CONTENT" ]; then
        echo "Found matching section for $DEPLOY_MODE" >&2
        SEARCH_CONTENT="$SECTION_CONTENT"
    else
        echo "Warning: No matching section found, using full page" >&2
        SEARCH_CONTENT="$HTML"
    fi
else
    SEARCH_CONTENT="$HTML"
fi

# 在目标内容中提取镜像版本
IMAGE_VERSION=$(echo "$SEARCH_CONTENT" | grep -o 'vllm-ascend:v[0-9.]*' | head -1 | sed 's/vllm-ascend://')

if [ -z "$IMAGE_VERSION" ]; then
    # 回退到全局搜索
    IMAGE_VERSION=$(echo "$HTML" | grep -o 'vllm-ascend:v[0-9.]*' | head -1 | sed 's/vllm-ascend://')
fi

if [ -z "$IMAGE_VERSION" ]; then
    IMAGE_VERSION="unknown"
fi

SOURCE_IMAGE="quay.io/vllm-ascend/vllm-ascend:$IMAGE_VERSION"

# 在目标内容中提取默认参数
MAX_MODEL_LEN=$(echo "$SEARCH_CONTENT" | grep -o 'max-model-len[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")
TENSOR_PARALLEL=$(echo "$SEARCH_CONTENT" | grep -o 'tensor-parallel-size[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")

# 如果没有找到 tensor_parallel_size，根据 NPU 数量给出默认建议
if [ -z "$TENSOR_PARALLEL" ] && [ -n "$NPU_COUNT" ]; then
    TENSOR_PARALLEL="$NPU_COUNT"
    echo "Using default tensor_parallel_size=$NPU_COUNT for $HW_SPEC" >&2
fi

# 提取启动脚本块（在目标章节中搜索）
SCRIPT_BLOCK=$(echo "$SEARCH_CONTENT" | grep -A 20 'vllm serve' | head -20 | tr '\n' ' ' | sed 's/"/\\"/g')

# 输出 JSON（使用 jq 或正确拼接）
if command -v jq &> /dev/null; then
    jq -n \
        --arg img_ver "$IMAGE_VERSION" \
        --arg src_img "$SOURCE_IMAGE" \
        --arg hw "$HW_SPEC" \
        --arg mode "$DEPLOY_MODE" \
        --arg npu "$NPU_COUNT" \
        --arg script "$SCRIPT_BLOCK" \
        --arg max_len "$MAX_MODEL_LEN" \
        --arg tp "$TENSOR_PARALLEL" \
        '{
            image_version: $img_ver,
            source_image: $src_img,
            hw_spec: $hw,
            deploy_mode: $mode,
            npu_count: (if $npu == "" then null else ($npu | tonumber) end),
            script_template: $script,
            extracted_params: {
                max_model_len: (if $max_len == "" then null else ($max_len | tonumber) end),
                tensor_parallel_size: (if $tp == "" then null else ($tp | tonumber) end)
            }
        }'
else
    # 手动构建 JSON（需要转义）
    printf '{\n'
    printf '  "image_version": "%s",\n' "$(escape_json_string "$IMAGE_VERSION")"
    printf '  "source_image": "%s",\n' "$(escape_json_string "$SOURCE_IMAGE")"
    printf '  "hw_spec": "%s",\n' "$(escape_json_string "$HW_SPEC")"
    printf '  "deploy_mode": "%s",\n' "$(escape_json_string "$DEPLOY_MODE")"
    if [ -n "$NPU_COUNT" ]; then
        printf '  "npu_count": %s,\n' "$NPU_COUNT"
    else
        printf '  "npu_count": null,\n'
    fi
    printf '  "script_template": "%s",\n' "$(escape_json_string "$SCRIPT_BLOCK")"
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