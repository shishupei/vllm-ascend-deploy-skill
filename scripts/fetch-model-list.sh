#!/bin/bash

# 抓取 vLLM-Ascend 模型列表页并提取模型名称和链接
# 输出格式：JSON

set -e

DEFAULT_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html"
URL="${1:-$DEFAULT_URL}"

# 检查 curl 是否可用
if ! command -v curl &> /dev/null; then
    echo '{"error": "curl not available"}'
    exit 1
fi

# 抓取页面
HTML=$(curl -s "$URL" 2>&1)
if [ $? -ne 0 ]; then
    echo '{"error": "Failed to fetch URL: ' "$URL" '"}'
    exit 1
fi

# 提取模型名称和链接（简化处理，实际需要根据页面结构调整）
# 假设模型链接格式为 <a href="ModelName.html">ModelName</a>
echo '{"models": ['

# 使用 grep 和 sed 提取（需要根据实际页面结构调整正则）
echo "$HTML" | grep -oP '<a href="[^"]+\.html"[^>]*>[^<]+</a>' | \
    sed -n 's/<a href="\([^"]+\)"[^>]*>\([^<]+\)<\/a>/{"name": "\2", "url": "\1"},/p' | \
    sed '$ s/,$//'

echo ']}'