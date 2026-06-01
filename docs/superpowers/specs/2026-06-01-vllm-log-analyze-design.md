# vLLM-Log-Analyze Skill 设计规格

> 日期：2026-06-01
> 状态：设计确认，待实现

## 背景

vLLM-Ascend 部署完成后或日常运维中，昇腾 NPU 可能出现各类错误（HCCL 通信失败、设备超时、内存溢出等）。当前项目只覆盖部署流程，缺少日志诊断能力。

本 Skill 创建一个 **独立的日志分析诊断工具**，可以在任何时候单独触发，不依赖部署流程。

## 需求

| 维度 | 决定 |
|------|------|
| Skill 类型 | 独立诊断 Skill，不依赖部署流程 |
| plog 含义 | 昇腾 NPU 专用日志（固定格式和路径） |
| 分析深度 | 完整链路：提取 → 诊断 → 修复指导 |
| 配置文件 | 复用 `.vllm-deploy/config.json`，新增 `plog_config` 字段 |
| 无配置时 | 交互问答让用户提供路径，保存到 config.json |
| 技术方案 | 规则预筛 + AI 诊断（方案 B） |

## 方案选型

### 方案 A：纯 AI 驱动
脚本只读取日志，全部交给 AI 分析。最轻量但依赖 AI 对昇腾特有错误的理解，token 消耗高。

### 方案 B：规则预筛 + AI 诊断 ⭐（选定）
脚本先做模式匹配预筛（grep 已知昇腾错误模式），生成结构化错误摘要 JSON，AI 再做深度诊断。对常见错误精准识别，AI 补充盲区，与项目风格一致。

### 方案 C：知识库 + 规则 + AI
创建昇腾错误知识库对照表，已知问题秒出答案，AI 处理未知。初期工作量最大，需持续维护知识库。

**选择方案 B 的理由：**
1. 与现有 Skill 模式一致（脚本做确定性操作 + AI 做智能判断）
2. 昇腾 NPU 错误模式相对固定，规则预筛覆盖大部分常见问题
3. YAGNI — 知识库增加了维护负担，初期收益不确定
4. 渐进增强 — 后续可随时升级为知识库方案

## Skill 结构

```
vllm-ascend-deploy-skill/
├── vllm-deploy-prepare/        # 已有：部署准备
├── vllm-deploy-execute/        # 已有：部署执行
├── vllm-log-analyze/           # 新增：日志分析诊断
│   ├── SKILL.md                # Skill 入口定义
│   ├── modules/
│   │   ├── config-setup.md     # Phase 1：配置获取/问答
│   │   ├── log-fetcher.md      # Phase 2：日志提取+预筛
│   │   ├── error-analyzer.md   # Phase 3：报错诊断+修复建议
│   │   └── report-generator.md # Phase 4：报告输出
│   ├── scripts/
│   │   ├── fetch-plog.sh       # 读取 plog 日志并提取关键信息
│   │   └── filter-errors.sh    # 预筛昇腾常见错误模式
│   ├── knowledge/
│   │   └── ascend-error-patterns.md  # 昇腾错误模式对照表
│   └── templates/
│       └── error-report.md     # 报告输出模板
```

**触发词：** `/vllm-log-analyze` 或 `vllm 日志分析`

## 配置体系

在 `.vllm-deploy/config.json` 中新增 `plog_config` 字段：

```json
{
  // ... 现有部署字段保持不变 ...

  "plog_config": {
    "plog_path": "/usr/local/Ascend/driver/log",
    "plog_types": ["device", "host", "app"],
    "time_range": "last_24h",
    "error_levels": ["ERROR", "WARNING", "CRITICAL"]
  }
}
```

| 字段 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| `plog_path` | string | plog 日志在宿主机上的根路径 | `/usr/local/Ascend/driver/log` |
| `plog_types` | string[] | 要分析的日志子目录类型 | `["device", "host", "app"]` |
| `time_range` | string | 分析的时间窗口 | `last_24h` |
| `error_levels` | string[] | 提取哪些级别的日志条目 | `["ERROR", "WARNING", "CRITICAL"]` |

**time_range 取值：** `last_1h` / `last_6h` / `last_24h` / `all`

### Phase 1 配置获取流程

1. 检查 `.vllm-deploy/config.json` 是否存在
   - 存在 → 读取 `plog_config` 字段
   - 不存在 → 创建 `.vllm-deploy/` 目录和最小 `config.json`
2. 如果 `plog_config` 缺失或为空 → 交互问答：
   - Q1：plog 日志路径在哪？（默认 `/usr/local/Ascend/driver/log`）
   - Q2：要分析哪些类型的日志？（多选：device/host/app）
   - Q3：分析最近多久的日志？（1h/6h/24h/全部）
   - Q4：提取哪些级别的日志？（ERROR/WARNING/CRITICAL）
3. 保存问答结果到 `config.json` 的 `plog_config` 字段

## 脚本设计

### fetch-plog.sh — 读取 plog 日志

**输入：** config.json 中的 plog_path、plog_types、time_range、error_levels

**工作流程：**
1. 读取 config.json 获取配置参数
2. 根据 plog_types 遍历对应子目录（device/host/app）
3. 根据 time_range 过滤时间窗口
4. 根据 error_levels 过滤日志级别
5. 输出 JSON 结构

**输出格式：**
```json
{
  "plog_path": "/usr/local/Ascend/driver/log",
  "log_files_scanned": 12,
  "total_lines": 45678,
  "filtered_lines": 234,
  "logs_by_type": {
    "device": [
      {
        "timestamp": "2026-06-01 10:23:45",
        "level": "ERROR",
        "message": "...",
        "source": "device-0.log"
      }
    ],
    "host": [],
    "app": []
  }
}
```

### filter-errors.sh — 预筛昇腾常见错误模式

**输入：** fetch-plog.sh 的输出 JSON

**工作流程：**
1. 读取 fetch-plog.sh 输出的 JSON
2. 对每条日志按昇腾常见错误模式做正则匹配
3. 分类统计匹配结果
4. 输出结构化错误摘要

**预筛的错误模式类别：**

| 类别 | 模式关键词 | 典型含义 |
|------|-----------|---------|
| HCCL 通信 | `HCCL_*`, `HCCS_*`, `rank_id`, `timeout` | NPU 间通信失败 |
| 设备超时 | `TS timeout`, `task timeout`, `execute timeout` | NPU 执行任务超时 |
| 内存溢出 | `OOM`, `out of memory`, `memory alloc failed` | NPU 或主机内存不足 |
| 设备异常 | `device error`, `dev* error`, `davinci*` | NPU 设备硬件错误 |
| 驱动错误 | `driver error`, `drv* error`, `firmware` | 昇腾驱动或固件问题 |
| 资源不足 | `resource exhausted`, `no available device` | NPU 资源被占用/不可用 |
| 数据对齐 | `alignment error`, `shape mismatch`, `dtype mismatch` | 数据格式/类型问题 |

**输出格式：**
```json
{
  "matched_patterns": [
    {
      "category": "HCCL通信",
      "pattern": "HCCL timeout",
      "count": 15,
      "first_occurrence": "2026-06-01 10:23:45",
      "last_occurrence": "2026-06-01 10:45:12",
      "sample_messages": ["HCCL timeout on rank 3..."],
      "severity": "high"
    }
  ],
  "unmatched_errors": [
    {
      "timestamp": "...",
      "level": "ERROR",
      "message": "...",
      "source": "..."
    }
  ],
  "summary": {
    "total_errors": 234,
    "matched_count": 189,
    "unmatched_count": 45,
    "categories_found": ["HCCL通信", "设备超时"]
  }
}
```

## 知识库设计

### ascend-error-patterns.md

昇腾 NPU 错误模式对照表，供脚本和 AI 代理共同参考。

**结构：** 每个错误类别包含：
- **模式定义**：正则表达式（脚本用）+ 关键词描述（AI 用）
- **常见根因**：3-5 条典型根因
- **诊断步骤**：排查命令和检查项
- **修复建议**：具体操作步骤和命令
- **关联模式**：哪些其他错误常与此类同时出现

示例结构：
```markdown
## HCCL 通信错误

### 模式
- 正则：`HCCL.*(?:timeout|error|fail)`
- 关键词：HCCL, HCCS, rank_id, collective

### 常见根因
1. 网络拓扑配置错误（rank 映射不一致）
2. NPU 间 RDMA 链路异常
3. 集合通信算子参数不匹配

### 诊断步骤
1. `npu-smi info -t board` 检查 NPU 卡状态
2. `cat /etc/hccn.conf` 检查网络拓扑
3. `hccl_test` 运行通信测试

### 修复建议
1. 核对所有节点的 hccn.conf 确保一致
2. 重启异常 NPU 卡：`npu-smi set -t reset -i <id>`
3. 检查物理链路：光模块、网线

### 关联模式
- 设备超时（HCCL 超时常导致后续任务超时）
- 设备异常（NPU 硬件故障可表现为通信错误）
```

## AI 诊断模块设计

### Phase 3：error-analyzer.md — 三层诊断

**第一层：已知模式直接诊断**
- 对 `matched_patterns` 中每个类别，结合 `ascend-error-patterns.md` 给出：
  - 根因分析
  - 修复建议（含具体命令）
  - 优先级（紧急/高/中/低）

**第二层：未知模式深度分析**
- 对 `unmatched_errors` 中的每条错误：
  - AI 用自身知识分析可能根因
  - 给出排查方向
  - 标记置信度（高/中/低）

**第三层：关联性分析**
- 跨类别分析错误是否有关联（如 HCCL 超时可能是设备异常的连锁反应）
- 判断根因是否是同一个底层问题
- 给出整体诊断结论

## 报告输出设计

### Phase 4：report-generator.md

生成结构化诊断报告，保存到 `.vllm-deploy/log-analysis/`：

```
.vllm-deploy/log-analysis/
├── error-summary.json      # filter-errors.sh 的原始输出
├── diagnosis-report.md     # AI 生成的诊断报告
└── raw-logs/               # 提取的原始日志片段（可选保留）
```

### 报告模板结构

```markdown
# 昇腾 NPU 日志诊断报告

## 概要
- 分析时间范围：xxx
- 扫描日志文件：xx 个
- 发现错误总数：xx 条
- 已识别类别：xx 个

## 🔴 紧急问题
### 1. HCCL 通信超时
- **根因**：xxx
- **修复建议**：xxx
- **执行命令**：xxx

## 🟠 高优先级问题
...

## 🟡 中优先级问题
...

## 关联性分析
...

## 未识别错误
...

## 建议的下一步操作
1. xxx
2. xxx
```

## 完整工作流

```
/vllm-log-analyze 触发
  │
  ├─ Phase 1: config-setup.md
  │   检查 config.json → 问答获取 plog 配置 → 保存到 config.json
  │
  ├─ Phase 2: log-fetcher.md
  │   调用 fetch-plog.sh → 提取日志
  │   调用 filter-errors.sh → 预筛错误模式 → 生成 error-summary.json
  │
  ├─ Phase 3: error-analyzer.md
  │   读取 error-summary.json + ascend-error-patterns.md
  │   → 三层诊断：已知诊断 → 未知分析 → 关联性分析
  │
  ├─ Phase 4: report-generator.md
  │   → 生成 diagnosis-report.md + raw-logs/
  │   → 展示给用户，确认是否需要进一步操作
  │
  └─ 输出交付
```

## SKILL.md 设计

```yaml
---
name: vllm-log-analyze
description: vLLM-Ascend 日志分析诊断 - 提取昇腾 NPU plog 日志、预筛错误模式、AI 诊断根因、给出修复建议
---

vLLM-Ascend 日志分析诊断 Skill，可独立触发使用。

## 前置条件

- 已运行 `/vllm-deploy-prepare` 并生成 `.vllm-deploy/config.json`（或在 Phase 1 通过问答创建）
- 宿主机可以访问 plog 日志路径

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

- config.json 不存在 → Phase 1 通过问答创建
- plog_path 路径不存在 → 提示检查日志路径配置
- 日志文件为空 → 提示检查时间范围或日志级别配置
- 无错误条目 → 报告"当前时间段未检测到异常日志"
```

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| config.json 不存在 | Phase 1 通过交互问答创建 |
| plog_path 路径不存在 | 提示用户检查日志路径是否正确 |
| 日志文件为空 | 提示检查时间范围或日志级别配置 |
| 无错误条目 | 报告"当前时间段未检测到异常日志" |
| 脚本执行失败 | 展示错误信息，建议手动检查 |

## 与现有 Skill 的关系

- **独立使用**：不需要先运行部署流程，可随时触发
- **复用 config.json**：与部署 Skill 共享配置文件，部署过的用户直接复用 plog 配置
- **输出位置统一**：诊断报告存放在 `.vllm-deploy/log-analysis/`，与部署产物在同一个目录树下

## 后续扩展方向

- 升级为方案 C（知识库 + 规则 + AI），将 ascend-error-patterns.md 扩展为完整的错误知识库
- 增加实时监控模式（定期分析新日志）
- 增加与部署 Skill 的联动：部署失败时自动触发日志分析