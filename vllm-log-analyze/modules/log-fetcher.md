# Phase 2: 日志提取+预筛

## 目标

运行脚本提取 plog 日志并预筛昇腾常见错误模式，生成结构化错误摘要供 AI 诊断使用。

## 前置条件

- Phase 1 已完成，`.vllm-deploy/config.json` 包含 `plog_config`
- plog 日志路径可访问

## 执行步骤

### 步骤 1：运行 fetch-plog.sh 提取日志

```bash
bash vllm-log-analyze/scripts/fetch-plog.sh .vllm-deploy/config.json .vllm-deploy/log-analysis > .vllm-deploy/log-analysis/fetch-output.json
```

验证输出：
```bash
jq -e '.plog_path' .vllm-deploy/log-analysis/fetch-output.json
jq -e '.filtered_lines' .vllm-deploy/log-analysis/fetch-output.json
```

如果 `filtered_lines` 为 0，说明当前时间段没有匹配级别的日志。向用户报告：
> "当前时间段未检测到异常日志（0 条错误条目）。建议扩大时间范围或检查日志路径是否正确。"

如果 `filtered_lines > 0`，继续步骤 2。

### 步骤 2：运行 filter-errors.sh 预筛错误模式

```bash
bash vllm-log-analyze/scripts/filter-errors.sh .vllm-deploy/log-analysis/fetch-output.json > .vllm-deploy/log-analysis/error-summary.json
```

验证输出：
```bash
jq -e '.matched_patterns' .vllm-deploy/log-analysis/error-summary.json
jq -e '.unmatched_errors' .vllm-deploy/log-analysis/error-summary.json
jq -e '.summary' .vllm-deploy/log-analysis/error-summary.json
```

### 步骤 3：展示预筛结果摘要

向用户展示错误摘要：

```
=== 日志预筛结果 ===

扫描了 {log_files_scanned} 个日志文件，提取 {filtered_lines} 条错误条目。

已识别错误类别：
- {category1} ({count1} 条, 严重等级: {severity1})
- {category2} ({count2} 条, 严重等级: {severity2})
...

未识别错误：{unmatched_count} 条

即将进入 AI 诊断阶段...
```

## 输出

`.vllm-deploy/log-analysis/` 目录包含：
- `fetch-output.json` — fetch-plog.sh 输出（原始提取结果）
- `error-summary.json` — filter-errors.sh 输出（预筛摘要）
- `raw-logs/` — 原始日志文件副本

## AI 执行指南

1. 执行 fetch-plog.sh，保存输出到 fetch-output.json
2. 检查 filtered_lines，如果为 0 提示用户并终止
3. 执行 filter-errors.sh，保存输出到 error-summary.json
4. 展示预筛结果摘要
5. 进入 Phase 3

## 错误处理

| 场景 | 处理 |
|------|------|
| plog_path 路径不存在 | 提示检查 config.json 中 plog_path 配置 |
| 日志文件为空 | 提示检查时间范围或 plog_types 设置 |
| 无错误条目 | 报告"未检测到异常"，建议扩大范围 |
| jq 命令失败 | 检查 JSON 输出是否完整，重试 |