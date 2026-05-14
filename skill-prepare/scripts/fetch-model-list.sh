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

# 提取模型链接（假设链接格式为 tutorials/models/*.html）
# 使用 grep 和 sed 提取
MODELS=$(echo "$HTML" | grep -oP 'tutorials/models/[A-Za-z0-9_-]+\.html' | sort -u)

# 构建 JSON 输出
echo '{"models": ['

FIRST=true
while IFS= read -r url; do
    # 提取模型名称（去掉 .html 后缀）
    NAME=$(basename "$url" .html)

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ','
    fi

    echo "{\"name\": \"$NAME\", \"url\": \"$url\"}"
done <<< "$MODELS"

echo ']}'