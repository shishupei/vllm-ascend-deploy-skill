---
name: vllm-log-analyze
description: vLLM-Ascend 日志分析诊断 - 提取昇腾 NPU plog 日志、预筛错误模式、AI 诊断根因、给出修复建议
---

vLLM-Ascend 日志分析诊断 Skill，可独立触发使用。

## 前置条件

- 宿主机可以访问 plog 日志路径（昇腾驱动日志目录）
- 已运行 `/vllm-deploy-prepare` 并生成 `.vllm-deploy/config.json`（或在 Phase 1 通过问答创建）

## 触发方式

- `/vllm-log-analyze`
- `vllm 日志分析`

## 执行流程

按顺序读取以下模块并执行：

1. **Phase 1**: `modules/config-setup.md` - 配置获取/问答
2. **Phase 2**: `modules/log-fetcher.md` - 日志提取+预筛
3. **Phase 3**: `modules/error-analyzer.md` - 报错诊断+修复建议
4. **Phase 4**: `modules/report-generator.md` - 报告输出

## 输入

读取 `.vllm-deploy/config.json` 中的 `plog_config` 字段。
如果不存在，Phase 1 会通过交互问答创建。

## 输出

生成 `.vllm-deploy/log-analysis/` 目录，包含：
- `error-summary.json` - 预筛后的错误摘要
- `diagnosis-report.md` - AI 生成的诊断报告
- `raw-logs/` - 提取的原始日志片段

## 错误处理

- config.json 不存在 → Phase 1 通过交互问答创建
- plog_path 路径不存在 → 提示检查日志路径配置
- 日志文件为空 → 提示检查时间范围或日志级别配置
- 无错误条目 → 报告"当前时间段未检测到异常日志"