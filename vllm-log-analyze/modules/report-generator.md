# Phase 4: 报告输出

## 目标

将 Phase 3 的诊断结果格式化为结构化报告，保存到 `.vllm-deploy/log-analysis/` 目录。

## 输入

- Phase 3 的三层诊断结果（AI 生成的文本）
- `.vllm-deploy/log-analysis/error-summary.json`（预筛数据）
- `vllm-log-analyze/templates/error-report.md`（报告模板）

## 执行步骤

### 步骤 1：读取报告模板

```bash
cat vllm-log-analyze/templates/error-report.md
```

### 步骤 2：填充报告模板

根据模板中的占位符，用诊断结果替换：

| 占位符 | 数据来源 |
|--------|---------|
| {{TIMESTAMP}} | 当前日期时间：`date '+%Y-%m-%d %H:%M:%S'` |
| {{TIME_RANGE}} | config.json → plog_config.time_range |
| {{PLOG_PATH}} | config.json → plog_config.plog_path |
| {{LOG_FILES_SCANNED}} | fetch-output.json → log_files_scanned |
| {{TOTAL_LINES}} | fetch-output.json → total_lines |
| {{FILTERED_LINES}} | fetch-output.json → filtered_lines |
| {{CATEGORIES_FOUND}} | error-summary.json → summary.categories_found |
| {{UNMATCHED_COUNT}} | error-summary.json → summary.unmatched_count |
| {{CRITICAL_SECTION}} | Phase 3 第一层诊断中 severity=critical 的部分 |
| {{HIGH_SECTION}} | Phase 3 第一层诊断中 severity=high 的部分 |
| {{MEDIUM_SECTION}} | Phase 3 第一层诊断中 severity=medium 的部分 |
| {{CORRELATION_ANALYSIS}} | Phase 3 第三层关联性分析 |
| {{UNMATCHED_ERRORS}} | Phase 3 第二层未知模式分析 |
| {{NEXT_STEPS}} | 基于诊断结果生成的操作清单 |

### 步骤 3：保存诊断报告

将填充后的报告写入文件：

```bash
# AI 代理将完整报告内容写入此文件
cat > .vllm-deploy/log-analysis/diagnosis-report.md <<'REPORT'
[AI 生成的完整报告内容]
REPORT
```

### 步骤 4：展示报告摘要

向用户展示关键发现：

```
=== 昇腾 NPU 日志诊断完成 ===

关键发现：
- 🔴 紧急问题：{critical_count} 个
- 🟠 高优先级：{high_count} 个
- 🟡 中优先级：{medium_count} 个
- ❓ 未识别：{unmatched_count} 条

最可能的底层根因：{root_cause_summary}
建议优先解决：{top_priority_category}

完整报告已保存到：.vllm-deploy/log-analysis/diagnosis-report.md
原始数据：.vllm-deploy/log-analysis/error-summary.json
```

询问用户是否需要进一步操作（如查看完整报告、针对某个问题深入分析、直接执行修复命令）。

## 输出

`.vllm-deploy/log-analysis/` 目录最终包含：

```
.vllm-deploy/log-analysis/
├── fetch-output.json      # Phase 2 脚本原始输出
├── error-summary.json     # 预筛后的错误摘要
├── diagnosis-report.md    # AI 生成的完整诊断报告
└── raw-logs/              # 原始日志文件副本
```

## AI 执行指南

1. 读取报告模板
2. 用 Phase 3 诊断结果填充模板
3. 用诊断数据补充概要表格
4. 写入 diagnosis-report.md
5. 展示关键发现摘要
6. 询问用户后续需求
7. Skill 执行完成

## 错误处理

| 场景 | 处理 |
|------|------|
| 报告模板缺失 | 使用内置默认格式生成报告 |
| 诊断结果为空 | 生成"无异常"报告 |
| 文件写入失败 | 检查目录权限和磁盘空间 |