#!/bin/bash
# Phase 1: 获取 vLLM-Ascend 支持的模型列表

set -e

DEFAULT_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html"
URL="${1:-$DEFAULT_URL}"

echo "Fetching model list from: $URL"

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}'
    exit 1
fi

# 提取模型链接（查找 toctree-l2 中的 reference internal 链接）
# 页面格式：<li class="toctree-l2"><a class="reference internal" href="ModelName.html">
MODELS=$(echo "$HTML" | grep 'class="reference internal" href=".*\.html"' | sed -n 's/.*href="\([A-Za-z0-9_.-]*\)\.html".*/\1.html/p' | grep -v "index.html" | grep -v "supported_models" | sort -u)

# 构建 JSON 输出（使用 jq 或正确拼接）
if command -v jq &> /dev/null; then
    # 使用 jq 构建 JSON
    echo "$MODELS" | jq -R -s 'split("\n") | map(select(length > 0)) | map({name: . | sub(".html$"; ""), url: .}) | {models: .}'
else
    # 手动构建 JSON
    echo '{"models": ['
    FIRST=true
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            NAME=$(basename "$url" .html)
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ','
            fi
            printf '{"name": "%s", "url": "%s"}' "$NAME" "$url"
        fi
    done <<< "$MODELS"
    echo ']}'
fi