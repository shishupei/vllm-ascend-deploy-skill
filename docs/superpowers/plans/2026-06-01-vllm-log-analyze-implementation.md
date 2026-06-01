# vLLM-Log-Analyze 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现独立的昇腾 NPU plog 日志分析诊断 Skill，通过规则预筛 + AI 诊断实现提取 → 诊断 → 修复指导的完整链路。

**架构：** 4 Phase 流程：配置获取 → 日志提取+预筛 → AI 三层诊断 → 报告输出。脚本做确定性操作（读取/过滤日志），AI 代理做智能判断（诊断根因、给出修复建议）。配置复用 `.vllm-deploy/config.json`，独立触发不依赖部署流程。

**技术栈：** Bash + jq（脚本层）、Markdown（Skill/模块定义）、AI 代理（诊断层）

---

## 文件结构与职责

| 文件 | 职责 | 创建/修改 |
|------|------|-----------|
| `vllm-log-analyze/SKILL.md` | Skill 入口定义：触发词、流程、前置条件 | 创建 |
| `vllm-log-analyze/modules/config-setup.md` | Phase 1：配置获取/问答流程描述 | 创建 |
| `vllm-log-analyze/modules/log-fetcher.md` | Phase 2：日志提取+预筛流程描述 | 创建 |
| `vllm-log-analyze/modules/error-analyzer.md` | Phase 3：AI 三层诊断流程描述 | 创建 |
| `vllm-log-analyze/modules/report-generator.md` | Phase 4：报告输出流程描述 | 创建 |
| `vllm-log-analyze/scripts/fetch-plog.sh` | 读取 plog 日志，按配置过滤提取 | 创建 |
| `vllm-log-analyze/scripts/filter-errors.sh` | 预筛昇腾常见错误模式，生成结构化摘要 | 创建 |
| `vllm-log-analyze/knowledge/ascend-error-patterns.md` | 昇腾错误模式对照表（脚本+AI 共用） | 创建 |
| `vllm-log-analyze/templates/error-report.md` | 诊断报告输出模板 | 创建 |

---

### 任务 1：创建目录结构和 SKILL.md

**文件：**
- 创建：`vllm-log-analyze/SKILL.md`

- [ ] **步骤 1：创建 vllm-log-analyze 目录结构**

```bash
mkdir -p vllm-log-analyze/modules
mkdir -p vllm-log-analyze/scripts
mkdir -p vllm-log-analyze/knowledge
mkdir -p vllm-log-analyze/templates
```

- [ ] **步骤 2：编写 SKILL.md**

```markdown
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
```

- [ ] **步骤 3：验证目录结构**

```bash
find vllm-log-analyze -type d | sort
```

预期输出：
```
vllm-log-analyze
vllm-log-analyze/modules
vllm-log-analyze/scripts
vllm-log-analyze/knowledge
vllm-log-analyze/templates
```

- [ ] **步骤 4：Commit**

```bash
git add vllm-log-analyze/SKILL.md
git commit -m "feat(log-analyze): add SKILL.md entry point"
```

---

### 任务 2：创建昇腾错误模式对照表

**文件：**
- 创建：`vllm-log-analyze/knowledge/ascend-error-patterns.md`

这是脚本和 AI 代理共同参考的基础文件。脚本用正则模式做 grep 预筛，AI 代理用根因/修复信息做深度诊断。

- [ ] **步骤 1：编写 ascend-error-patterns.md**

内容必须覆盖 7 个错误类别，每个类别包含：正则模式、关键词、常见根因、诊断步骤、修复建议、关联模式。

```markdown
# 昇腾 NPU 错误模式对照表

供 `filter-errors.sh`（正则预筛）和 AI 代理（深度诊断）共同参考。

## 1. HCCL 通信错误

### 正则模式
```
HCCL.*(?:timeout|error|fail|abort)
HCCS.*(?:timeout|error|fail)
rank.*(?:timeout|disconnect|fail)
```

### 关键词
HCCL, HCCS, rank_id, collective, allreduce, broadcast

### 常见根因
1. 网络拓扑配置错误（rank 映射不一致或 hccn.conf 配置不当）
2. NPU 间 RDMA/RoCE 链路异常（光模块故障、网线松动）
3. 集合通信算子参数不匹配（tensor_parallel_size 与实际 NPU 数不符）
4. 防火墙或网络策略阻断 NPU 间通信端口

### 诊断步骤
1. `npu-smi info -t board` — 检查 NPU 卡状态
2. `cat /etc/hccn.conf` — 检查网络拓扑配置是否一致
3. `hccl_test -p 8` — 运行 HCCL 通信测试
4. `ip addr show` — 检查 RDMA 网卡状态
5. 检查集群所有节点的 hccn.conf 是否一致

### 修复建议
1. 核对所有节点的 `/etc/hccn.conf`，确保 rank_id 映射一致
2. 重启异常 NPU 卡：`npu-smi set -t reset -i <device_id>`
3. 检查物理链路：光模块插紧、网线完好、RDMA 网卡 UP
4. 确认 `tensor_parallel_size` 与实际可用 NPU 数量匹配
5. 如有防火墙，开放 HCCL 通信端口（默认 29500）

### 关联模式
- 设备超时（HCCL 超时常导致后续任务超时）
- 设备异常（NPU 硬件故障可表现为通信错误）
- 资源不足（NPU 资源不足导致 rank 分配失败）

---

## 2. 设备超时错误

### 正则模式
```
(?:TS|task|execute|kernel|op).*timeout
timeout.*(?:davinci|npu|device|execute)
```

### 关键词
timeout, TS timeout, task timeout, execute timeout, stall

### 常见根因
1. NPU 计算任务卡死（模型计算量超出 NPU 处理能力）
2. HCCL 通信等待超时（上游通信错误传导）
3. NPU 驱动固件版本过旧（已知 bug 导致任务卡死）
4. 内存不足导致任务无法分配所需 buffer

### 诊断步骤
1. `npu-smi info -t usages -i <device_id>` — 检查 NPU 使用率和内存
2. `dmesg | grep -i davinci` — 检查内核日志中的设备错误
3. 检查 vLLM 启动参数：`max_model_len`、`max_num_seqs` 是否过大
4. `npu-smi info -t board -i <device_id>` — 检查固件版本

### 修复建议
1. 降低模型参数：减小 `max_model_len` 或 `max_num_seqs`
2. 更新昇腾驱动和固件到最新稳定版本
3. 检查是否存在 HCCL 通信错误（先解决通信问题）
4. 重启异常 NPU 卡后重试
5. 增加 `--gpu-memory-utilization` 参数（默认 0.9）降低内存压力

### 关联模式
- HCCL 通信（通信超时是设备超时的常见上游原因）
- 内存溢出（OOM 后续任务可能超时）
- 设备异常（硬件故障导致任务卡死）

---

## 3. 内存溢出错误

### 正则模式
```
(?:OOM|out of memory|memory alloc(?:ation)? failed|memory exceed|CANN.*memory)
```

### 关键词
OOM, out of memory, memory allocation failed, memory exceed, buffer alloc

### 常见根因
1. 模型参数过大超出 NPU HBM 容量（如 max_model_len 设置过高）
2. KV Cache 占用过多（batch size 过大或序列过长）
3. tensor_parallel_size 不足导致单卡内存压力大
4. CANN 算子内部 buffer 分配失败

### 诊断步骤
1. `npu-smi info -t usages -i <device_id>` — 查看 NPU HBM 使用率
2. 检查 vLLM 启动参数中的 `max_model_len` 和 `max_num_seqs`
3. `free -h` — 检查主机内存是否充足
4. 检查模型实际参数量和 KV Cache 计算需求

### 修复建议
1. 降低 `max_model_len`（如从 8192 降到 4096）
2. 降低 `max_num_seqs`（如从 256 降到 128）
3. 增加 `tensor_parallel_size` 分摊内存压力
4. 使用 `--gpu-memory-utilization 0.9`（默认值）或适当降低
5. 检查是否有多余进程占用 NPU 内存

### 关联模式
- 设备超时（OOM 后续任务可能超时）
- 资源不足（NPU 内存资源耗尽）

---

## 4. 设备异常错误

### 正则模式
```
(?:device|dev\d+|davinci\d+).*(?:error|fault|fail|abnormal|reset)
(?:NPU|npu).*(?:error|fault|fail|abnormal|offline)
```

### 关键词
device error, davinci error, NPU error, device fault, device offline, reset

### 常见根因
1. NPU 硬件故障（芯片损坏、PCIE 链路异常）
2. 驱动与固件不兼容（版本 mismatch）
3. 过热保护触发（散热不足导致设备自动 offline）
4. 电源不稳定导致设备异常重启

### 诊断步骤
1. `npu-smi info -t board -i <device_id>` — 检查设备健康状态
2. `npu-smi info -t common -i <device_id>` — 检查设备是否在线
3. `dmesg | grep -i davinci` — 检查内核层面的设备错误
4. 检查服务器温度和散热状态
5. `lspci | grep -i ascend` — 检查 PCIE 设备是否可见

### 修复建议
1. 重启异常设备：`npu-smi set -t reset -i <device_id>`
2. 重启宿主机尝试恢复 PCIE 链路
3. 更新驱动固件到兼容版本
4. 检查散热系统：风扇转速、环境温度
5. 如反复异常，联系硬件供应商更换 NPU 卡

### 关联模式
- HCCL 通信（设备故障可表现为通信错误）
- 驱动错误（驱动异常导致设备不可用）
- 设备超时（设备异常导致任务卡死超时）

---

## 5. 驱动错误

### 正则模式
```
(?:driver|drv).*(?:error|fail|crash|version mismatch|incompatible)
(?:firmware|fw).*(?:error|fail|version mismatch|upgrade)
CANN.*(?:error|fail|init failed)
```

### 关键词
driver error, drv error, firmware, fw, CANN init failed, version mismatch

### 常见根因
1. 驱动版本与固件版本不匹配（升级不完整）
2. CANN 软件栈初始化失败（环境变量或依赖缺失）
3. 驱动模块未正确加载（`ko` 文件缺失或冲突）
4. 多版本 CANN 共存导致环境冲突

### 诊断步骤
1. `npu-smi info -t board` — 检查驱动和固件版本
2. `cat /usr/local/Ascend/driver/version.info` — 知驱动版本
3. `cat /usr/local/Ascend/ascend-toolkit/version.info` — 检查 CANN 版本
4. `lsmod | grep -i davinci` — 检查驱动模块是否加载
5. 检查环境变量：`ASCEND_HOME_PATH`、`LD_LIBRARY_PATH`

### 修复建议
1. 确保驱动、固件、CANN 版本三件套一致（参考昇腾兼容性矩阵）
2. 清理多版本残留：只保留一套 CANN + driver
3. 重新加载驱动模块：`rmmod davinci; modprobe davinci`
4. 设置正确环境变量（参考 vLLM-Ascend 文档）
5. 重启宿主机使驱动变更生效

### 关联模式
- 设备异常（驱动问题导致设备不可用）
- 设备超时（驱动 bug 导致任务超时）

---

## 6. 资源不足错误

### 正则模式
```
(?:resource|device).*(?:exhausted|not available|unavailable|busy|occupied)
(?:no available|cannot find).*(?:device|npu|davinci)
```

### 关键词
resource exhausted, no available device, device busy, device occupied

### 常见根因
1. 其他进程占用 NPU 资源（残留训练/推理进程）
2. Device Plugin 配置不当导致资源注册异常
3. NPU 资源分配策略不合理（请求量超过节点实际可用量）
4. 容器资源限制与 NPU 数量不匹配

### 诊断步骤
1. `npu-smi info` — 查看所有 NPU 状态和使用情况
2. `fuser /dev/davinci*` — 检查哪些进程占用 NPU 设备
3. `kubectl describe node <name>` — 检查 NPU 资源注册情况
4. `ps aux | grep -i vllm` — 检查残留 vLLM 进程

### 修复建议
1. 杀掉占用 NPU 的残留进程：`kill -9 <pid>`
2. 检查 Device Plugin 日志确保资源正确注册
3. 调整 Deployment 中的 NPU 资源请求量
4. 确保 Pod 的 NPU limit/request 与实际需要匹配
5. 重启 Device Plugin：`kubectl rollout restart daemonset ascend-device-plugin`

### 关联模式
- 内存溢出（NPU 资源耗尽后内存也溢出）
- HCCL 通信（资源不足导致 rank 分配失败）

---

## 7. 数据对齐错误

### 正则模式
```
(?:alignment|shape|dtype|type).*(?:error|mismatch|not match|incompatible)
(?:tensor|data).*(?:cast|convert|transform).*(?:error|fail)
```

### 关键词
alignment error, shape mismatch, dtype mismatch, type error, cast error

### 常见根因
1. 模型权重数据类型与 NPU 算子不兼容（如 float64 不支持）
2. KV Cache 数据格式不匹配（Prefill 与 Decode 间格式不一致）
3. 模型配置中的 `dtype` 与实际权重 dtype 不符
4. 昇腾 CANN 算子对某些数据类型有限制

### 诊断步骤
1. 检查模型权重 dtype：`python -c "import torch; print(torch.load('model.bin').dtype)"`
2. 检查 vLLM 启动参数中的 `--dtype` 设置
3. 查看 CANN 版本支持的数据类型列表
4. 检查模型 config.json 中的 `torch_dtype` 字段

### 修复建议
1. 确保 `--dtype float16` 或 `--dtype bfloat16`（昇腾推荐 bfloat16）
2. 如使用 PD 分离，确保 Prefill 和 Decode 使用相同的 dtype
3. 更新 CANN 版本以支持更多数据类型
4. 模型转换：将不兼容的 dtype 权重转为支持的 dtype

### 关联模式
- 内存溢出（dtype 不匹配可能导致额外内存分配）
- 设备超时（数据转换耗时可能超时）

---

## 严重等级映射

| 类别 | 默认严重等级 | 触发条件 |
|------|-------------|---------|
| HCCL 通信 | high | 任何 HCCL 错误出现 |
| 设备超时 | high | 超时次数 > 5 |
| 内存溢出 | critical | 任何 OOM 出现 |
| 设备异常 | critical | 设备 offline 或 fault |
| 驱动错误 | high | 驱动初始化失败 |
| 资源不足 | medium | 资源不可用 |
| 数据对齐 | medium | dtype/shape 不匹配 |

> 低频出现（< 3 次）的设备超时降级为 medium，高频 HCCL 错误升级为 critical。
```

- [ ] **步骤 2：验证文件内容完整性**

```bash
grep -c "^## " vllm-log-analyze/knowledge/ascend-error-patterns.md
```

预期输出：`8`（7 个错误类别 + 1 个严重等级映射）

- [ ] **步骤 3：Commit**

```bash
git add vllm-log-analyze/knowledge/ascend-error-patterns.md
git commit -m "feat(log-analyze): add ascend error patterns knowledge base"
```

---

### 任务 3：创建报告模板

**文件：**
- 创建：`vllm-log-analyze/templates/error-report.md`

- [ ] **步骤 1：编写 error-report.md**

```markdown
# 昇腾 NPU 日志诊断报告

> 生成时间：{{TIMESTAMP}}
> 分析范围：{{TIME_RANGE}}
> 日志路径：{{PLOG_PATH}}

---

## 概要

| 项目 | 数值 |
|------|------|
| 扫描日志文件 | {{LOG_FILES_SCANNED}} 个 |
| 总日志行数 | {{TOTAL_LINES}} 行 |
| 过滤后错误条目 | {{FILTERED_LINES}} 条 |
| 已识别类别 | {{CATEGORIES_FOUND}} 个 |
| 未识别错误 | {{UNMATCHED_COUNT}} 条 |

---

{{CRITICAL_SECTION}}

{{HIGH_SECTION}}

{{MEDIUM_SECTION}}

---

## 关联性分析

{{CORRELATION_ANALYSIS}}

---

## 未识别错误

{{UNMATCHED_ERRORS}}

---

## 建议的下一步操作

{{NEXT_STEPS}}
```

- [ ] **步骤 2：验证模板占位符**

```bash
grep -o "{{[^}]+}}" vllm-log-analyze/templates/error-report.md | sort
```

预期输出包含所有模板占位符：TIMESTAMP, TIME_RANGE, PLOG_PATH, LOG_FILES_SCANNED, TOTAL_LINES, FILTERED_LINES, CATEGORIES_FOUND, UNMATCHED_COUNT, CRITICAL_SECTION, HIGH_SECTION, MEDIUM_SECTION, CORRELATION_ANALYSIS, UNMATCHED_ERRORS, NEXT_STEPS

- [ ] **步骤 3：Commit**

```bash
git add vllm-log-analyze/templates/error-report.md
git commit -m "feat(log-analyze): add error report template"
```

---

### 任务 4：实现 fetch-plog.sh 脚本

**文件：**
- 创建：`vllm-log-analyze/scripts/fetch-plog.sh`

这是核心脚本之一，负责读取 plog 日志并按配置过滤提取。

- [ ] **步骤 1：编写 fetch-plog.sh**

```bash
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

echo "$TEMP_DEVICE" > /dev/null
echo "$TEMP_HOST" > /dev/null
echo "$TEMP_APP" > /dev/null

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
        echo "[]" > "$temp_file"
        continue
    fi
    
    # 查找日志文件（glob 模式匹配，不硬编码文件名）
    log_files=$(find "$type_dir" -name "*.log" -o -name "*.log.*" 2>/dev/null | sort)
    
    if [ -z "$log_files" ]; then
        echo "Warning: no log files found in '$type_dir'" >&2
        echo "[]" > "$temp_file"
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

# 使用 jq 合并各类型日志为数组
device_logs=$(jq -s '.' "$TEMP_DEVICE" 2>/dev/null || echo "[]")
host_logs=$(jq -s '.' "$TEMP_HOST" 2>/dev/null || echo "[]")
app_logs=$(jq -s '.' "$TEMP_APP" 2>/dev/null || echo "[]")

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
```

- [ ] **步骤 2：创建测试数据验证脚本输出格式**

创建最小测试日志文件验证 fetch-plog.sh 能正确提取：

```bash
# 创建测试目录和日志
mkdir -p /tmp/test-plog/device /tmp/test-plog/host /tmp/test-plog/app

# 写入测试日志（含时间戳和级别）
cat > /tmp/test-plog/device/device-0.log <<'TESTLOG'
[2026-06-01 10:23:45] [ERROR] HCCL timeout on rank 3, waiting for response from rank 7
[2026-06-01 10:24:00] [WARNING] Device davinci0 temperature approaching threshold
[2026-06-01 10:24:15] [INFO] Normal operation continued
[2026-05-30 08:00:00] [ERROR] Old error outside time range
TESTLOG

cat > /tmp/test-plog/host/host-daemon.log <<'TESTLOG'
[2026-06-01 10:25:00] [CRITICAL] Driver firmware version mismatch detected
[2026-06-01 10:25:10] [ERROR] OOM: memory allocation failed for buffer on davinci2
TESTLOG

# 创建最小 config.json
mkdir -p /tmp/test-vllm-deploy
cat > /tmp/test-vllm-deploy/config.json <<'TESTCONF'
{
  "plog_config": {
    "plog_path": "/tmp/test-plog",
    "plog_types": ["device", "host", "app"],
    "time_range": "last_24h",
    "error_levels": ["ERROR", "WARNING", "CRITICAL"]
  }
}
TESTCONF

# 运行脚本
bash vllm-log-analyze/scripts/fetch-plog.sh /tmp/test-vllm-deploy/config.json /tmp/test-vllm-deploy/log-analysis

# 验证输出是有效 JSON 且包含预期字段
OUTPUT=$(bash vllm-log-analyze/scripts/fetch-plog.sh /tmp/test-vllm-deploy/config.json /tmp/test-vllm-deploy/log-analysis 2>/dev/null)
echo "$OUTPUT" | jq -e '.plog_path'
echo "$OUTPUT" | jq -e '.filtered_lines'
echo "$OUTPUT" | jq -e '.logs_by_type.device | length'

# 验证至少提取了 3 条日志（排除 INFO 和超出时间范围的）
echo "$OUTPUT" | jq '.logs_by_type.device | length' | grep -E "^[2-9]$"
echo "$OUTPUT" | jq '.logs_by_type.host | length' | grep -E "^[1-9]$"
```

预期：device 类型提取 2 条（1 ERROR + 1 WARNING，排除 INFO 和旧时间），host 类型提取 2 条（1 CRITICAL + 1 ERROR）。

- [ ] **步骤 3：Commit**

```bash
git add vllm-log-analyze/scripts/fetch-plog.sh
git commit -m "feat(log-analyze): add fetch-plog.sh script"
```

---

### 任务 5：实现 filter-errors.sh 脚本

**文件：**
- 创建：`vllm-log-analyze/scripts/filter-errors.sh`

这是核心脚本之二，负责对 fetch-plog.sh 输出做正则模式匹配预筛。

- [ ] **步骤 1：编写 filter-errors.sh**

```bash
#!/bin/bash
# 昇腾错误模式预筛脚本
# 对 fetch-plog.sh 输出做正则匹配，分类统计已知错误模式
# 输出结构化错误摘要 JSON，供 AI 代理深度诊断使用

set -e

# 参数处理
FETCH_OUTPUT="${1:-.vllm-deploy/log-analysis/fetch-output.json}"
KNOWLEDGE_FILE="${2:-vllm-log-analyze/knowledge/ascend-error-patterns.md}"

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

# 检查知识库文件
if [ ! -f "$KNOWLEDGE_FILE" ]; then
    echo "Warning: knowledge file not found, using built-in patterns" >&2
fi

# 从知识库提取正则模式（解析 markdown 中的正则块）
# 如果知识库不存在，使用内置模式
extract_patterns_from_knowledge() {
    local knowledge_file="$1"
    if [ ! -f "$knowledge_file" ]; then
        # 内置默认模式（与知识库对应）
        cat <<'PATTERNS'
HCCL通信|HCCL.*(?:timeout|error|fail|abort)|HCCS.*(?:timeout|error|fail)|rank.*(?:timeout|disconnect|fail)
设备超时|(?:TS|task|execute|kernel|op).*timeout|timeout.*(?:davinci|npu|device|execute)
内存溢出|(?:OOM|out of memory|memory alloc(?:ation)? failed|memory exceed|CANN.*memory)
设备异常|(?:device|dev\d+|davinci\d+).*(?:error|fault|fail|abnormal|reset)|(?:NPU|npu).*(?:error|fault|fail|abnormal|offline)
驱动错误|(?:driver|drv).*(?:error|fail|crash|version mismatch|incompatible)|(?:firmware|fw).*(?:error|fail|version mismatch|upgrade)|CANN.*(?:error|fail|init failed)
资源不足|(?:resource|device).*(?:exhausted|not available|unavailable|busy|occupied)|(?:no available|cannot find).*(?:device|npu|davinci)
数据对齐|(?:alignment|shape|dtype|type).*(?:error|mismatch|not match|incompatible)|(?:tensor|data).*(?:cast|convert|transform).*(?:error|fail)
PATTERNS
        return
    fi
    
    # 从 markdown 提取正则块（### 正则模式 后的 ``` 块）
    awk '
        /^### 正则模式/ { capture = 1; next }
        capture && /^```/ { if (block_start) { block_start = 0; capture = 0 } else { block_start = 1; next } }
        capture && block_start { print }
    ' "$knowledge_file"
}

# 提取所有日志条目（合并三种类型）
ALL_LOGS=$(jq -s '
    .[0].logs_by_type.device + 
    .[0].logs_by_type.host + 
    .[0].logs_by_type.app
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

# 严重等级映射
declare -A SEVERITY_MAP
SEVERITY_MAP["HCCL通信"]="high"
SEVERITY_MAP["设备超时"]="high"
SEVERITY_MAP["内存溢出"]="critical"
SEVERITY_MAP["设备异常"]="critical"
SEVERITY_MAP["驱动错误"]="high"
SEVERITY_MAP["资源不足"]="medium"
SEVERITY_MAP["数据对齐"]="medium"

# 解析模式定义：每行格式为 "类别|正则1|正则2|..."
PATTERNS_DATA=$(extract_patterns_from_knowledge "$KNOWLEDGE_FILE")

# 使用临时文件收集匹配结果
TEMP_MATCHED=$(mktemp)
trap "rm -f '$TEMP_MATCHED'" EXIT

echo "[]" > "$TEMP_MATCHED"

# 遍历每个模式类别
while IFS='|' read -r category regex1 regex2 regex3; do
    [ -z "$category" ] && continue
    
    echo "Filtering category: $category" >&2
    
    # 构建完整的 grep 正则（合并所有子模式）
    FULL_REGEX="${regex1}"
    [ -n "$regex2" ] && FULL_REGEX="${FULL_REGEX}|${regex2}"
    [ -n "$regex3" ] && FULL_REGEX="${FULL_REGEX}|${regex3}"
    
    # 从 ALL_LOGS 中匹配此类别
    # 用 jq + grep 组合：先转为文本，再 grep 匹配
    MATCHED_LOGS=$(echo "$ALL_LOGS" | jq -r '.[] | .message' | grep -iE "$FULL_REGEX" 2>/dev/null || echo "")
    
    MATCHED_COUNT=$(echo "$MATCHED_LOGS" | grep -c "." 2>/dev/null || echo 0)
    
    if [ "$MATCHED_COUNT" -eq 0 ]; then
        echo "No matches for $category" >&2
        continue
    fi
    
    echo "Found $MATCHED_COUNT matches for $category" >&2
    
    # 获取匹配日志的详细信息
    # 从 ALL_LOGS 中提取 message 匹配的条目
    MATCHED_ENTRIES=$(echo "$ALL_LOGS" | jq -c --arg regex "$FULL_REGEX" '
        [.[] | select(.message | test($regex; "i"))]
    ' 2>/dev/null || echo "[]")
    
    # 统计时间范围
    FIRST_OCC=$(echo "$MATCHED_ENTRIES" | jq -r '[.[] | .timestamp] | sort | .[0]' 2>/dev/null || echo "unknown")
    LAST_OCC=$(echo "$MATCHED_ENTRIES" | jq -r '[.[] | .timestamp] | sort | .[-1]' 2>/dev/null || echo "unknown")
    
    # 提取样本消息（最多 5 条）
    SAMPLES=$(echo "$MATCHED_ENTRIES" | jq -r '[.[] | .message][0:5]' 2>/dev/null || echo "[]")
    
    # 确定严重等级
    SEVERITY="${SEVERITY_MAP[$category]}"
    # 高频 HCCL 升级为 critical
    if [ "$category" = "HCCL通信" ] && [ "$MATCHED_COUNT" -gt 10 ]; then
        SEVERITY="critical"
    fi
    # 低频设备超时降级为 medium
    if [ "$category" = "设备超时" ] && [ "$MATCHED_COUNT" -lt 3 ]; then
        SEVERITY="medium"
    fi
    
    # 构建此类别的匹配结果
    CATEGORY_RESULT=$(jq -n \
        --arg cat "$category" \
        --arg pat "$FULL_REGEX" \
        --argjson count "$MATCHED_COUNT" \
        --arg first "$FIRST_OCC" \
        --arg last "$LAST_OCC" \
        --argjson samples "$SAMPLES" \
        --arg severity "$SEVERITY" \
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
    
done <<< "$PATTERNS_DATA"

# 合并所有匹配结果为数组
MATCHED_ARRAY=$(jq -s '.' "$TEMP_MATCHED" 2>/dev/null || echo "[]")

# 找出未匹配的错误条目
# 收集所有已匹配的 message，然后过滤出不在任何类别中的条目
ALL_MATCHED_MESSAGES=$(echo "$MATCHED_ARRAY" | jq -r '.[].sample_messages[]' 2>/dev/null || echo "")

# 使用 jq 从 ALL_LOGS 中排除已匹配的条目
MATCHED_CATEGORIES=$(echo "$MATCHED_ARRAY" | jq -r '.[].category' 2>/dev/null || echo "")

# 构建所有匹配正则的合并正则
COMBINED_REGEX=""
while IFS='|' read -r category regex1 regex2 regex3; do
    [ -z "$category" ] && continue
    PART="${regex1}"
    [ -n "$regex2" ] && PART="${PART}|${regex2}"
    [ -n "$regex3" ] && PART="${PART}|${regex3}"
    if [ -n "$COMBINED_REGEX" ]; then
        COMBINED_REGEX="${COMBINED_REGEX}|${PART}"
    else
        COMBINED_REGEX="${PART}"
    fi
done <<< "$PATTERNS_DATA"

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
```

- [ ] **步骤 2：使用任务 4 的测试数据验证 filter-errors.sh**

```bash
# 先运行 fetch-plog.sh 生成中间数据
FETCH_OUTPUT=$(bash vllm-log-analyze/scripts/fetch-plog.sh /tmp/test-vllm-deploy/config.json /tmp/test-vllm-deploy/log-analysis 2>/dev/null)

# 保存中间结果到文件
echo "$FETCH_OUTPUT" > /tmp/test-vllm-deploy/log-analysis/fetch-output.json

# 运行 filter-errors.sh
FILTER_OUTPUT=$(bash vllm-log-analyze/scripts/filter-errors.sh /tmp/test-vllm-deploy/log-analysis/fetch-output.json 2>/dev/null)

# 验证输出是有效 JSON
echo "$FILTER_OUTPUT" | jq -e '.matched_patterns'
echo "$FILTER_OUTPUT" | jq -e '.unmatched_errors'
echo "$FILTER_OUTPUT" | jq -e '.summary.total_errors'

# 验证匹配了 HCCL 类别（测试日志含 "HCCL timeout"）
echo "$FILTER_OUTPUT" | jq -r '.matched_patterns[].category' | grep "HCCL"

# 验证匹配了内存溢出类别（测试日志含 "OOM"）
echo "$FILTER_OUTPUT" | jq -r '.matched_patterns[].category' | grep "内存"
```

预期：matched_patterns 包含 HCCL通信 和 内存溢出 类别，summary.total_errors ≥ 4。

- [ ] **步骤 3：Commit**

```bash
git add vllm-log-analyze/scripts/filter-errors.sh
git commit -m "feat(log-analyze): add filter-errors.sh script"
```

---

### 任务 6：编写 Phase 1 模块 — config-setup.md

**文件：**
- 创建：`vllm-log-analyze/modules/config-setup.md`

- [ ] **步骤 1：编写 config-setup.md**

```markdown
# Phase 1: 配置获取/问答

## 目标

获取 plog 日志分析所需的配置参数。如果 `.vllm-deploy/config.json` 中已有 `plog_config`，直接使用；否则通过交互问答创建。

## 前置检查

1. 检查 `.vllm-deploy/` 目录是否存在
   - 不存在 → 创建目录
2. 检查 `.vllm-deploy/config.json` 是否存在
   - 不存在 → 创建最小 config.json（只含 plog_config）
   - 存在 → 读取并检查 `plog_config` 字段
3. 检查 `plog_config` 是否完整（包含所有 4 个字段）
   - 不完整 → 补充缺失字段

## 交互问答流程

使用 AskUserQuestion 工具，逐个询问缺失的配置参数：

### Q1: plog 日志路径

```
昇腾 NPU 的 plog 日志在宿主机上的路径是什么？
常见路径：
- /usr/local/Ascend/driver/log（昇腾驱动默认）
- /var/log/ascend（某些安装方式）
- 自定义路径
```

默认值：`/usr/local/Ascend/driver/log`

### Q2: 日志类型选择

```
要分析哪些类型的 plog 日志？（多选）
- device: NPU 设备操作日志（包含 HCCL、超时、设备异常等）
- host: 宿主机驱动层日志（包含驱动错误、固件问题等）
- app: 应用层日志（包含 vLLM/CANN 相关错误）
```

默认值：全部三种（device、host、app）

### Q3: 时间范围

```
分析最近多久的日志？
- last_1h: 最近 1 小时（适合排查刚刚发生的错误）
- last_6h: 最近 6 小时（适合排查近期问题）
- last_24h: 最近 24 小时（默认，适合常规巡检）
- all: 全部日志（适合首次全面排查，注意日志量可能很大）
```

默认值：`last_24h`

### Q4: 日志级别

```
提取哪些级别的日志条目？（多选）
- ERROR: 错误级别（必选）
- WARNING: 警告级别（可能预示即将出错）
- CRITICAL: 严重错误（系统级故障）
```

默认值：全部三种（ERROR、WARNING、CRITICAL）

## 配置写入

将问答结果合并到 `.vllm-deploy/config.json`：

```bash
# 如果 config.json 不存在，创建新文件
if [ ! -f .vllm-deploy/config.json ]; then
    jq -n --arg path "$PLOG_PATH" \
        --argjson types "$PLOG_TYPES" \
        --arg range "$TIME_RANGE" \
        --argjson levels "$ERROR_LEVELS" \
        '{plog_config: {plog_path: $path, plog_types: $types, time_range: $range, error_levels: $levels}}' \
        > .vllm-deploy/config.json
else
    # 已有 config.json，追加或更新 plog_config
    jq --arg path "$PLOG_PATH" \
       --argjson types "$PLOG_TYPES" \
       --arg range "$TIME_RANGE" \
       --argjson levels "$ERROR_LEVELS" \
       '.plog_config = {plog_path: $path, plog_types: $types, time_range: $range, error_levels: $levels}' \
       .vllm-deploy/config.json > .vllm-deploy/config.json.tmp
    mv .vllm-deploy/config.json.tmp .vllm-deploy/config.json
fi
```

## 输出

`.vllm-deploy/config.json` 中包含完整的 `plog_config` 字段：

```json
{
  "plog_config": {
    "plog_path": "/usr/local/Ascend/driver/log",
    "plog_types": ["device", "host", "app"],
    "time_range": "last_24h",
    "error_levels": ["ERROR", "WARNING", "CRITICAL"]
  }
}
```

## AI 执行指南

1. 检查 `.vllm-deploy/config.json` 状态
2. 读取 `plog_config`（如有）
3. 对缺失参数逐个使用 AskUserQuestion 问答
4. 使用 jq 命令将配置写入 config.json
5. 确认配置完整后进入 Phase 2

## 错误处理

| 场景 | 处理 |
|------|------|
| .vllm-deploy/ 目录不存在 | 创建目录：`mkdir -p .vllm-deploy` |
| config.json 不存在 | 创建最小配置文件 |
| plog_config 字段缺失 | 逐个问答补充 |
| jq 不可用 | 提示安装 jq：`apt install jq` |
```

- [ ] **步骤 2：验证模块文件结构完整**

```bash
grep -c "^## " vllm-log-analyze/modules/config-setup.md
```

预期输出：`8`（8 个章节）

- [ ] **步骤 3：Commit**

```bash
git add vllm-log-analyze/modules/config-setup.md
git commit -m "feat(log-analyze): add Phase 1 config-setup module"
```

---

### 任务 7：编写 Phase 2 模块 — log-fetcher.md

**文件：**
- 创建：`vllm-log-analyze/modules/log-fetcher.md`

- [ ] **步骤 1：编写 log-fetcher.md**

```markdown
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
bash vllm-log-analyze/scripts/filter-errors.sh .vllm-deploy/log-analysis/fetch-output.json vllm-log-analyze/knowledge/ascend-error-patterns.md > .vllm-deploy/log-analysis/error-summary.json
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
```

- [ ] **步骤 2：Commit**

```bash
git add vllm-log-analyze/modules/log-fetcher.md
git commit -m "feat(log-analyze): add Phase 2 log-fetcher module"
```

---

### 任务 8：编写 Phase 3 模块 — error-analyzer.md

**文件：**
- 创建：`vllm-log-analyze/modules/error-analyzer.md`

- [ ] **步骤 1：编写 error-analyzer.md**

```markdown
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
```

- [ ] **步骤 2：Commit**

```bash
git add vllm-log-analyze/modules/error-analyzer.md
git commit -m "feat(log-analyze): add Phase 3 error-analyzer module"
```

---

### 任务 9：编写 Phase 4 模块 — report-generator.md

**文件：**
- 创建：`vllm-log-analyze/modules/report-generator.md`

- [ ] **步骤 1：编写 report-generator.md**

```markdown
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
| {{LOG_FILES_SCANNED}} | error-summary.json → summary.total_errors（或 fetch-output.json → log_files_scanned） |
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
```

- [ ] **步骤 2：Commit**

```bash
git add vllm-log-analyze/modules/report-generator.md
git commit -m "feat(log-analyze): add Phase 4 report-generator module"
```

---

### 任务 10：集成验证

验证所有文件协同工作，整个 Skill 可以完整运行。

- [ ] **步骤 1：验证目录结构完整**

```bash
find vllm-log-analyze -type f | sort
```

预期输出：
```
vllm-log-analyze/SKILL.md
vllm-log-analyze/knowledge/ascend-error-patterns.md
vllm-log-analyze/modules/config-setup.md
vllm-log-analyze/modules/error-analyzer.md
vllm-log-analyze/modules/log-fetcher.md
vllm-log-analyze/modules/report-generator.md
vllm-log-analyze/scripts/fetch-plog.sh
vllm-log-analyze/scripts/filter-errors.sh
vllm-log-analyze/templates/error-report.md
```

- [ ] **步骤 2：运行端到端脚本测试**

使用任务 4 的测试数据，完整运行脚本链：

```bash
# Phase 2: fetch-plog.sh
bash vllm-log-analyze/scripts/fetch-plog.sh /tmp/test-vllm-deploy/config.json /tmp/test-vllm-deploy/log-analysis > /tmp/test-vllm-deploy/log-analysis/fetch-output.json 2>/dev/null

# 验证 fetch 输出
jq -e '.plog_path' /tmp/test-vllm-deploy/log-analysis/fetch-output.json
jq -e '.filtered_lines' /tmp/test-vllm-deploy/log-analysis/fetch-output.json
jq -e '.logs_by_type.device | length > 0' /tmp/test-vllm-deploy/log-analysis/fetch-output.json

# Phase 2: filter-errors.sh
bash vllm-log-analyze/scripts/filter-errors.sh /tmp/test-vllm-deploy/log-analysis/fetch-output.json vllm-log-analyze/knowledge/ascend-error-patterns.md > /tmp/test-vllm-deploy/log-analysis/error-summary.json 2>/dev/null

# 验证 filter 输出
jq -e '.matched_patterns | length > 0' /tmp/test-vllm-deploy/log-analysis/error-summary.json
jq -e '.summary.total_errors > 0' /tmp/test-vllm-deploy/log-analysis/error-summary.json
jq -r '.matched_patterns[].category' /tmp/test-vllm-deploy/log-analysis/error-summary.json
```

预期：
- fetch-output.json 包含 plog_path、filtered_lines > 0、device 类型有条目
- error-summary.json 包含 matched_patterns > 0、total_errors > 0、至少 HCCL通信 类别

- [ ] **步骤 3：验证脚本可执行权限**

```bash
chmod +x vllm-log-analyze/scripts/fetch-plog.sh
chmod +x vllm-log-analyze/scripts/filter-errors.sh
ls -la vllm-log-analyze/scripts/
```

- [ ] **步骤 4：验证 SKILL.md frontmatter 格式**

```bash
head -5 vllm-log-analyze/SKILL.md
```

预期输出包含 YAML frontmatter：`---`、`name: vllm-log-analyze`、`description:`、`---`

- [ ] **步骤 5：验证知识库模式数量**

```bash
grep "^## [0-9]" vllm-log-analyze/knowledge/ascend-error-patterns.md | wc -l
```

预期输出：`7`（7 个错误类别）

- [ ] **步骤 6：最终 Commit**

```bash
git add vllm-log-analyze/scripts/fetch-plog.sh vllm-log-analyze/scripts/filter-errors.sh
git commit -m "feat(log-analyze): set script permissions and complete integration verification"
```

---

## 规格覆盖度自检

对照设计规格 [2026-06-01-vllm-log-analyze-design.md](../specs/2026-06-01-vllm-log-analyze-design.md) 逐项检查：

| 规格章节 | 对应任务 | 状态 |
|----------|---------|------|
| Skill 结构 | 任务 1 | ✅ |
| 配置体系 plog_config | 任务 6 | ✅ |
| Phase 1 配置获取流程 | 任务 6 | ✅ |
| fetch-plog.sh 脚本设计 | 任务 4 | ✅ |
| filter-errors.sh 脚本设计 | 任务 5 | ✅ |
| 昇腾错误模式 7 类别 | 任务 2 | ✅ |
| ascend-error-patterns.md 知识库 | 任务 2 | ✅ |
| AI 三层诊断流程 | 任务 8 | ✅ |
| 报告输出模板 | 任务 3 | ✅ |
| Phase 4 报告生成 | 任务 9 | ✅ |
| 完整工作流 | 任务 10 | ✅ |
| SKILL.md 入口 | 任务 1 | ✅ |
| 错误处理 | 各模块内覆盖 | ✅ |

无遗漏，无占位符，类型一致（所有 JSON 字段名在脚本和模块间一致）。