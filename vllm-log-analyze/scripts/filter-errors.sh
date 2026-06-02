#!/bin/bash
# 昇腾错误模式预筛脚本
# 对 fetch-plog.sh 输出做正则匹配，分类统计已知错误模式
# 输出结构化错误摘要 JSON，供 AI 代理深度诊断使用

set -e

# 参数处理
FETCH_OUTPUT="${1:-.vllm-deploy/log-analysis/fetch-output.json}"

echo "=== Error Pattern Filtering ===" >&2

# 检查输入文件
if [ ! -f "$FETCH_OUTPUT" ]; then
    cat <<EOF
{
  "error": "fetch output not found",
  "message": "Please run fetch-plog.sh first to generate fetch-output.json"
}
EOF
    exit 1
fi

# 错误模式定义（与 ascend-error-patterns.md 知识库对应）
# 每个类别使用独立的正则，避免管道分隔符冲突
# 格式：类别名|合并正则（用换行分隔不同类别）
PATTERN_HCCL="HCCL.*(timeout|error|fail|abort)|HCCS.*(timeout|error|fail)|rank.*(timeout|disconnect|fail)"
PATTERN_TIMEOUT="(TS|task|execute|kernel|op).*timeout|timeout.*(davinci|npu|device|execute)"
PATTERN_OOM="OOM|out of memory|memory alloc(ation)? failed|memory exceed|CANN.*memory"
PATTERN_DEVICE="(device|dev[0-9]+|davinci[0-9]+).*(error|fault|fail|abnormal|reset)|(NPU|npu).*(error|fault|fail|abnormal|offline)"
PATTERN_DRIVER="(driver|drv).*(error|fail|crash|version mismatch|incompatible)|(firmware|fw).*(error|fail|version mismatch|upgrade)|CANN.*(error|fail|init failed)"
PATTERN_RESOURCE="(resource|device).*(exhausted|not available|unavailable|busy|occupied)|(no available|cannot find).*(device|npu|davinci)"
PATTERN_ALIGN="(alignment|shape|dtype|type).*(error|mismatch|not match|incompatible)|(tensor|data).*(cast|convert|transform).*(error|fail)"

# 类别与正则的映射（数组，顺序遍历）
CATEGORIES=("HCCL通信" "设备超时" "内存溢出" "设备异常" "驱动错误" "资源不足" "数据对齐")
PATTERNS=("PATTERN_HCCL" "PATTERN_TIMEOUT" "PATTERN_OOM" "PATTERN_DEVICE" "PATTERN_DRIVER" "PATTERN_RESOURCE" "PATTERN_ALIGN")

# 严重等级映射
SEVERITY_HCCL="high"
SEVERITY_TIMEOUT="high"
SEVERITY_OOM="critical"
SEVERITY_DEVICE="critical"
SEVERITY_DRIVER="high"
SEVERITY_RESOURCE="medium"
SEVERITY_ALIGN="medium"
SEVERITIES=("SEVERITY_HCCL" "SEVERITY_TIMEOUT" "SEVERITY_OOM" "SEVERITY_DEVICE" "SEVERITY_DRIVER" "SEVERITY_RESOURCE" "SEVERITY_ALIGN")

# 提取所有日志条目（合并三种类型）
ALL_LOGS=$(jq '
    .logs_by_type.device +
    .logs_by_type.host +
    .logs_by_type.app
' "$FETCH_OUTPUT" 2>/dev/null || echo "[]")

TOTAL_ERRORS=$(echo "$ALL_LOGS" | jq 'length' 2>/dev/null || echo 0)
echo "Total error entries to filter: $TOTAL_ERRORS" >&2

# 如果没有错误条目，直接返回空结果
if [ "$TOTAL_ERRORS" -eq 0 ]; then
    cat <<EOF
{
  "matched_patterns": [],
  "unmatched_errors": [],
  "summary": {
    "total_errors": 0,
    "matched_count": 0,
    "unmatched_count": 0,
    "categories_found": []
  }
}
EOF
    exit 0
fi

# 使用临时文件收集匹配结果
TEMP_MATCHED=$(mktemp)
trap "rm -f '$TEMP_MATCHED'" EXIT
# 不写入初始内容，保持空文件，用 jq -s 在最后合并

# 遍历每个模式类别
for i in "${!CATEGORIES[@]}"; do
    category="${CATEGORIES[$i]}"
    # 获取正则变量的值（间接引用）
    pattern_var="${PATTERNS[$i]}"
    full_regex="${!pattern_var}"
    # 获取严重等级变量的值
    severity_var="${SEVERITIES[$i]}"
    default_severity="${!severity_var}"

    echo "Filtering category: $category" >&2

    # 从 ALL_LOGS 中匹配此类别
    MATCHED_ENTRIES=$(echo "$ALL_LOGS" | jq -c --arg regex "$full_regex" '
        [.[] | select(.message | test($regex; "i"))]
    ' 2>/dev/null || echo "[]")

    MATCHED_COUNT=$(echo "$MATCHED_ENTRIES" | jq 'length' 2>/dev/null || echo 0)

    if [ "$MATCHED_COUNT" -eq 0 ]; then
        echo "No matches for $category" >&2
        continue
    fi

    echo "Found $MATCHED_COUNT matches for $category" >&2

    # 统计时间范围
    FIRST_OCC=$(echo "$MATCHED_ENTRIES" | jq -r '[.[] | .timestamp] | sort | .[0]' 2>/dev/null || echo "unknown")
    LAST_OCC=$(echo "$MATCHED_ENTRIES" | jq -r '[.[] | .timestamp] | sort | .[-1]' 2>/dev/null || echo "unknown")

    # 提取样本消息（最多 5 条）
    SAMPLES=$(echo "$MATCHED_ENTRIES" | jq -r '[.[] | .message][0:5]' 2>/dev/null || echo "[]")

    # 确定严重等级（含动态调整）
    severity="$default_severity"
    # 高频 HCCL 升级为 critical
    if [ "$category" = "HCCL通信" ] && [ "$MATCHED_COUNT" -gt 10 ]; then
        severity="critical"
    fi
    # 低频设备超时降级为 medium
    if [ "$category" = "设备超时" ] && [ "$MATCHED_COUNT" -lt 3 ]; then
        severity="medium"
    fi

    # 构建此类别的匹配结果
    CATEGORY_RESULT=$(jq -n \
        --arg cat "$category" \
        --arg pat "$full_regex" \
        --argjson count "$MATCHED_COUNT" \
        --arg first "$FIRST_OCC" \
        --arg last "$LAST_OCC" \
        --argjson samples "$SAMPLES" \
        --arg severity "$severity" \
        '{
            category: $cat,
            pattern: $pat,
            count: $count,
            first_occurrence: $first,
            last_occurrence: $last,
            sample_messages: $samples,
            severity: $severity
        }')

    # 追加到临时文件
    echo "$CATEGORY_RESULT" >> "$TEMP_MATCHED"

done

# 合并所有匹配结果为数组
if [ -s "$TEMP_MATCHED" ]; then
    MATCHED_ARRAY=$(jq -s '.' "$TEMP_MATCHED" 2>/dev/null || echo "[]")
else
    MATCHED_ARRAY="[]"
fi

# 构建所有匹配正则的合并正则（用于过滤未匹配条目）
COMBINED_REGEX=""
for i in "${!CATEGORIES[@]}"; do
    pattern_var="${PATTERNS[$i]}"
    part="${!pattern_var}"
    if [ -n "$COMBINED_REGEX" ]; then
        COMBINED_REGEX="${COMBINED_REGEX}|${part}"
    else
        COMBINED_REGEX="${part}"
    fi
done

# 过滤出未匹配条目
if [ -n "$COMBINED_REGEX" ]; then
    UNMATCHED=$(echo "$ALL_LOGS" | jq -c --arg regex "$COMBINED_REGEX" '
        [.[] | select(.message | test($regex; "i") | not)]
    ' 2>/dev/null || echo "[]")
else
    UNMATCHED="$ALL_LOGS"
fi

UNMATCHED_COUNT=$(echo "$UNMATCHED" | jq 'length' 2>/dev/null || echo 0)
MATCHED_COUNT=$(echo "$MATCHED_ARRAY" | jq 'length' 2>/dev/null || echo 0)
CATEGORIES_FOUND=$(echo "$MATCHED_ARRAY" | jq -r '[.[] | .category]' 2>/dev/null || echo "[]")

# 输出结果
cat <<EOF
{
  "matched_patterns": $MATCHED_ARRAY,
  "unmatched_errors": $UNMATCHED,
  "summary": {
    "total_errors": $TOTAL_ERRORS,
    "matched_count": $MATCHED_COUNT,
    "unmatched_count": $UNMATCHED_COUNT,
    "categories_found": $CATEGORIES_FOUND
  }
}
EOF

echo "" >&2
echo "Error filtering completed. $MATCHED_COUNT categories matched, $UNMATCHED_COUNT unmatched errors." >&2