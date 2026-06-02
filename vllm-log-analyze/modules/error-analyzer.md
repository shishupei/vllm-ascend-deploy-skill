# Phase 3: 报错诊断+修复建议

## 目标

对 Phase 2 预筛出的错误做三层诊断：
1. 已知模式直接诊断
2. 未知模式深度分析
3. 关联性分析

## 输入

- `.vllm-deploy/log-analysis/error-summary.json` — 预筛结果
- `vllm-log-analyze/knowledge/ascend-error-patterns.md` — 错误模式知识库

## 三层诊断流程

### 第一层：已知模式直接诊断

对 `error-summary.json` 中 `matched_patterns` 的每个类别：

1. 读取 `ascend-error-patterns.md` 中对应类别的详细信息
2. 结合匹配的日志条目（`sample_messages`、`first_occurrence`、`last_occurrence`、`count`），给出：
   - **根因分析**：根据知识库中的常见根因，结合实际日志内容判断最可能的根因
   - **修复建议**：从知识库的修复建议中选择适合当前情况的步骤，给出具体命令
   - **优先级**：使用 `severity` 字段，按 🔴 紧急 / 🟠 高 / 🟡 中 分级

输出格式（每个类别）：

```
### [类别名] ([count] 条, 严重等级: [severity])

**根因分析：**
[基于知识库和日志内容的分析]

**修复建议：**
1. [具体步骤1 + 命令]
2. [具体步骤2 + 命令]
...

**诊断依据：**
- 首次出现：[first_occurrence]
- 最后出现：[last_occurrence]
- 样本日志：[sample_messages 前3条]
```

### 第二层：未知模式深度分析

对 `error-summary.json` 中 `unmatched_errors` 的每条错误：

1. 分析日志消息内容，判断可能属于哪个领域（硬件/网络/软件/配置）
2. 搜索是否与已知类别有隐含关联
3. 给出：
   - **可能根因**：AI 基于自身知识推断
   - **排查方向**：建议的检查命令和步骤
   - **置信度**：高（有明确线索）/ 中（有模糊线索）/ 低（无法判断）

输出格式：

```
### 未识别错误 #N

**日志内容：** [原始 message]
**时间：** [timestamp]
**来源：** [source]

**可能根因：** [AI 分析]
**排查方向：** [建议步骤]
**置信度：** [高/中/低]
```

如果 `unmatched_errors` 数量超过 20，只分析前 20 条，其余列出时间戳和级别供参考。

### 第三层：关联性分析

1. 检查 `matched_patterns` 中各类别的时间关联：
   - 是否在同一时间段集中爆发？
   - 是否有先后顺序（如 HCCL 超时 → 设备超时 → 内存溢出）？
2. 检查 `matched_patterns` 与 `unmatched_errors` 的关联
3. 判断是否是同一个底层问题导致的连锁反应
4. 给出整体诊断结论：

```
### 关联性分析

**错误爆发时间：** [集中时间段]
**因果链推断：** [类别A] → [类别B] → [类别C]
**底层根因：** [最可能的单一根因]
**建议优先解决：** [最关键的类别]
```

## AI 执行指南

1. 读取 error-summary.json 和 ascend-error-patterns.md
2. 对每个 matched_patterns 类别做第一层诊断
3. 对 unmatched_errors 做第二层分析（限制 20 条）
4. 做第三层关联性分析
5. 将三层诊断结果汇总，作为 Phase 4 报告的输入
6. 进入 Phase 4

## 重要提示

- 诊断必须引用具体的日志内容，不能笼统概括
- 修复建议必须包含可执行的命令，不能只说"检查配置"
- 优先级标记必须与 error-summary.json 中的 severity 对应
- 关联性分析必须有因果推断逻辑，不能简单罗列