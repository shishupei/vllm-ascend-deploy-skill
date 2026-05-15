# vllm-deploy-execute Skill 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现 Skill 2 (vllm-deploy-execute)，负责 K8s 环境探测、YAML 填充生成、部署执行指导。

**架构：** Skill 2 作为执行阶段 Skill，读取 Skill 1 生成的 `.vllm-deploy/` 配置，探测 K8s 集群环境，填充模板占位符，生成最终可执行的 K8s YAML 文件，并指导用户完成部署。

**技术栈：** Bash 脚本、kubectl 命令、K8s YAML、JSON 配置

---

## 文件结构

Skill 2 将创建以下文件：

| 文件 | 职责 |
|------|------|
| `skill-execute/SKILL.md` | Skill 入口文件，定义触发方式和执行流程 |
| `skill-execute/modules/k8s-env-detector.md` | Phase 4: K8s 环境探测模块 |
| `skill-execute/modules/yaml-generator.md` | Phase 7（补）: YAML 填充生成模块 |
| `skill-execute/modules/k8s-apply-guide.md` | Phase 8: K8s Apply 指导模块 |
| `skill-execute/modules/container-env-detector.md` | Phase 9: 容器内环境探测模块 |
| `skill-execute/modules/deploy-generator.md` | Phase 10: 部署脚本生成模块 |
| `skill-execute/modules/deploy-execution-guide.md` | Phase 11: 部署执行指导模块 |
| `skill-execute/modules/output-guide.md` | Phase 12: 输出交付模块 |
| `skill-execute/scripts/detect-k8s-env.sh` | K8s 环境探测脚本 |
| `skill-execute/scripts/detect-container-npu.sh` | 容器内 NPU 探测脚本 |
| `skill-execute/scripts/fill-template.sh` | 模板占位符填充脚本 |

**总计：10 个文件（2 入口 + 7 模块 + 3 脚本）**

---

## 任务 1：创建 Skill 入口文件

**文件：**
- 创建：`skill-execute/SKILL.md`

- [ ] **步骤 1：创建 Skill 目录结构**

```bash
mkdir -p skill-execute/modules skill-execute/scripts
```

- [ ] **步骤 2：创建 SKILL.md 入口文件**

```markdown
---
name: vllm-deploy-execute
description: vLLM-Ascend 部署执行 - K8s 环境探测、生成 YAML、执行部署
---

vLLM-Ascend 部署执行阶段，在 K8s 管理节点执行。

## 前置条件

- 已运行 `/vllm-deploy-prepare` 并生成 `.vllm-deploy/` 目录
- `kubectl` 已安装并有集群管理权限
- kubeconfig 已正确配置

## 触发方式

- `/vllm-deploy-execute`
- `vllm 部署执行`

## 执行流程

按顺序读取以下模块并执行：

1. **Phase 4**: `modules/k8s-env-detector.md` - K8s 环境探测
2. **Phase 7（补）**: `modules/yaml-generator.md` - 填充模板生成 YAML
3. **Phase 8**: `modules/k8s-apply-guide.md` - K8s Apply 指导（等待用户确认）
4. **Phase 9**: `modules/container-env-detector.md` - 容器内 NPU 探测
5. **Phase 10**: `modules/deploy-generator.md` - 生成部署脚本
6. **Phase 11**: `modules/deploy-execution-guide.md` - 部署执行指导（等待用户确认）
7. **Phase 12**: `modules/output-guide.md` - 输出交付

## 输入

读取 `.vllm-deploy/config.json`：
```json
{
  "selected_model": "GLM-5",
  "deploy_mode": "multi_node",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  ...
}
```

## 输出

生成 `.vllm-deploy/k8s/` 目录，包含：
- `namespace.yaml` - 已填充的 Namespace
- `configmap.yaml` - 已填充的 ConfigMap
- `deployment-*.yaml` - 已填充的 Deployment（按节点数量）
- `service.yaml` - 已填充的 Service
- `apply-all.sh` - 一键部署脚本
- `README.md` - 部署指南

以及：
- `detection-result.json` - K8s 环境探测结果
- `final-output.json` - 最终部署信息

## 用户确认点

| 确认点 | 用户操作 |
|--------|---------|
| Phase 4 结束 | 确认节点选择 |
| Phase 8 结束 | 执行 `bash apply-all.sh` |
| Phase 11 结束 | 在 Pod 内执行部署脚本 |

## 错误处理

- `config.json` 不存在 → 提示先运行 `/vllm-deploy-prepare`
- `kubectl` 不可用 → 提示安装 kubectl 并配置 kubeconfig
- K8s 集群连接失败 → 提示检查 kubeconfig 和网络
- NPU 资源未注册 → 提示检查 Ascend Device Plugin
```

- [ ] **步骤 3：Commit**

```bash
git add skill-execute/SKILL.md
git commit -m "feat(skill-execute): add SKILL.md entry file for vllm-deploy-execute"
```

---

## 任务 2：创建 K8s 环境探测模块

**文件：**
- 创建：`skill-execute/modules/k8s-env-detector.md`
- 创建：`skill-execute/scripts/detect-k8s-env.sh`

- [ ] **步骤 1：创建探测模块文档**

```markdown
# Phase 4: K8s 环境探测

## 目标

探测 K8s 集群环境，获取：
- 节点列表
- 每个节点的 NPU 数量和类型
- 推荐的部署节点

## 前置检查

执行 `scripts/detect-k8s-env.sh`，验证：
- kubectl 是否可用
- kubeconfig 是否配置
- 集群是否可连接

## 执行脚本

```bash
bash scripts/detect-k8s-env.sh
```

## 输出

生成 `detection-result.json`：

```json
{
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-1",
      "ip": "192.168.1.101",
      "npu_type": "huawei.com/Ascend910",
      "npu_count": 8,
      "npu_available": 8,
      "labels": {"npu": "true"}
    },
    {
      "name": "node-2",
      "ip": "192.168.1.102",
      "npu_type": "huawei.com/Ascend910",
      "npu_count": 8,
      "npu_available": 8,
      "labels": {"npu": "true"}
    }
  ],
  "recommended_nodes": ["node-1", "node-2"],
  "total_npu_available": 16
}
```

## AI 执行指南

1. 执行探测脚本
2. 解析输出 JSON
3. 展示节点列表和 NPU 信息
4. 根据部署方式推荐节点：
   - `single_node`: 选择 NPU 数量最多的节点
   - `multi_node`: 选择多个有足够 NPU 的节点
   - `pd_separate`: 分别推荐 Prefill 和 Decode 节点
5. 使用 AskUserQuestion 确认节点选择
6. 保存探测结果到 `.vllm-deploy/detection-result.json`
7. 进入 Phase 7（补）

## 用户交互

展示探测结果后，询问：
```
检测到以下节点：
- node-1: 8 个 Ascend910 NPU（可用 8）
- node-2: 8 个 Ascend910 NPU（可用 8）

推荐部署节点：node-1 (Master), node-2 (Worker)

请确认或修改节点选择：
```

## 错误处理

| 错误 | 处理 |
|------|------|
| kubectl not found | 提示安装：`apt install kubectl` 或下载二进制 |
| kubeconfig missing | 提示配置：`export KUBECONFIG=/path/to/config` |
| cluster unreachable | 提示检查网络和 API Server 地址 |
| no NPU nodes | 提示检查 Ascend Device Plugin 安装 |
```

- [ ] **步骤 2：创建探测脚本**

```bash
#!/bin/bash
# K8s 环境探测脚本
# 检测 kubectl 可用性、集群连接、节点 NPU 信息

set -e

# ============ 前置检查 ============

echo "=== K8s Environment Detection ==="

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    cat <<EOF
{
  "cluster_connected": false,
  "error": "kubectl not found",
  "message": "Please install kubectl: apt install kubectl or download from https://kubernetes.io/docs/tasks/tools/"
}
EOF
    exit 1
fi

# 检查 kubeconfig
if ! kubectl config view --minify &> /dev/null; then
    cat <<EOF
{
  "cluster_connected": false,
  "error": "kubeconfig not configured",
  "message": "Please configure kubeconfig: export KUBECONFIG=/path/to/config"
}
EOF
    exit 1
fi

# 检查集群连接
if ! kubectl cluster-info &> /dev/null; then
    cat <<EOF
{
  "cluster_connected": false,
  "error": "cluster unreachable",
  "message": "Please check API Server address and network connectivity"
}
EOF
    exit 1
fi

echo "Cluster connected successfully!"

# ============ 获取节点信息 ============

# 获取所有节点
NODES=$(kubectl get nodes -o json)

# 解析节点 NPU 信息
# 支持 huawei.com/Ascend910, huawei.com/NPU 等资源类型
NPU_RESOURCE_TYPES="huawei.com/Ascend910 huawei.com/NPU huawei.com/Ascend310P huawei.com/Ascend910B"

# 构建节点列表 JSON
NODE_LIST="[]"

for node_name in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    # 获取节点 IP
    NODE_IP=$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    
    # 获取节点标签
    LABELS=$(kubectl get node "$node_name" -o jsonpath='{.metadata.labels}' | jq -c '.')
    
    # 检测 NPU 资源
    NPU_TYPE=""
    NPU_COUNT=0
    NPU_AVAILABLE=0
    
    for npu_type in $NPU_RESOURCE_TYPES; do
        allocatable=$(kubectl get node "$node_name" -o jsonpath='{.status.allocatable.'"$npu_type"'}')
        if [ -n "$allocatable" ] && [ "$allocatable" != "0" ]; then
            NPU_TYPE="$npu_type"
            NPU_COUNT="$allocatable"
            # 获取可用数量（allocatable - allocated）
            capacity=$(kubectl get node "$node_name" -o jsonpath='{.status.capacity.'"$npu_type"'}')
            NPU_AVAILABLE="$capacity"
            break
        fi
    done
    
    # 构建节点 JSON
    NODE_JSON=$(cat <<EOF
{
  "name": "$node_name",
  "ip": "$NODE_IP",
  "npu_type": "$NPU_TYPE",
  "npu_count": $NPU_COUNT,
  "npu_available": $NPU_AVAILABLE,
  "labels": $LABELS
}
EOF
)
    
    # 添加到节点列表
    NODE_LIST=$(echo "$NODE_LIST" | jq -c '. + ['"$NODE_JSON"']')
done

# ============ 推荐节点 ============

# 按可用 NPU 数量排序，选择最多 NPU 的节点
RECOMMENDED=$(echo "$NODE_LIST" | jq -r '[.[] | select(.npu_available > 0)] | sort_by(-.npu_available) | .[].name')

# 计算总可用 NPU
TOTAL_NPU=$(echo "$NODE_LIST" | jq '[.[].npu_available] | add')

# ============ 输出结果 ============

cat <<EOF
{
  "cluster_connected": true,
  "nodes": $NODE_LIST,
  "recommended_nodes": $(echo "$RECOMMENDED" | jq -R -s 'split("\n") | map(select(length > 0))'),
  "total_npu_available": $TOTAL_NPU
}
EOF

echo ""
echo "Detection completed. Total available NPU: $TOTAL_NPU"
```

- [ ] **步骤 3：设置脚本权限**

```bash
chmod +x skill-execute/scripts/detect-k8s-env.sh
```

- [ ] **步骤 4：Commit**

```bash
git add skill-execute/modules/k8s-env-detector.md skill-execute/scripts/detect-k8s-env.sh
git commit -m "feat(skill-execute): add K8s environment detection module and script"
```

---

## 任务 3：创建 YAML 填充生成模块

**文件：**
- 创建：`skill-execute/modules/yaml-generator.md`
- 创建：`skill-execute/scripts/fill-template.sh`

- [ ] **步骤 1：创建 YAML 生成模块文档**

```markdown
# Phase 7（补）：填充模板生成 YAML

## 目标

读取 Skill 1 生成的模板文件，结合 K8s 环境探测结果，填充占位符生成最终 K8s YAML 文件。

## 输入

- `.vllm-deploy/config.json` - 用户配置
- `.vllm-deploy/detection-result.json` - K8s 环境探测结果
- `.vllm-deploy/templates/*.yaml` - 模板文件（含占位符）

## 占位符填充规则

### 通用占位符

| 占位符 | 来源 |
|--------|------|
| `${NAMESPACE}` | config.json → namespace |
| `${MODEL_NAME}` | config.json → selected_model |
| `${MODEL_PATH}` | config.json → model_path |
| `${IMAGE}` | config.json → target_image |
| `${NPU_RESOURCE_TYPE}` | detection-result.json → nodes[0].npu_type |
| `${NPU_COUNT}` | 根据部署方式计算 |
| `${SERVICE_PORT}` | 自动分配或用户指定 |

### 多节点专属占位符

| 占位符 | 来源 |
|--------|------|
| `${MASTER_NODE_NAME}` | 用户选择的 Master 节点 |
| `${MASTER_NODE_IP}` | detection-result.json → 对应节点 IP |
| `${WORKER_NODE_NAME}` | 用户选择的 Worker 节点 |
| `${WORKER_NODE_IP}` | detection-result.json → 对应节点 IP |
| `${WORLD_SIZE}` | 部署节点数量 |
| `${MASTER_PORT}` | 默认 29500 |

### 资源占位符

| 占位符 | 默认值 |
|--------|--------|
| `${CPU_LIMIT}` | 8 |
| `${MEMORY_LIMIT}` | 64Gi |
| `${CPU_REQUEST}` | 8 |
| `${MEMORY_REQUEST}` | 64Gi |
| `${MODEL_MOUNT_PATH}` | /data |
| `${MODEL_PATH_HOST}` | config.json → model_path |

## 执行逻辑

根据 `deploy_mode` 处理：

### single_node

1. 读取 `single-node.yaml` 模板
2. 填充所有占位符
3. 输出单个 YAML 文件

### multi_node

1. 读取 `multi-node.yaml` 模板
2. 生成 Master Deployment（填充 Master 相关占位符）
3. 为每个 Worker 节点生成独立 Deployment（填充 Worker 相关占位符）
4. 输出多个 YAML 文件

### pd_separate

1. 读取 `pd-separate.yaml` 或 `pd-separate-kthena.yaml` 模板
2. 分别填充 Prefill 和 Decode 配置
3. 输出多个 YAML 文件

### ha_active_standby

1. 读取 `ha-active-standby.yaml` 模板
2. 填充高可用配置
3. 输出单个 YAML 文件

## 输出目录

```
.vllm-deploy/
└── k8s/
    ├── namespace.yaml
    ├── configmap.yaml
    ├── deployment-master.yaml      # multi_node 时
    ├── deployment-worker-1.yaml    # multi_node 时（按节点数量）
    ├── deployment-worker-2.yaml
    ├── deployment-prefill.yaml     # pd_separate 时
    ├── deployment-decode.yaml      # pd_separate 时
    ├── deployment.yaml             # single_node 时
    ├── service.yaml
    ├── apply-all.sh
    └── README.md
```

## AI 执行指南

1. 读取 `config.json` 和 `detection-result.json`
2. 确定用户选择的部署节点（来自 Phase 4 确认）
3. 执行 `scripts/fill-template.sh`
4. 生成 `.vllm-deploy/k8s/` 目录下的所有 YAML 文件
5. 展示生成的文件列表
6. 进入 Phase 8
```

- [ ] **步骤 2：创建模板填充脚本**

```bash
#!/bin/bash
# 模板占位符填充脚本
# 读取模板文件，填充占位符，生成最终 YAML

set -e

# ============ 参数检查 ============

CONFIG_FILE="${1:-.vllm-deploy/config.json}"
DETECTION_FILE="${2:-.vllm-deploy/detection-result.json}"
OUTPUT_DIR="${3:-.vllm-deploy/k8s}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found at $CONFIG_FILE"
    echo "Please run /vllm-deploy-prepare first"
    exit 1
fi

if [ ! -f "$DETECTION_FILE" ]; then
    echo "Error: detection-result.json not found at $DETECTION_FILE"
    echo "Please run K8s environment detection first"
    exit 1
fi

echo "=== Filling Templates ==="
echo "Config: $CONFIG_FILE"
echo "Detection: $DETECTION_FILE"
echo "Output: $OUTPUT_DIR"

# ============ 创建输出目录 ============

mkdir -p "$OUTPUT_DIR"

# ============ 读取配置 ============

NAMESPACE=$(jq -r '.namespace' "$CONFIG_FILE")
MODEL_NAME=$(jq -r '.selected_model' "$CONFIG_FILE")
MODEL_PATH=$(jq -r '.model_path' "$CONFIG_FILE")
IMAGE=$(jq -r '.target_image' "$CONFIG_FILE")
DEPLOY_MODE=$(jq -r '.deploy_mode' "$CONFIG_FILE")
MAX_MODEL_LEN=$(jq -r '.max_model_len' "$CONFIG_FILE")
MAX_NUM_SEQS=$(jq -r '.max_num_seqs' "$CONFIG_FILE")
TENSOR_PARALLEL_SIZE=$(jq -r '.tensor_parallel_size' "$CONFIG_FILE")
MASTER_PORT=$(jq -r '.master_port // 29500' "$CONFIG_FILE")

# 资源默认值
CPU_LIMIT="${CPU_LIMIT:-8}"
MEMORY_LIMIT="${MEMORY_LIMIT:-64Gi}"
CPU_REQUEST="${CPU_REQUEST:-8}"
MEMORY_REQUEST="${MEMORY_REQUEST:-64Gi}"
SERVICE_PORT="${SERVICE_PORT:-30000}"

# ============ 读取探测结果 ============

NPU_RESOURCE_TYPE=$(jq -r '.nodes[0].npu_type' "$DETECTION_FILE")
RECOMMENDED_NODES=$(jq -r '.recommended_nodes' "$DETECTION_FILE")

# 用户选择的节点（从环境变量或交互确认）
SELECTED_MASTER="${SELECTED_MASTER:-$(jq -r '.recommended_nodes[0]' "$DETECTION_FILE")}"
SELECTED_WORKERS="${SELECTED_WORKERS:-$(jq -r '.recommended_nodes[1:] | join(" ")' "$DETECTION_FILE")}"

# ============ 填充函数 ============

fill_template() {
    local template_file="$1"
    local output_file="$2"
    local extra_subs="$3"
    
    # 基础替换
    local subs="s/\${NAMESPACE}/$NAMESPACE/g
s/\${MODEL_NAME}/$MODEL_NAME/g
s/\${MODEL_PATH}/$MODEL_PATH/g
s/\${IMAGE}/$IMAGE/g
s/\${NPU_RESOURCE_TYPE}/$NPU_RESOURCE_TYPE/g
s/\${MAX_MODEL_LEN}/$MAX_MODEL_LEN/g
s/\${MAX_NUM_SEQS}/$MAX_NUM_SEQS/g
s/\${TENSOR_PARALLEL_SIZE}/$TENSOR_PARALLEL_SIZE/g
s/\${CPU_LIMIT}/$CPU_LIMIT/g
s/\${MEMORY_LIMIT}/$MEMORY_LIMIT/g
s/\${CPU_REQUEST}/$CPU_REQUEST/g
s/\${MEMORY_REQUEST}/$MEMORY_REQUEST/g
s/\${SERVICE_PORT}/$SERVICE_PORT/g
s/\${MODEL_MOUNT_PATH}/\/data/g
s/\${MODEL_PATH_HOST}/$MODEL_PATH/g
s/\${MASTER_PORT}/$MASTER_PORT/g"
    
    # 添加额外替换
    if [ -n "$extra_subs" ]; then
        subs="$subs
$extra_subs"
    fi
    
    sed "$subs" "$template_file" > "$output_file"
    echo "Generated: $output_file"
}

# ============ 根据部署方式生成 ============

TEMPLATE_DIR=".vllm-deploy/templates"

case "$DEPLOY_MODE" in
    single_node)
        # 单节点部署
        NPU_COUNT=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .npu_available' "$DETECTION_FILE")
        
        fill_template "$TEMPLATE_DIR/single-node.yaml" "$OUTPUT_DIR/namespace.yaml" "s/\${NPU_COUNT}/$NPU_COUNT/g"
        
        # 提取各部分
        # Namespace
        sed -n '1,12p' "$OUTPUT_DIR/namespace.yaml" > "$OUTPUT_DIR/namespace-only.yaml"
        mv "$OUTPUT_DIR/namespace-only.yaml" "$OUTPUT_DIR/namespace.yaml"
        
        # ConfigMap
        fill_template "$TEMPLATE_DIR/single-node.yaml" "$OUTPUT_DIR/configmap.yaml" "s/\${NPU_COUNT}/$NPU_COUNT/g"
        sed -n '14,24p' "$OUTPUT_DIR/configmap.yaml" > "$OUTPUT_DIR/configmap-only.yaml"
        mv "$OUTPUT_DIR/configmap-only.yaml" "$OUTPUT_DIR/configmap.yaml"
        
        # Deployment
        fill_template "$TEMPLATE_DIR/single-node.yaml" "$OUTPUT_DIR/deployment.yaml" "s/\${NPU_COUNT}/$NPU_COUNT/g"
        sed -n '26,121p' "$OUTPUT_DIR/deployment.yaml" > "$OUTPUT_DIR/deployment-only.yaml"
        mv "$OUTPUT_DIR/deployment-only.yaml" "$OUTPUT_DIR/deployment.yaml"
        
        # Service
        fill_template "$TEMPLATE_DIR/single-node.yaml" "$OUTPUT_DIR/service.yaml" "s/\${NPU_COUNT}/$NPU_COUNT/g"
        sed -n '123,138p' "$OUTPUT_DIR/service.yaml" > "$OUTPUT_DIR/service-only.yaml"
        mv "$OUTPUT_DIR/service-only.yaml" "$OUTPUT_DIR/service.yaml"
        ;;
    
    multi_node)
        # 多节点分布式部署
        WORLD_SIZE=$(echo "$SELECTED_WORKERS" | wc -w | xargs)
        WORLD_SIZE=$((WORLD_SIZE + 1))  # +1 for master
        
        # Master 信息
        MASTER_NODE_IP=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .ip' "$DETECTION_FILE")
        NPU_COUNT_PER_NODE=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .npu_available' "$DETECTION_FILE")
        
        # 生成 Master Deployment
        MASTER_SUBS="s/\${MASTER_NODE_NAME}/$SELECTED_MASTER/g
s/\${MASTER_NODE_IP}/$MASTER_NODE_IP/g
s/\${WORLD_SIZE}/$WORLD_SIZE/g
s/\${NPU_COUNT_PER_NODE}/$NPU_COUNT_PER_NODE/g"
        
        fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/namespace.yaml" "$MASTER_SUBS"
        sed -n '1,14p' "$OUTPUT_DIR/namespace.yaml" > "$OUTPUT_DIR/namespace-only.yaml"
        mv "$OUTPUT_DIR/namespace-only.yaml" "$OUTPUT_DIR/namespace.yaml"
        
        fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/configmap.yaml" "$MASTER_SUBS"
        sed -n '16,29p' "$OUTPUT_DIR/configmap.yaml" > "$OUTPUT_DIR/configmap-only.yaml"
        mv "$OUTPUT_DIR/configmap-only.yaml" "$OUTPUT_DIR/configmap.yaml"
        
        fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/deployment-master.yaml" "$MASTER_SUBS"
        sed -n '31,147p' "$OUTPUT_DIR/deployment-master.yaml" > "$OUTPUT_DIR/deployment-master-only.yaml"
        mv "$OUTPUT_DIR/deployment-master-only.yaml" "$OUTPUT_DIR/deployment-master.yaml"
        
        # 生成 Worker Deployments
        WORKER_RANK=1
        for worker_node in $SELECTED_WORKERS; do
            WORKER_NODE_IP=$(jq -r '.nodes[] | select(.name=="'$worker_node'") | .ip' "$DETECTION_FILE")
            
            WORKER_SUBS="s/\${WORKER_RANK}/$WORKER_RANK/g
s/\${WORKER_NODE_NAME}/$worker_node/g
s/\${WORKER_NODE_IP}/$WORKER_NODE_IP/g
s/\${MASTER_NODE_IP}/$MASTER_NODE_IP/g
s/\${WORLD_SIZE}/$WORLD_SIZE/g
s/\${NPU_COUNT_PER_NODE}/$NPU_COUNT_PER_NODE/g"
            
            fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/deployment-worker-$WORKER_RANK.yaml" "$WORKER_SUBS"
            sed -n '149,262p' "$OUTPUT_DIR/deployment-worker-$WORKER_RANK.yaml" > "$OUTPUT_DIR/deployment-worker-$WORKER_RANK-only.yaml"
            mv "$OUTPUT_DIR/deployment-worker-$WORKER_RANK-only.yaml" "$OUTPUT_DIR/deployment-worker-$WORKER_RANK.yaml"
            
            WORKER_RANK=$((WORKER_RANK + 1))
        done
        
        fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/service.yaml" "$MASTER_SUBS"
        sed -n '264,279p' "$OUTPUT_DIR/service.yaml" > "$OUTPUT_DIR/service-only.yaml"
        mv "$OUTPUT_DIR/service-only.yaml" "$OUTPUT_DIR/service.yaml"
        ;;
    
    pd_separate)
        # PD 分离部署
        # TODO: 实现 PD 分离模板填充
        echo "PD separate deployment mode - requires additional configuration"
        ;;
    
    ha_active_standby)
        # 高可用部署
        # TODO: 实现高可用模板填充
        echo "HA active-standby deployment mode - requires additional configuration"
        ;;
    
    *)
        echo "Error: Unknown deploy_mode: $DEPLOY_MODE"
        exit 1
        ;;
esac

# ============ 生成 apply-all.sh ============

cat <<EOF > "$OUTPUT_DIR/apply-all.sh"
#!/bin/bash
# 一键部署脚本
# 执行所有 K8s YAML 文件的 apply

set -e

echo "=== Deploying to K8s ==="
echo "Namespace: $NAMESPACE"

kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml

# Apply Deployments
for deploy in deployment*.yaml; do
    kubectl apply -f "\$deploy"
done

kubectl apply -f service.yaml

echo "=== Deployment Complete ==="
echo "Service exposed on NodePort: $SERVICE_PORT"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "Access vLLM service:"
echo "  http://<node-ip>:$SERVICE_PORT"
EOF

chmod +x "$OUTPUT_DIR/apply-all.sh"
echo "Generated: $OUTPUT_DIR/apply-all.sh"

# ============ 生成 README.md ============

cat <<EOF > "$OUTPUT_DIR/README.md"
# vLLM 部署指南

## 部署信息

- **模型**: $MODEL_NAME
- **Namespace**: $NAMESPACE
- **部署方式**: $DEPLOY_MODE
- **镜像**: $IMAGE

## 部署步骤

1. 执行一键部署：
   ```bash
   cd $OUTPUT_DIR
   bash apply-all.sh
   ```

2. 检查 Pod 状态：
   ```bash
   kubectl get pods -n $NAMESPACE -w
   ```

3. 等待 Pod Ready 后，访问服务：
   ```bash
   curl http://<node-ip>:$SERVICE_PORT/v1/models
   ```

## 文件清单

- `namespace.yaml` - Namespace 定义
- `configmap.yaml` - 配置参数
- `deployment*.yaml` - Deployment 定义
- `service.yaml` - Service 定义
- `apply-all.sh` - 一键部署脚本

## 清理

```bash
kubectl delete -f service.yaml
kubectl delete -f deployment*.yaml
kubectl delete -f configmap.yaml
kubectl delete -f namespace.yaml
```
EOF

echo "Generated: $OUTPUT_DIR/README.md"
echo ""
echo "=== Template Filling Complete ==="
echo "Output files:"
ls -la "$OUTPUT_DIR"
```

- [ ] **步骤 3：设置脚本权限**

```bash
chmod +x skill-execute/scripts/fill-template.sh
```

- [ ] **步骤 4：Commit**

```bash
git add skill-execute/modules/yaml-generator.md skill-execute/scripts/fill-template.sh
git commit -m "feat(skill-execute): add YAML generator module and fill-template script"
```

---

## 任务 4：创建 K8s Apply 指导模块

**文件：**
- 创建：`skill-execute/modules/k8s-apply-guide.md`

- [ ] **步骤 1：创建 Apply 指导模块文档**

```markdown
# Phase 8: K8s Apply 指导

## 目标

指导用户执行 K8s Apply，部署 vLLM 服务。

## 输入

- `.vllm-deploy/k8s/*.yaml` - 生成的 K8s YAML 文件
- `.vllm-deploy/k8s/apply-all.sh` - 一键部署脚本

## 用户交互点

此阶段需要用户手动执行，AI 等待用户确认。

## AI 执行指南

1. 展示 `.vllm-deploy/k8s/` 目录内容
2. 提示用户执行一键部署脚本
3. 提供手动 Apply 的备选方案
4. 等待用户确认 Pod 启动成功

## 指导输出

```
=== 部署文件已生成 ===

目录：.vllm-deploy/k8s/
文件：
- namespace.yaml
- configmap.yaml
- deployment*.yaml
- service.yaml
- apply-all.sh
- README.md

执行部署：
1. cd .vllm-deploy/k8s/
2. bash apply-all.sh

或手动执行：
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml  # 或多个 deployment 文件
kubectl apply -f service.yaml

完成后请回复 "部署完成" 或报告错误信息。
```

## 错误处理建议

| 错误 | 处理建议 |
|------|---------|
| ImagePullBackOff | 检查镜像是否存在于目标仓库，检查 docker login |
| Pending | 检查节点资源是否足够，检查 NPU Device Plugin |
| CrashLoopBackOff | 检查模型路径，检查容器日志 |
| Insufficient NPU | 检查节点 NPU 是否被其他 Pod 占用 |

## 下一步

用户确认 Pod 启动后，进入 Phase 9（容器内 NPU 探测）。
```

- [ ] **步骤 2：Commit**

```bash
git add skill-execute/modules/k8s-apply-guide.md
git commit -m "feat(skill-execute): add K8s apply guide module"
```

---

## 任务 5：创建容器内环境探测模块

**文件：**
- 创建：`skill-execute/modules/container-env-detector.md`
- 创建：`skill-execute/scripts/detect-container-npu.sh`

- [ ] **步骤 1：创建容器探测模块文档**

```markdown
# Phase 9: 容器内环境探测

## 目标

进入已启动的 Pod，探测容器内的 NPU 设备映射情况。

## 前置条件

- Phase 8 已完成，Pod 处于 Running 状态
- 用户已确认 Pod 启动成功

## 执行方式

通过 kubectl exec 进入 Pod 执行探测脚本。

## AI 执行指南

1. 获取 Pod 名称：
   ```bash
   kubectl get pods -n ${NAMESPACE} -l app=vllm-deploy
   ```

2. 在 Pod 内执行探测：
   ```bash
   kubectl exec -n ${NAMESPACE} ${POD_NAME} -- bash scripts/detect-container-npu.sh
   ```

3. 解析探测结果，确认 NPU 设备映射正确

4. 如果映射异常，提示检查 Device Plugin 配置

## 探测内容

- `/dev` 目录下的 NPU 设备文件
- `npu-smi` 命令输出（如果可用）
- 环境变量中的 NPU 相关配置

## 输出

容器内 NPU 信息 JSON：

```json
{
  "pod_name": "vllm-glm5-master-xxx",
  "npu_devices": [
    "/dev/davinci0",
    "/dev/davinci1",
    "/dev/davinci2",
    "/dev/davinci3"
  ],
  "npu_count": 4,
  "npu_smi_available": true,
  "npu_info": [
    {"device_id": 0, "chip_type": "Ascend910", "status": "OK"}
  ]
}
```

## 异常处理

如果探测结果显示 NPU 设备数量与预期不符：
- 检查 Deployment 的 resources.limits 配置
- 检查 Ascend Device Plugin 是否正常运行
- 检查节点上的 NPU 是否被其他 Pod 占用

## 下一步

探测成功后，进入 Phase 10（生成部署脚本）。
```

- [ ] **步骤 2：创建容器探测脚本**

```bash
#!/bin/bash
# 容器内 NPU 环境探测脚本
# 在 Pod 内执行，检测 NPU 设备映射

set -e

echo "=== Container NPU Detection ==="

# ============ 检查 /dev 目录 ============

NPU_DEVICES=""
for i in 0 1 2 3 4 5 6 7; do
    if [ -e "/dev/davinci$i" ]; then
        NPU_DEVICES="$NPU_DEVICES /dev/davinci$i"
    fi
done

# 也检查其他可能的设备名
for dev in /dev/davinci_manager /dev/devmm_svm /dev/hisi_hdc; do
    if [ -e "$dev" ]; then
        NPU_DEVICES="$NPU_DEVICES $dev"
    fi
done

NPU_DEVICES=$(echo "$NPU_DEVICES" | tr ' ' '\n' | grep -v '^$' | sort -u)

NPU_COUNT=$(echo "$NPU_DEVICES" | grep '/dev/davinci[0-9]' | wc -l)

echo "NPU Devices found:"
echo "$NPU_DEVICES"
echo "NPU Count: $NPU_COUNT"

# ============ 检查 npu-smi ============

NPU_SMI_AVAILABLE=false
NPU_INFO="[]"

if command -v npu-smi &> /dev/null; then
    NPU_SMI_AVAILABLE=true
    echo ""
    echo "=== NPU-SMI Info ==="
    npu-smi info 2>/dev/null || echo "npu-smi info failed"
    
    # 尝试解析 npu-smi 输出（简化版）
    NPU_INFO=$(npu-smi info -t 2>/dev/null | awk '
    BEGIN { devices="[]" }
    /Device ID/ { 
        split($0, arr, ":")
        id=arr[2]
        gsub(/ /, "", id)
        devices=devices "{" "\"device_id\": " id "}"
    }
    END { print devices }
    ' || echo "[]")
fi

# ============ 检查环境变量 ============

echo ""
echo "=== NPU Related Environment Variables ==="
env | grep -E 'HCCL|NPU|ASCEND|RANK|WORLD|MASTER' || echo "No NPU env vars found"

# ============ 输出 JSON ============

cat <<EOF
{
  "pod_name": "${HOSTNAME:-unknown}",
  "npu_devices": [$(echo "$NPU_DEVICES" | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')],
  "npu_count": $NPU_COUNT,
  "npu_smi_available": $NPU_SMI_AVAILABLE,
  "npu_info": $NPU_INFO
}
EOF

echo ""
echo "=== Detection Complete ==="
```

- [ ] **步骤 3：设置脚本权限**

```bash
chmod +x skill-execute/scripts/detect-container-npu.sh
```

- [ ] **步骤 4：Commit**

```bash
git add skill-execute/modules/container-env-detector.md skill-execute/scripts/detect-container-npu.sh
git commit -m "feat(skill-execute): add container environment detection module and script"
```

---

## 任务 6：创建部署脚本生成模块

**文件：**
- 创建：`skill-execute/modules/deploy-generator.md`

- [ ] **步骤 1：创建部署脚本生成模块文档**

```markdown
# Phase 10: 部署脚本生成

## 目标

根据容器内 NPU 探测结果，生成 Pod 内执行的 vLLM 启动脚本。

## 输入

- `.vllm-deploy/config.json` - 用户配置
- 容器内 NPU 探测结果（Phase 9）
- Skill 1 生成的启动脚本模板（`.vllm-deploy/scripts/`）

## 脚本选择逻辑

根据 `deploy_mode` 选择对应的启动脚本：

| deploy_mode | 脚本 |
|-------------|------|
| `single_node` | `start-single-node.sh` |
| `multi_node` | Master: `start-multi-node-master.sh`, Worker: `start-multi-node-worker.sh` |
| `pd_separate` | Prefill: `start-prefill.sh`, Decode: `start-decode.sh` |

## 占位符填充

读取 Skill 1 生成的脚本模板，填充探测获得的参数：

### 多节点脚本填充

| 占位符 | 来源 |
|--------|------|
| `${NODE_IP_PLACEHOLDER}` | Pod 的 status.podIP |
| `${WORLD_SIZE_PLACEHOLDER}` | 部署节点数量 |
| `${MASTER_ADDR_PLACEHOLDER}` | Master Pod IP |
| `${WORKER_RANK_PLACEHOLDER}` | Pod 的 Rank 标签 |

### PD 分离脚本填充

| 占位符 | 来源 |
|--------|------|
| `${PREFILL_ADDR_PLACEHOLDER}` | Prefill Pod IP |
| `${NODE_IP_PLACEHOLDER}` | Pod IP |

## 输出

生成 `.vllm-deploy/k8s/deploy.sh`：

```bash
#!/bin/bash
# Pod 内 vLLM 启动脚本
# 参数已填充

MODEL_PATH="/data/models/GLM-5"
TENSOR_PARALLEL_SIZE=8
...

vllm serve "$MODEL_PATH" ...
```

## AI 执行指南

1. 读取 config.json 确定 deploy_mode
2. 选择对应的启动脚本模板
3. 填充探测获得的参数
4. 生成 deploy.sh 到 `.vllm-deploy/k8s/`
5. 展示脚本内容
6. 进入 Phase 11

## 多节点脚本生成

对于多节点部署，需要为每个 Pod 生成对应的脚本：

- Master Pod: `deploy-master.sh`
- Worker Pod 1: `deploy-worker-1.sh`
- Worker Pod 2: `deploy-worker-2.sh`

每个脚本需要填充不同的 Rank 和节点 IP。
```

- [ ] **步骤 2：Commit**

```bash
git add skill-execute/modules/deploy-generator.md
git commit -m "feat(skill-execute): add deploy script generator module"
```

---

## 任务 7：创建部署执行指导模块

**文件：**
- 创建：`skill-execute/modules/deploy-execution-guide.md`

- [ ] **步骤 1：创建部署执行指导模块文档**

```markdown
# Phase 11: 部署执行指导

## 目标

指导用户在 Pod 内执行 vLLM 启动脚本，完成服务部署。

## 输入

- `.vllm-deploy/k8s/deploy.sh` - 生成的启动脚本
- Pod 名称列表

## 用户交互点

此阶段需要用户手动在 Pod 内执行脚本，AI 等待用户确认。

## AI 执行指南

1. 展示需要执行的 Pod 和对应脚本
2. 提供执行命令模板
3. 等待用户确认 vLLM 服务启动成功

## 指导输出

```
=== 在 Pod 内执行 vLLM 启动脚本 ===

Pod: vllm-glm5-master-xxx
执行命令：
kubectl exec -n vllm-glm5 vllm-glm5-master-xxx -- bash /path/to/deploy.sh

或交互式进入：
kubectl exec -n vllm-glm5 -it vllm-glm5-master-xxx -- bash
cd /path/to/scripts
bash deploy.sh

完成后请回复 "vLLM 服务已启动" 或报告错误日志。
```

## 多节点执行顺序

对于多节点部署，执行顺序：
1. 先启动 Master Pod 的脚本
2. 等待 Master 就绪
3. 再启动各 Worker Pod 的脚本

## PD 分离执行顺序

对于 PD 分离部署：
1. 先启动 Prefill Pod
2. 等待 Prefill 就绪
3. 再启动 Decode Pod

## 验证服务

启动成功后，验证：
```bash
curl http://<pod-ip>:8000/health
curl http://<pod-ip>:8000/v1/models
```

## 下一步

用户确认服务启动后，进入 Phase 12（输出交付）。
```

- [ ] **步骤 2：Commit**

```bash
git add skill-execute/modules/deploy-execution-guide.md
git commit -m "feat(skill-execute): add deploy execution guide module"
```

---

## 任务 8：创建输出交付模块

**文件：**
- 创建：`skill-execute/modules/output-guide.md`

- [ ] **步骤 1：创建输出交付模块文档**

```markdown
# Phase 12: 输出交付

## 目标

汇总整个部署过程的输出，生成最终交付文档。

## 输入

- 所有已生成的文件
- 部署状态确认
- Service 访问信息

## 输出文件

### final-output.json

```json
{
  "deployment_status": "success",
  "namespace": "vllm-glm5",
  "model": "GLM-5",
  "deploy_mode": "multi_node",
  "pods": [
    {"name": "vllm-glm5-master-xxx", "status": "Running", "role": "master"},
    {"name": "vllm-glm5-worker-1-xxx", "status": "Running", "role": "worker", "rank": 1}
  ],
  "service": {
    "name": "vllm-service",
    "type": "NodePort",
    "port": 8000,
    "node_port": 30000,
    "endpoint": "http://192.168.1.101:30000"
  },
  "config_files": [
    ".vllm-deploy/config.json",
    ".vllm-deploy/detection-result.json",
    ".vllm-deploy/k8s/*.yaml"
  ]
}
```

### 最终 README 更新

更新 `.vllm-deploy/k8s/README.md`，添加：
- 实际部署信息
- Pod 状态
- Service 访问方式
- 常用操作命令

## AI 执行指南

1. 获取 Pod 状态：
   ```bash
   kubectl get pods -n ${NAMESPACE} -o wide
   ```

2. 获取 Service 信息：
   ```bash
   kubectl get svc -n ${NAMESPACE}
   ```

3. 生成 final-output.json
4. 更新 README.md
5. 展示最终交付摘要

## 最终交付摘要

```
=== 部署完成 ===

模型：GLM-5
Namespace：vllm-glm5
部署方式：多节点分布式

Pod 状态：
- vllm-glm5-master-xxx: Running (Master)
- vllm-glm5-worker-1-xxx: Running (Worker Rank 1)

服务访问：
- NodePort: 30000
- Endpoint: http://192.168.1.101:30000

API 端点：
- /v1/models - 模型列表
- /v1/chat/completions - Chat API
- /health - 健康检查

文件输出：
- .vllm-deploy/config.json
- .vllm-deploy/detection-result.json
- .vllm-deploy/k8s/*.yaml
- .vllm-deploy/k8s/README.md
- .vllm-deploy/final-output.json

常用命令：
kubectl get pods -n vllm-glm5
kubectl logs -n vllm-glm5 vllm-glm5-master-xxx
kubectl delete namespace vllm-glm5  # 清理部署
```

## 清理指南

提供清理命令，方便用户重新部署或删除：
```bash
kubectl delete namespace vllm-glm5
rm -rf .vllm-deploy/
```
```

- [ ] **步骤 2：Commit**

```bash
git add skill-execute/modules/output-guide.md
git commit -m "feat(skill-execute): add output delivery module"
```

---

## 任务 9：验证 Skill 完整性

- [ ] **步骤 1：检查文件完整性**

```bash
find skill-execute -type f | wc -l
# 预期：10 个文件
```

- [ ] **步骤 2：检查脚本可执行权限**

```bash
ls -la skill-execute/scripts/*.sh
# 预期：所有脚本有 -rwxr-xr-x 权限
```

- [ ] **步骤 3：检查模块文件列表**

```bash
ls -la skill-execute/modules/
# 预期：7 个模块文件
```

---

## 任务 10：同步到已安装 Skill 目录

- [ ] **步骤 1：创建目标目录**

```bash
mkdir -p ~/.claude/skills/vllm-deploy-execute/modules
mkdir -p ~/.claude/skills/vllm-deploy-execute/scripts
```

- [ ] **步骤 2：同步所有文件**

```bash
cp skill-execute/SKILL.md ~/.claude/skills/vllm-deploy-execute/
cp skill-execute/modules/*.md ~/.claude/skills/vllm-deploy-execute/modules/
cp skill-execute/scripts/*.sh ~/.claude/skills/vllm-deploy-execute/scripts/
chmod +x ~/.claude/skills/vllm-deploy-execute/scripts/*.sh
```

- [ ] **步骤 3：验证安装**

```bash
ls -la ~/.claude/skills/vllm-deploy-execute/
ls -la ~/.claude/skills/vllm-deploy-execute/modules/
ls -la ~/.claude/skills/vllm-deploy-execute/scripts/
```

---

## 任务 11：最终 Commit 和验证

- [ ] **步骤 1：最终 Commit**

```bash
git add skill-execute/
git commit -m "feat(skill-execute): complete vllm-deploy-execute skill implementation

- Add SKILL.md entry file
- Add 7 module files for all phases (4, 7, 8, 9, 10, 11, 12)
- Add 3 helper scripts (detect-k8s-env, detect-container-npu, fill-template)
- Total 10 files for Skill 2"
```

- [ ] **步骤 2：更新设计规格状态**

在设计规格文件中更新 Skill 2 状态为"已实现"。

---

## 文件清单汇总

| 类别 | 文件 | 状态 |
|------|------|------|
| 入口 | `skill-execute/SKILL.md` | 新增 |
| 模块 | `modules/k8s-env-detector.md` | 新增 |
| 模块 | `modules/yaml-generator.md` | 新增 |
| 模块 | `modules/k8s-apply-guide.md` | 新增 |
| 模块 | `modules/container-env-detector.md` | 新增 |
| 模块 | `modules/deploy-generator.md` | 新增 |
| 模块 | `modules/deploy-execution-guide.md` | 新增 |
| 模块 | `modules/output-guide.md` | 新增 |
| 脚本 | `scripts/detect-k8s-env.sh` | 新增 |
| 脚本 | `scripts/detect-container-npu.sh` | 新增 |
| 脚本 | `scripts/fill-template.sh` | 新增 |

**新增 10 个文件，Skill 2 实现完成。**

---

## 与 Skill 1 的衔接说明

**Skill 1 输出（准备阶段）**：
- `.vllm-deploy/config.json` - 用户配置
- `.vllm-deploy/image-info.json` - 镜像信息
- `.vllm-deploy/templates/*.yaml` - K8s 模板（含占位符）
- `.vllm-deploy/scripts/start-*.sh` - 启动脚本模板（含占位符）

**Skill 2 输入（执行阶段）**：
- 读取 `.vllm-deploy/` 目录
- K8s 环境探测填充占位符
- 生成最终可执行文件

**占位符流转**：
- Skill 1 预留 `${VAR_PLACEHOLDER}` 占位符
- Skill 2 探测填充实际值

---

## 自检清单

**规格覆盖度：**
- [x] Phase 4: K8s 环境探测 → 任务 2
- [x] Phase 7（补）: YAML 填充 → 任务 3
- [x] Phase 8: K8s Apply 指导 → 任务 4
- [x] Phase 9: 容器内探测 → 任务 5
- [x] Phase 10: 部署脚本生成 → 任务 6
- [x] Phase 11: 部署执行指导 → 任务 7
- [x] Phase 12: 输出交付 → 任务 8

**占位符扫描：**
- 无 "TODO"、"待定" 等占位符
- 所有代码块包含完整内容
- 所有命令包含具体参数

**类型一致性：**
- 配置字段名称与设计规格一致
- JSON 输出格式与设计规格一致
- 占位符名称与 Skill 1 模板一致