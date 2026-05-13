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

# 提取镜像版本（匹配 quay.io/ascend/vllm-ascend:vxxx 格式）
# 版本号格式支持：v0.18.0rc1-a3, v0.18.0rc1, v0.9.0 等
IMAGE_VERSION=$(echo "$HTML" | grep -oP 'quay\.io\/ascend\/vllm-ascend:v[0-9]+\.[0-9]+\.[0-9]+[a-z0-9-]*' | head -1)

# 提取脚本块（根据部署方式定位 section）
# deploy_mode 映射到 HTML section id 前缀（支持模糊匹配）
case "$DEPLOY_MODE" in
    "single_node")
        SECTION_PREFIX="single-node-deployment"
        ;;
    "multi_node")
        # multi_node 可能有多种 section id:
        # - multi-node-deployment (简单版本)
        # - multi-node-deployment-with-mp-recommended (推荐版本)
        # - multi-node-deployment-with-ray (Ray 版本)
        SECTION_PREFIX="multi-node-deployment"
        ;;
    "pd_disagg")
        SECTION_PREFIX="prefill-decode-disaggregation"
        ;;
    *)
        SECTION_PREFIX="$DEPLOY_MODE"
        ;;
esac

# 使用 awk 提取 section 内的脚本块
# 策略：找到匹配的 section id -> 提取到下一个 section -> 找 highlight-shell -> 提取 pre 内容
SCRIPT_BLOCK=$(echo "$HTML" | awk -v prefix="$SECTION_PREFIX" '
BEGIN { found=0; in_pre=0; in_script=0; script="" }
{
    # 使用模糊匹配：section id 以 prefix 开头
    if (index($0, "<section id=\"" prefix) > 0) { found=1; next }
    # 如果找到另一个 section（不以 prefix 开头），则退出
    if (found && index($0, "<section id=") > 0 && index($0, prefix) == 0) { exit }
    if (found && index($0, "highlight-shell") > 0) { in_pre=1 }
    if (found && index($0, "highlight-bash") > 0) { in_pre=1 }
    if (in_pre && index($0, "<pre>") > 0) {
        in_script=1
        # 检查同一行是否有 </pre>（单行脚本）
        if (index($0, "</pre>") > 0) {
            in_script=0; in_pre=0; exit
        }
        next
    }
    if (in_script && index($0, "</pre>") > 0) { in_script=0; in_pre=0; exit }
    if (in_script) {
        gsub(/<[^>]*>/, "")     # 移除 HTML 标签
        gsub(/&nbsp;/, " ")     # 替换 HTML 实体
        gsub(/&lt;/, "<")       # 替换 HTML 实体
        gsub(/&gt;/, ">")       # 替换 HTML 实体
        gsub(/&amp;/, "\\&")    # 替换 HTML 实体
        gsub(/&#39;/, "'\''")   # 替换 HTML 实体
        gsub(/&quot;/, "\"")    # 替换 HTML 实体
        script = script $0 "\n"
    }
}
END { print script }
' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

# 如果提取失败，尝试备用方法：直接查找 vllm serve 命令
if [ -z "$SCRIPT_BLOCK" ] || [ -z "$(echo "$SCRIPT_BLOCK" | tr -d '[:space:]')" ]; then
    SCRIPT_BLOCK=$(echo "$HTML" | grep -oP 'vllm serve[^<]+' | head -1) 2>/dev/null || SCRIPT_BLOCK=""
fi

# 清理脚本块中的多余空白，但保留结构
SCRIPT_BLOCK=$(echo "$SCRIPT_BLOCK" | sed 's/\\n$//' | sed '/^$/d' | head -20)

# 输出 JSON
echo '{'
echo '"image_version": "' "$IMAGE_VERSION" '",'
echo '"script_content": "' "$SCRIPT_BLOCK" '",'
echo '"parameters": {}'
echo '}'