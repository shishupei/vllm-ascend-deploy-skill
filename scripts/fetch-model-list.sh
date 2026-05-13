#!/bin/bash

# 抓取 vLLM-Ascend 模型列表页并提取模型名称和链接
# 输出格式：JSON

DEFAULT_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html"
URL="${1:-$DEFAULT_URL}"

# 检查 curl 是否可用
if ! command -v curl &> /dev/null; then
    echo '{"error": "curl not available"}'
    exit 1
fi

# 抓取页面
HTML=$(curl -s "$URL" 2>&1) || {
    echo '{"error": "Failed to fetch URL: ' "$URL" '"}'
    exit 1
}

# 提取模型名称和链接
# 匹配 class="reference internal" 的链接
# 过滤掉 ../ 导航链接、features/ 和 hardwares/ 子目录链接
MODELS=$(echo "$HTML" | grep -oP '<a class="reference internal" href="[^"]+\.html">[^<]+</a>' | \
    grep -v '\.\./' | \
    grep -v 'features/' | \
    grep -v 'hardwares/' | \
    sort -u | \
    sed -n 's/.*href="\([^"]*\)">\([^<]*\)<.*/{"name": "\2", "url": "\1"},/p' | \
    sed '$ s/,$//')

# 输出 JSON
echo '{'
echo '"models": ['

if [ -n "$MODELS" ]; then
    echo "$MODELS"
fi

echo ']'
echo '}'