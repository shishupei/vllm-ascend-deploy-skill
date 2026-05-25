# vLLM-Deploy Skill 实现计划更新

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为 Skill 1 添加 vLLM 服务拉起脚本模板，支持手动输入环境信息或 Skill 2 探测填充占位符。

**架构：** 创建 4 个启动脚本模板（单机/多机/PD分离-Prefill/PD分离-Decode），使用 `${VAR}` 占位符。Skill 1 生成时填充已知参数，未知参数保留占位符由 Skill 2 探测填充。

**技术栈：** Bash 脚本、K8s YAML、环境变量

---

## 文件结构

本次更新新增/修改的文件：

| 文件 | 职责 |
|------|------|
| `vllm-deploy-prepare/scripts/start-single-node.sh` | 单机启动脚本模板 |
| `vllm-deploy-prepare/scripts/start-multi-node-master.sh` | 多机 Master 启动脚本模板 |
| `vllm-deploy-prepare/scripts/start-multi-node-worker.sh` | 多机 Worker 启动脚本模板 |
| `vllm-deploy-prepare/scripts/start-prefill.sh` | PD 分离 Prefill 启动脚本模板 |
| `vllm-deploy-prepare/scripts/start-decode.sh` | PD 分离 Decode 启动脚本模板 |
| `vllm-deploy-prepare/modules/deploy-script-generator.md` | Phase 7 新增：生成启动脚本模块 |

---

## 任务 1：创建单机启动脚本模板

**文件：**
- 创建：`vllm-deploy-prepare/scripts/start-single-node.sh`

- [ ] **步骤 1：创建单机启动脚本**

```bash
#!/bin/bash
# vLLM 单机启动脚本
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
# 手动输入时可预先填充，Skill 2 探测时用占位符

MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-256}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.9}"

# ============ 服务端口配置 ============
SERVICE_PORT="${SERVICE_PORT:-8000}"

# ============ 可选参数 ============
TRUST_REMOTE_CODE="${TRUST_REMOTE_CODE:-true}"
ENFORCE_EAGER="${ENFORCE_EAGER:-false}"

# ============ 启动命令构建 ============
echo "Starting vLLM serve on single node..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "Max Model Len: ${MAX_MODEL_LEN}"
echo "Max Num Seqs: ${MAX_NUM_SEQS}"

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
    --port "${SERVICE_PORT}" \
    ${TRUST_REMOTE_CODE:-} \
    ${ENFORCE_EAGER:-}

echo "vLLM service started on port ${SERVICE_PORT}"
```

- [ ] **步骤 2：设置可执行权限**

```bash
chmod +x vllm-deploy-prepare/scripts/start-single-node.sh
```

- [ ] **步骤 3：Commit**

```bash
git add vllm-deploy-prepare/scripts/start-single-node.sh
git commit -m "feat(skill-prepare): add single-node vLLM startup script template"
```

---

## 任务 2：创建多机分布式启动脚本模板

**文件：**
- 创建：`vllm-deploy-prepare/scripts/start-multi-node-master.sh`
- 创建：`vllm-deploy-prepare/scripts/start-multi-node-worker.sh`

- [ ] **步骤 1：创建 Master 启动脚本**

```bash
#!/bin/bash
# vLLM 多机分布式 Master 启动脚本（Rank 0）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-256}"

# ============ 分布式配置（Skill 2 探测填充）============
RANK="${RANK:-0}"
WORLD_SIZE="${WORLD_SIZE:-${WORLD_SIZE_PLACEHOLDER}}"
MASTER_ADDR="${MASTER_ADDR:-${MASTER_ADDR_PLACEHOLDER}}"  # 本节点 IP
MASTER_PORT="${MASTER_PORT:-29500}"

# ============ 网络配置（Skill 2 探测填充）============
HCCL_IF_IP="${HCCL_IF_IP:-${NODE_IP_PLACEHOLDER}}"
GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"
TP_SOCKET_IFNAME="${TP_SOCKET_IFNAME:-eth0}"

# 导出环境变量
export HCCL_IF_IP
export GLOO_SOCKET_IFNAME
export TP_SOCKET_IFNAME

# ============ 启动命令构建 ============
echo "Starting vLLM serve as Master (Rank ${RANK})..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "World Size: ${WORLD_SIZE}"
echo "Master Addr: ${MASTER_ADDR}"
echo "Master Port: ${MASTER_PORT}"

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --distributed-executor-backend ray \
    --port 8000 \
    --trust-remote-code

echo "vLLM Master service started"
```

- [ ] **步骤 2：创建 Worker 启动脚本**

```bash
#!/bin/bash
# vLLM 多机分布式 Worker 启动脚本（Rank 1-N）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-256}"

# ============ 分布式配置（Skill 2 探测填充）============
RANK="${RANK:-${WORKER_RANK_PLACEHOLDER}}"        # Worker Rank 编号
WORLD_SIZE="${WORLD_SIZE:-${WORLD_SIZE_PLACEHOLDER}}"
MASTER_ADDR="${MASTER_ADDR:-${MASTER_ADDR_PLACEHOLDER}}"  # Master 节点 IP
MASTER_PORT="${MASTER_PORT:-29500}"

# ============ 网络配置（Skill 2 探测填充）============
HCCL_IF_IP="${HCCL_IF_IP:-${NODE_IP_PLACEHOLDER}}"  # 本节点 IP
GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"
TP_SOCKET_IFNAME="${TP_SOCKET_IFNAME:-eth0}"

# 导出环境变量
export HCCL_IF_IP
export GLOO_SOCKET_IFNAME
export TP_SOCKET_IFNAME
export RANK
export WORLD_SIZE
export MASTER_ADDR
export MASTER_PORT

# ============ 启动命令构建 ============
echo "Starting vLLM serve as Worker (Rank ${RANK})..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "World Size: ${WORLD_SIZE}"
echo "Master Addr: ${MASTER_ADDR}"
echo "Connecting to Master..."

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --distributed-executor-backend ray \
    --port 8000 \
    --trust-remote-code

echo "vLLM Worker service started (Rank ${RANK})"
```

- [ ] **步骤 3：设置可执行权限**

```bash
chmod +x vllm-deploy-prepare/scripts/start-multi-node-master.sh
chmod +x vllm-deploy-prepare/scripts/start-multi-node-worker.sh
```

- [ ] **步骤 4：Commit**

```bash
git add vllm-deploy-prepare/scripts/start-multi-node-*.sh
git commit -m "feat(skill-prepare): add multi-node vLLM startup scripts for Master/Worker"
```

---

## 任务 3：创建 PD 分离启动脚本模板

**文件：**
- 创建：`vllm-deploy-prepare/scripts/start-prefill.sh`
- 创建：`vllm-deploy-prepare/scripts/start-decode.sh`

- [ ] **步骤 1：创建 Prefill 启动脚本（KV Producer）**

```bash
#!/bin/bash
# vLLM PD 分离 Prefill 启动脚本（KV Producer）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${PREFILL_TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-${MAX_MODEL_LEN}}"

# ============ KV Transfer 配置 ============
KV_CONNECTOR="${KV_CONNECTOR:-MooncakeConnectorV1}"
KV_ROLE="kv_producer"
KV_PORT="${KV_PORT:-20001}"
ENGINE_ID="${ENGINE_ID:-0}"
KV_RANK="${KV_RANK:-0}"
KV_PARALLEL_SIZE="${KV_PARALLEL_SIZE:-1}"

# ============ 网络配置（Skill 2 探测填充）============
HCCL_IF_IP="${HCCL_IF_IP:-${NODE_IP_PLACEHOLDER}}"
GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"

export HCCL_IF_IP
export GLOO_SOCKET_IFNAME

# ============ 构建 KV Transfer Config ============
KV_TRANSFER_CONFIG=$(cat <<EOF
{
    "kv_connector": "${KV_CONNECTOR}",
    "kv_buffer_device": "npu",
    "kv_role": "${KV_ROLE}",
    "kv_parallel_size": ${KV_PARALLEL_SIZE},
    "kv_port": "${KV_PORT}",
    "engine_id": "${ENGINE_ID}",
    "kv_rank": ${KV_RANK}
}
EOF
)

# ============ 启动命令构建 ============
echo "Starting vLLM Prefill instance (KV Producer)..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "KV Role: ${KV_ROLE}"
echo "KV Port: ${KV_PORT}"

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
    --gpu-memory-utilization 0.8 \
    --port 8100 \
    --trust-remote-code \
    --enforce-eager \
    --kv-transfer-config "${KV_TRANSFER_CONFIG}"

echo "vLLM Prefill service started on port 8100"
```

- [ ] **步骤 2：创建 Decode 启动脚本（KV Consumer）**

```bash
#!/bin/bash
# vLLM PD 分离 Decode 启动脚本（KV Consumer）
# 环境信息来源：手动输入 或 Skill 2 探测填充

set -e

# ============ 环境变量配置 ============
MODEL_PATH="${MODEL_PATH:-${MODEL_PATH_PLACEHOLDER}}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-${DECODE_TP_SIZE_PLACEHOLDER}}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-${DECODE_MAX_TOKENS_PLACEHOLDER:-16384}}"

# ============ KV Transfer 配置 ============
KV_CONNECTOR="${KV_CONNECTOR:-MooncakeConnectorV1}"
KV_ROLE="kv_consumer"
KV_PORT="${KV_PORT:-20002}"
ENGINE_ID="${ENGINE_ID:-1}"
KV_RANK="${KV_RANK:-1}"
KV_PARALLEL_SIZE="${KV_PARALLEL_SIZE:-1}"

# Prefill 服务地址（Skill 2 探测填充）
PREFILL_ADDR="${PREFILL_ADDR:-${PREFILL_ADDR_PLACEHOLDER}}"
PREFILL_PORT="${PREFILL_PORT:-8100}"

# ============ 网络配置（Skill 2 探测填充）============
HCCL_IF_IP="${HCCL_IF_IP:-${NODE_IP_PLACEHOLDER}}"
GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"

export HCCL_IF_IP
export GLOO_SOCKET_IFNAME

# ============ 构建 KV Transfer Config ============
KV_TRANSFER_CONFIG=$(cat <<EOF
{
    "kv_connector": "${KV_CONNECTOR}",
    "kv_buffer_device": "npu",
    "kv_role": "${KV_ROLE}",
    "kv_parallel_size": ${KV_PARALLEL_SIZE},
    "kv_port": "${KV_PORT}",
    "engine_id": "${ENGINE_ID}",
    "kv_rank": ${KV_RANK}
}
EOF
)

# ============ 启动命令构建 ============
echo "Starting vLLM Decode instance (KV Consumer)..."
echo "Model: ${MODEL_PATH}"
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}"
echo "KV Role: ${KV_ROLE}"
echo "KV Port: ${KV_PORT}"
echo "Prefill Addr: ${PREFILL_ADDR}:${PREFILL_PORT}"

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
    --gpu-memory-utilization 0.8 \
    --port 8200 \
    --trust-remote-code \
    --enforce-eager \
    --no-enable-prefix-caching \
    --kv-transfer-config "${KV_TRANSFER_CONFIG}"

echo "vLLM Decode service started on port 8200"
```

- [ ] **步骤 3：设置可执行权限**

```bash
chmod +x vllm-deploy-prepare/scripts/start-prefill.sh
chmod +x vllm-deploy-prepare/scripts/start-decode.sh
```

- [ ] **步骤 4：Commit**

```bash
git add vllm-deploy-prepare/scripts/start-prefill.sh vllm-deploy-prepare/scripts/start-decode.sh
git commit -m "feat(skill-prepare): add PD separation startup scripts for Prefill/Decode"
```

---

## 任务 4：创建启动脚本生成模块

**文件：**
- 创建：`vllm-deploy-prepare/modules/deploy-script-generator.md`

- [ ] **步骤 1：创建模块文档**

```markdown
# Phase 7.5: 生成 vLLM 启动脚本

## 目标

根据部署方式生成对应的 vLLM 服务启动脚本，环境信息来源支持：
- 手动输入：用户在 Phase 6 提供已知参数
- Skill 2 探测：未知参数保留占位符，由 Skill 2 填充

## 输入

- config.json（Phase 6 生成的配置）
- deploy_mode（部署方式）

## 可用脚本模板

| 脚本文件 | 适用部署方式 | 说明 |
|----------|--------------|------|
| `start-single-node.sh` | 单节点 | 单机启动命令 |
| `start-multi-node-master.sh` | 多节点 Master | Rank 0 启动命令 |
| `start-multi-node-worker.sh` | 多节点 Worker | Rank 1-N 启动命令 |
| `start-prefill.sh` | PD 分离 Prefill | KV Producer 启动命令 |
| `start-decode.sh` | PD 分离 Decode | KV Consumer 启动命令 |

## 占位符说明

脚本使用 `${VAR_PLACEHOLDER}` 格式的占位符，表示需要 Skill 2 探测填充：

### 通用占位符
| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${MODEL_PATH_PLACEHOLDER}` | 模型路径 | 可手动输入 |
| `${TP_SIZE_PLACEHOLDER}` | 张量并行大小 | 可手动输入 |
| `${NODE_IP_PLACEHOLDER}` | 节点 IP | Skill 2 探测 |

### 多节点专属占位符
| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${WORLD_SIZE_PLACEHOLDER}` | 分布式世界大小 | Skill 2 探测 |
| `${MASTER_ADDR_PLACEHOLDER}` | Master 节点 IP | Skill 2 探测 |
| `${WORKER_RANK_PLACEHOLDER}` | Worker Rank | Skill 2 生成 |

### PD 分离专属占位符
| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${PREFILL_TP_SIZE_PLACEHOLDER}` | Prefill TP Size | 可手动输入 |
| `${DECODE_TP_SIZE_PLACEHOLDER}` | Decode TP Size | 可手动输入 |
| `${DECODE_MAX_TOKENS_PLACEHOLDER}` | Decode Max Tokens | 可手动输入 |
| `${PREFILL_ADDR_PLACEHOLDER}` | Prefill 服务地址 | Skill 2 探测 |

## 脚本选择逻辑

根据 `deploy_mode` 选择：

| deploy_mode | 生成的脚本 |
|-------------|------------|
| `single_node` | `start-single-node.sh` |
| `multi_node` | `start-multi-node-master.sh` + 多个 `start-multi-node-worker.sh` |
| `pd_separate` | `start-prefill.sh` + `start-decode.sh` |
| `ha_active_standby` | `start-single-node.sh`（每个副本相同） |

## 输出目录

```
.vllm-deploy/
└── scripts/
    └── start-*.sh    # 根据部署方式生成的启动脚本
```

## AI 执行指南

1. 读取 `config.json` 获取部署方式
2. 根据部署方式选择对应脚本模板
3. 填充已知参数（从 config.json）
4. 保留未知参数为占位符
5. 生成脚本文件到 `.vllm-deploy/scripts/`
6. 展示脚本内容供用户确认
7. 提示：未知参数将在 Skill 2 执行时探测填充
```

- [ ] **步骤 2：Commit**

```bash
git add vllm-deploy-prepare/modules/deploy-script-generator.md
git commit -m "feat(skill-prepare): add deploy-script-generator module documentation"
```

---

## 任务 5：更新 SKILL.md 添加新 Phase

**文件：**
- 修改：`vllm-deploy-prepare/SKILL.md`

- [ ] **步骤 1：更新执行流程**

在 SKILL.md 的执行流程中添加 Phase 7.5：

```markdown
## 执行流程

按顺序读取以下模块并执行：

1. **Phase 1**: `modules/model-list-fetcher.md` - 获取模型列表
2. **Phase 2**: `modules/user-selector.md` - 用户选择
3. **Phase 3**: `modules/doc-parser.md` - 文档解析
4. **Phase 5**: `modules/image-handler.md` - 镜像处理
5. **Phase 6**: `modules/config-guide.md` - 交互配置
6. **Phase 7**: `modules/template-generator.md` - 生成 K8s 模板
7. **Phase 7.5**: `modules/deploy-script-generator.md` - 生成启动脚本  ← 新增
8. 进入 Phase 完成提示
```

- [ ] **步骤 2：更新输出说明**

```markdown
## 输出

生成 `.vllm-deploy/` 目录，包含：
- `config.json` - 用户配置汇总
- `image-info.json` - 镜像信息
- `templates/` - K8s YAML 模板文件
- `scripts/` - vLLM 启动脚本（新增）
```

- [ ] **步骤 3：Commit**

```bash
git add vllm-deploy-prepare/SKILL.md
git commit -m "feat(skill-prepare): add Phase 7.5 for startup script generation"
```

---

## 任务 6：同步更新到已安装 Skill

- [ ] **步骤 1：同步脚本文件**

```bash
cp vllm-deploy-prepare/scripts/start-*.sh ~/.claude/skills/vllm-deploy-prepare/scripts/
chmod +x ~/.claude/skills/vllm-deploy-prepare/scripts/start-*.sh
```

- [ ] **步骤 2：同步模块文件**

```bash
cp vllm-deploy-prepare/modules/deploy-script-generator.md ~/.claude/skills/vllm-deploy-prepare/modules/
cp vllm-deploy-prepare/SKILL.md ~/.claude/skills/vllm-deploy-prepare/SKILL.md
```

- [ ] **步骤 3：验证安装**

```bash
ls -la ~/.claude/skills/vllm-deploy-prepare/scripts/
ls -la ~/.claude/skills/vllm-deploy-prepare/modules/
```

---

## 任务 7：最终验证

- [ ] **步骤 1：验证文件完整性**

```bash
find vllm-deploy-prepare -type f | wc -l
# 预期：新增 6 个脚本文件 + 1 个模块文件
```

- [ ] **步骤 2：验证脚本可执行**

```bash
ls -la vllm-deploy-prepare/scripts/*.sh
# 预期：所有 .sh 文件有 -rwxr-xr-x 权限
```

- [ ] **步骤 3：最终 Commit**

```bash
git add -A
git commit -m "feat(skill-prepare): complete startup scripts integration with placeholder support for Skill 2"
```

---

## 占位符填充流程说明

**Skill 1 阶段（准备）**：
- 已知参数（用户输入）：直接填充实际值
- 未知参数（需探测）：保留 `${VAR_PLACEHOLDER}` 占位符

**Skill 2 阶段（执行）**：
- K8s 环境探测后填充：
  - `${NODE_IP_PLACEHOLDER}` → 实际节点 IP
  - `${WORLD_SIZE_PLACEHOLDER}` → 实际节点数量
  - `${MASTER_ADDR_PLACEHOLDER}` → Master 节点 IP
- 生成最终可执行的脚本

---

## 文件清单汇总

| 类别 | 文件 | 状态 |
|------|------|------|
| 脚本 | `scripts/start-single-node.sh` | 新增 |
| 脚本 | `scripts/start-multi-node-master.sh` | 新增 |
| 脚本 | `scripts/start-multi-node-worker.sh` | 新增 |
| 脚本 | `scripts/start-prefill.sh` | 新增 |
| 脚本 | `scripts/start-decode.sh` | 新增 |
| 模块 | `modules/deploy-script-generator.md` | 新增 |
| 入口 | `SKILL.md` | 修改 |

**新增 7 个文件，总计 Skill 1 将有 23 个文件。**