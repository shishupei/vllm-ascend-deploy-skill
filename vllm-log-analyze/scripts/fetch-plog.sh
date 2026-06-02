#!/bin/bash
# plog 日志提取脚本
# 读取昇腾 NPU plog 日志，按配置过滤时间窗口和日志级别
# 输出 JSON 结构供 filter-errors.sh 使用

set -e

# 参数处理
CONFIG_FILE="${1:-.vllm-deploy/config.json}"
OUTPUT_DIR="${2:-.vllm-deploy/log-analysis}"

echo "=== Plog Log Fetching ===" >&2

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    cat <<EOF
{
  "error": "config.json not found",
  "message": "Please run Phase 1 (config-setup) first, or run /vllm-deploy-prepare to create config.json"
}
EOF
    exit 1
fi

# 读取 plog 配置
PLOG_PATH=$(jq -r '.plog_config.plog_path // "/usr/local/Ascend/driver/log"' "$CONFIG_FILE")
PLOG_TYPES=$(jq -r '.plog_config.plog_types // ["device","host","app"]' "$CONFIG_FILE")
TIME_RANGE=$(jq -r '.plog_config.time_range // "last_24h"' "$CONFIG_FILE")
ERROR_LEVELS=$(jq -r '.plog_config.error_levels // ["ERROR","WARNING","CRITICAL"]' "$CONFIG_FILE")

# 检查日志路径
if [ ! -d "$PLOG_PATH" ]; then
    cat <<EOF
{
  "error": "plog path not found",
  "plog_path": "$PLOG_PATH",
  "message": "Please check the plog log path in config.json. Common paths: /usr/local/Ascend/driver/log, /var/log/ascend"
}
EOF
    exit 1
fi

echo "Plog path: $PLOG_PATH" >&2
echo "Time range: $TIME_RANGE" >&2
echo "Error levels: $ERROR_LEVELS" >&2

# 计算时间过滤的起始时间戳
calculate_start_time() {
    local range="$1"
    case "$range" in
        last_1h)  date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-1H '+%Y-%m-%d %H:%M:%S' ;;
        last_6h)  date -d '6 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-6H '+%Y-%m-%d %H:%M:%S' ;;
        last_24h) date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-24H '+%Y-%m-%d %H:%M:%S' ;;
        all)      echo "1970-01-01 00:00:00" ;;
        *)        date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-24H '+%Y-%m-%d %H:%M:%S' ;;
    esac
}

START_TIME=$(calculate_start_time "$TIME_RANGE")
echo "Start time: $START_TIME" >&2

# 创建输出目录
mkdir -p "$OUTPUT_DIR/raw-logs"

# 构建日志级别过滤正则
# 将 JSON 数组转为 grep 正则：ERROR|WARNING|CRITICAL
LEVEL_REGEX=$(echo "$ERROR_LEVELS" | jq -r '. | join("|")')

# 收集日志
TOTAL_FILES=0
TOTAL_LINES=0
FILTERED_LINES=0

# 使用临时文件收集各类型的日志 JSON
TEMP_DEVICE=$(mktemp)
TEMP_HOST=$(mktemp)
TEMP_APP=$(mktemp)
trap "rm -f '$TEMP_DEVICE' '$TEMP_HOST' '$TEMP_APP'" EXIT

# 遍历每种日志类型
for log_type in $(echo "$PLOG_TYPES" | jq -r '.[]'); do
    type_dir="$PLOG_PATH/$log_type"
    temp_file=""

    case "$log_type" in
        device) temp_file="$TEMP_DEVICE" ;;
        host)   temp_file="$TEMP_HOST" ;;
        app)    temp_file="$TEMP_APP" ;;
        *)      temp_file=$(mktemp); trap "rm -f '$temp_file'" EXIT ;;
    esac

    if [ ! -d "$type_dir" ]; then
        echo "Warning: log type directory '$type_dir' not found, skipping" >&2
        continue
    fi

    # 查找日志文件（glob 模式匹配，不硬编码文件名）
    log_files=$(find "$type_dir" -name "*.log" -o -name "*.log.*" 2>/dev/null | sort)

    if [ -z "$log_files" ]; then
        echo "Warning: no log files found in '$type_dir'" >&2
        continue
    fi

    echo "Processing $log_type logs: $(echo "$log_files" | wc -l) files" >&2

    # 逐文件提取日志
    for log_file in $log_files; do
        TOTAL_FILES=$((TOTAL_FILES + 1))
        file_basename=$(basename "$log_file")

        # 统计总行数
        file_lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)
        TOTAL_LINES=$((TOTAL_LINES + file_lines))

        # 过滤：时间窗口 + 日志级别
        # plog 日志格式通常为：[YYYY-MM-DD HH:MM:SS] [LEVEL] message
        # 使用 awk 做时间过滤（比 grep 更高效处理多条件）
        filtered=$(awk -v start="$START_TIME" -v levels="$LEVEL_REGEX" '
            BEGIN { start_ts = 0 }
            {
                # 尝试提取时间戳：[YYYY-MM-DD HH:MM:SS] 或 YYYY-MM-DD HH:MM:SS
                ts = ""
                if (match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})\]/, arr)) {
                    ts = arr[1]
                } else if (match($0, /([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/, arr)) {
                    ts = arr[1]
                }

                # 时间过滤
                if (ts != "" && ts >= start) {
                    # 级别过滤
                    for (i = 1; i <= NF; i++) {
                        if (match($i, levels)) {
                            level = $i
                            gsub(/[\[\]]/, "", level)
                            # 输出 JSON 行
                            printf "{\"timestamp\":\"%s\",\"level\":\"%s\",\"message\":\"%s\",\"source\":\"%s\"}\n",
                                   ts, level, $0, FILENAME
                            break
                        }
                    }
                }
            }
        ' "$log_file" 2>/dev/null)

        filtered_count=$(echo "$filtered" | grep -c "." 2>/dev/null || echo 0)
        FILTERED_LINES=$((FILTERED_LINES + filtered_count))

        # 将过滤结果追加到临时文件
        if [ -n "$filtered" ]; then
            echo "$filtered" >> "$temp_file"
            # 同时保存原始日志片段到 raw-logs/
            cp "$log_file" "$OUTPUT_DIR/raw-logs/${log_type}-${file_basename}" 2>/dev/null || true
        fi
    done

    echo "$log_type: $FILTERED_LINES filtered lines so far" >&2
done

# 使用 jq 合并各类型日志为数组（flatten 处理嵌套数组）
collect_logs() {
    local temp_file="$1"
    if [ -s "$temp_file" ]; then
        jq -s 'flatten' "$temp_file" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

device_logs=$(collect_logs "$TEMP_DEVICE")
host_logs=$(collect_logs "$TEMP_HOST")
app_logs=$(collect_logs "$TEMP_APP")

# 输出 JSON 结果
cat <<EOF
{
  "plog_path": "$PLOG_PATH",
  "time_range": "$TIME_RANGE",
  "start_time": "$START_TIME",
  "log_files_scanned": $TOTAL_FILES,
  "total_lines": $TOTAL_LINES,
  "filtered_lines": $FILTERED_LINES,
  "logs_by_type": {
    "device": $device_logs,
    "host": $host_logs,
    "app": $app_logs
  }
}
EOF

echo "" >&2
echo "Plog fetching completed. $FILTERED_LINES error lines extracted from $TOTAL_FILES files." >&2