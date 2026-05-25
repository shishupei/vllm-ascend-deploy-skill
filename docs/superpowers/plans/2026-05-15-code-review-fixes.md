# vLLM-Deploy Skill 代码审查问题修复计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复代码审查发现的 8 个 Critical/Important 问题，使 YAML 生成链路真正落地、JSON 协议稳定、容器内脚本可分发。

**架构：** 按优先级修复：先修 JSON 契约和 fill-template.sh 模式覆盖，再补 Pod 内脚本分发机制，最后处理多节点 Ray 启动和文档解析优化。

**技术栈：** Bash 脚本、jq JSON 处理、K8s YAML、sed 占位符替换

---

## 问题清单（按优先级）

| # | 严重度 | 问题 | 文件 |
|---|--------|------|------|
| 1 | Critical | JSON 输出不稳定（日志混入、非法 JSON） | 多个脚本 |
| 2 | Critical | detect-k8s-env.sh 多节点 JSON 拼坏 | detect-k8s-env.sh |
| 3 | Critical | fill-template.sh 模式覆盖不全 | fill-template.sh |
| 4 | Critical | 容器内 NPU 探测只扫 0-7 卡 | detect-container-npu.sh |
| 5 | Critical | Phase 9/11 脚本无法进入 Pod | YAML 模板 |
| 6 | Important | Phase 3 文档解析未真正针对性 | parse-model-doc.sh |
| 7 | Important | 节点确认流程未接入生成链路 | fill-template.sh |
| 8 | Important | Ray 分布式未真正引导启动 | 启动脚本 |

---

## 文件结构

本次修复涉及的文件：

| 文件 | 职责 | 修改类型 |
|------|------|----------|
| `vllm-deploy-prepare/scripts/fetch-model-list.sh` | 模型列表抓取 | 修改：JSON 输出纯净 |
| `vllm-deploy-prepare/scripts/parse-model-doc.sh` | 文档解析 | 修改：JSON 输出纯净、针对性解析 |
| `vllm-deploy-prepare/scripts/fetch-k8s-config.sh` | K8s 配置获取 | 修改：JSON 输出纯净 |
| `vllm-deploy-execute/scripts/detect-k8s-env.sh` | K8s 环境探测 | 修改：JSON 输出纯净、节点列表拼接修复 |
| `vllm-deploy-execute/scripts/detect-container-npu.sh` | 容器内 NPU 探测 | 修改：JSON 输出纯净、扩展扫描范围 |
| `vllm-deploy-execute/scripts/fill-template.sh` | YAML 生成 | 修改：覆盖所有模式、正确填充占位符 |
| `vllm-deploy-prepare/templates/single-node.yaml` | 单节点模板 | 修改：添加脚本 ConfigMap 挂载 |
| `vllm-deploy-prepare/templates/multi-node.yaml` | 多节点模板 | 修改：添加脚本 ConfigMap、Ray 引导 |
| `vllm-deploy-prepare/templates/pd-separate.yaml` | PD 分离模板 | 修改：添加脚本 ConfigMap 挂载 |
| `vllm-deploy-prepare/templates/ha-active-standby.yaml` | HA 模板 | 修改：添加脚本 ConfigMap 挂载 |

---

## 任务 1：修复 JSON 输出协议（所有脚本）

**目标：** 所有脚本输出纯净 JSON，日志信息重定向到 stderr

**文件：**
- 修改：`vllm-deploy-prepare/scripts/fetch-model-list.sh`
- 修改：`vllm-deploy-prepare/scripts/parse-model-doc.sh`
- 修改：`vllm-deploy-prepare/scripts/fetch-k8s-config.sh`
- 修改：`vllm-deploy-execute/scripts/detect-k8s-env.sh`
- 修改：`vllm-deploy-execute/scripts/detect-container-npu.sh`

### 步骤 1.1：修复 fetch-model-list.sh JSON 输出

- [ ] 将日志输出重定向到 stderr

**修改前（第 9 行）：**
```bash
echo "Fetching model list from: $URL"
```

**修改后：**
```bash
echo "Fetching model list from: $URL" >&2
```

- [ ] 确保所有 JSON 输出到 stdout，日志到 stderr

**完整修改版：**
```bash
#!/bin/bash
# Phase 1: 获取 vLLM-Ascend 支持的模型列表

set -e

DEFAULT_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html"
URL="${1:-$DEFAULT_URL}"

# 所有日志输出到 stderr
echo "Fetching model list from: $URL" >&2

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    # 错误信息到 stderr，JSON 到 stdout
    echo '{"error": "Failed to fetch page"}' >&2
    exit 1
fi

# 提取模型链接
MODELS=$(echo "$HTML" | grep 'class="reference internal" href=".*\.html"' | sed -n 's/.*href="\([A-Za-z0-9_.-]*\)\.html".*/\1.html/p' | grep -v "index.html" | grep -v "supported_models" | sort -u)

# 构建 JSON 输出（仅 stdout）
if command -v jq &> /dev/null; then
    echo "$MODELS" | jq -R -s 'split("\n") | map(select(length > 0)) | map({name: . | sub(".html$"; ""), url: .}) | {models: .}'
else
    # 手动构建 JSON（纯 stdout）
    FIRST=true
    printf '{"models": ['
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            NAME=$(basename "$url" .html)
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                printf ','
            fi
            printf '{"name": "%s", "url": "%s"}' "$NAME" "$url"
        fi
    done <<< "$MODELS"
    printf ']}'
fi
```

- [ ] Commit

```bash
git add vllm-deploy-prepare/scripts/fetch-model-list.sh
git commit -m "fix(skill-prepare): redirect logs to stderr in fetch-model-list.sh for clean JSON output"
```

### 步骤 1.2：修复 parse-model-doc.sh JSON 输出

- [ ] 将日志输出重定向到 stderr

**修改位置：第 25-27 行**

**修改前：**
```bash
echo "Parsing: $URL"
echo "HW Spec: $HW_SPEC"
echo "Deploy Mode: $DEPLOY_MODE"
```

**修改后：**
```bash
echo "Parsing: $URL" >&2
echo "HW Spec: $HW_SPEC" >&2
echo "Deploy Mode: $DEPLOY_MODE" >&2
```

- [ ] Commit

```bash
git add vllm-deploy-prepare/scripts/parse-model-doc.sh
git commit -m "fix(skill-prepare): redirect logs to stderr in parse-model-doc.sh for clean JSON output"
```

### 步骤 1.3：修复 fetch-k8s-config.sh JSON 输出和 kv_config 处理

- [ ] 将日志重定向到 stderr（第 9 行）

**修改前：**
```bash
echo "Fetching K8s deployment config from: $URL"
```

**修改后：**
```bash
echo "Fetching K8s deployment config from: $URL" >&2
```

- [ ] 修复 kv_config 为合法 JSON 值（第 36、72 行）

**修改前（第 36 行）：**
```bash
KV_CONFIG=$(echo "$HTML" | grep -o '"kv_connector":"[^"]*"' | head -1)
```

**问题：** 如果匹配不到，KV_CONFIG 为空，导致 `"kv_config": ` 后面没有值，形成非法 JSON。

**修改后：**
```bash
KV_CONFIG=$(echo "$HTML" | grep -o '"kv_connector":"[^"]*"' | head -1)
if [ -z "$KV_CONFIG" ]; then
    KV_CONFIG='null'
else
    # 保持原格式，已包含引号
    KV_CONFIG="$KV_CONFIG"
fi
```

**修改第 72 行输出：**
```bash
  "kv_config": $KV_CONFIG
```

- [ ] Commit

```bash
git add vllm-deploy-prepare/scripts/fetch-k8s-config.sh
git commit -m "fix(skill-prepare): redirect logs to stderr and handle missing kv_config gracefully"
```

### 步骤 1.4：修复 detect-k8s-env.sh JSON 输出和节点列表拼接

- [ ] 将日志重定向到 stderr（第 7、45、111 行）

**修改位置：**
```bash
# 第 7 行
echo "=== K8s Environment Detection ===" >&2

# 第 45 行
echo "Cluster connected successfully!" >&2

# 第 111 行
echo "" >&2
echo "Detection completed. Total available NPU: $TOTAL_NPU" >&2
```

- [ ] **Critical：修复节点 JSON 拼接逻辑（第 87-92 行）**

**问题分析：** `NODE_LIST="${NODE_LIST%,*}, $NODE_JSON]"` 会截掉前一个对象内部最后一个逗号之后的内容，导致 JSON 拼坏。

**修复方案：** 使用 jq 或数组方式正确拼接。

**修改后（使用 jq 方式）：**
```bash
#!/bin/bash
# K8s 环境探测脚本
# 检测 kubectl 可用性、集群连接、节点 NPU 信息

set -e

echo "=== K8s Environment Detection ===" >&2

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

echo "Cluster connected successfully!" >&2

# 获取所有节点
NODES=$(kubectl get nodes -o json)

# 支持的 NPU 资源类型
NPU_RESOURCE_TYPES="huawei.com/Ascend910 huawei.com/NPU huawei.com/Ascend310P huawei.com/Ascend910B"

# 使用临时文件收集节点 JSON，然后用 jq 合并
TEMP_NODES_FILE=$(mktemp)

for node_name in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    # 获取节点 IP
    NODE_IP=$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

    # 检测 NPU 资源
    NPU_TYPE=""
    NPU_COUNT=0

    for npu_type in $NPU_RESOURCE_TYPES; do
        count=$(kubectl get node "$node_name" -o json | jq -r ".status.allocatable.\"$npu_type\"" 2>/dev/null || echo "0")
        if [ "$count" != "null" ] && [ "$count" != "0" ] && [ -n "$count" ]; then
            NPU_TYPE="$npu_type"
            NPU_COUNT="$count"
            break
        fi
    done

    # 输出单个节点 JSON 到临时文件
    jq -n \
        --arg name "$node_name" \
        --arg ip "$NODE_IP" \
        --arg npu_type "$NPU_TYPE" \
        --argjson npu_count "$NPU_COUNT" \
        '{
            name: $name,
            ip: $ip,
            npu_type: $npu_type,
            npu_count: $npu_count,
            npu_available: $npu_count,
            labels: {}
        }' >> "$TEMP_NODES_FILE"
done

# 使用 jq 合并所有节点为数组
NODE_LIST=$(jq -s '.' "$TEMP_NODES_FILE")
rm "$TEMP_NODES_FILE"

# 推荐节点（按 NPU 数量排序）
RECOMMENDED=$(echo "$NODE_LIST" | jq -r '[.[] | select(.npu_count > 0)] | sort_by(-.npu_count) | .[].name' 2>/dev/null || echo "")

# 计算总 NPU 数量
TOTAL_NPU=$(echo "$NODE_LIST" | jq '[.[].npu_count] | add' 2>/dev/null || echo "0")

# 输出结果（仅 stdout）
cat <<EOF
{
  "cluster_connected": true,
  "nodes": $NODE_LIST,
  "recommended_nodes": $(echo "$RECOMMENDED" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]"),
  "total_npu_available": $TOTAL_NPU
}
EOF

echo "" >&2
echo "Detection completed. Total available NPU: $TOTAL_NPU" >&2
```

- [ ] Commit

```bash
git add vllm-deploy-execute/scripts/detect-k8s-env.sh
git commit -m "fix(skill-execute): redirect logs to stderr and fix node JSON array concatenation in detect-k8s-env.sh"
```

### 步骤 1.5：修复 detect-container-npu.sh JSON 输出

- [ ] 将日志重定向到 stderr（第 7、27-29、35-37、49-50 行）

**修改位置：**
```bash
# 第 7 行
echo "=== Container NPU Detection ===" >&2

# 第 27-29 行
echo "NPU Devices found:" >&2
echo "$NPU_DEVICES" >&2
echo "NPU Count: $NPU_COUNT" >&2

# 第 35-37 行
if command -v npu-smi &> /dev/null; then
    NPU_SMI_AVAILABLE=true
    echo "" >&2
    echo "=== NPU-SMI Info ===" >&2
    npu-smi info 2>/dev/null >&2 || echo "npu-smi info failed" >&2
fi

# 第 49-50 行
echo "" >&2
echo "=== Detection Complete ===" >&2
```

- [ ] Commit

```bash
git add vllm-deploy-execute/scripts/detect-container-npu.sh
git commit -m "fix(skill-execute): redirect logs to stderr in detect-container-npu.sh for clean JSON output"
```

---

## 任务 2：修复容器内 NPU 探测扫描范围

**目标：** 支持扫描 0-15 卡（覆盖 A3 16 卡环境）

**文件：**
- 修改：`vllm-deploy-execute/scripts/detect-container-npu.sh:11-14`

### 步骤 2.1：扩展扫描范围

- [ ] 修改扫描循环范围

**修改前（第 11-14 行）：**
```bash
NPU_DEVICES=""
for i in 0 1 2 3 4 5 6 7; do
    if [ -e "/dev/davinci$i" ]; then
        NPU_DEVICES="$NPU_DEVICES /dev/davinci$i"
    fi
done
```

**修改后：**
```bash
NPU_DEVICES=""
# 支持扫描 0-15，覆盖 A3 16 卡环境
for i in $(seq 0 15); do
    if [ -e "/dev/davinci$i" ]; then
        NPU_DEVICES="$NPU_DEVICES /dev/davinci$i"
    fi
done
```

- [ ] Commit

```bash
git add vllm-deploy-execute/scripts/detect-container-npu.sh
git commit -m "fix(skill-execute): extend NPU device scan range to 0-15 for A3 16-card support"
```

---

## 任务 3：修复 fill-template.sh 模式覆盖和占位符填充

**目标：** 实现所有 4 种部署模式的 YAML 生成，正确填充各模式所需的占位符

**文件：**
- 修改：`vllm-deploy-execute/scripts/fill-template.sh`

### 步骤 3.1：实现 pd_separate 模式

- [ ] 在 case 分支中添加 pd_separate 处理（第 83-106 行之后）

**添加代码：**
```bash
    pd_separate)
        PREFILL_TP_SIZE=$(jq -r '.prefill_tp_size // 8' "$CONFIG_FILE")
        DECODE_TP_SIZE=$(jq -r '.decode_tp_size // 8' "$CONFIG_FILE")
        PREFILL_NPU_COUNT=$(jq -r '.prefill_npu_count // 8' "$CONFIG_FILE")
        DECODE_NPU_COUNT=$(jq -r '.decode_npu_count // 8' "$CONFIG_FILE")
        PREFILL_REPLICAS=$(jq -r '.prefill_replicas // 1' "$CONFIG_FILE")
        DECODE_REPLICAS=$(jq -r '.decode_replicas // 1' "$CONFIG_FILE")
        KV_CONNECTOR=$(jq -r '.kv_connector // "MooncakeConnectorV1"' "$CONFIG_FILE")
        DECODE_MAX_BATCHED_TOKENS=$(jq -r '.decode_max_batched_tokens // 16384' "$CONFIG_FILE")
        
        fill_template "$TEMPLATE_DIR/pd-separate.yaml" "$OUTPUT_DIR/all.yaml" \
            "-e s|\${PREFILL_TP_SIZE}|${PREFILL_TP_SIZE}|g \
             -e s|\${DECODE_TP_SIZE}|${DECODE_TP_SIZE}|g \
             -e s|\${PREFILL_NPU_COUNT}|${PREFILL_NPU_COUNT}|g \
             -e s|\${DECODE_NPU_COUNT}|${DECODE_NPU_COUNT}|g \
             -e s|\${PREFILL_REPLICAS}|${PREFILL_REPLICAS}|g \
             -e s|\${DECODE_REPLICAS}|${DECODE_REPLICAS}|g \
             -e s|\${KV_CONNECTOR}|${KV_CONNECTOR}|g \
             -e s|\${DECODE_MAX_BATCHED_TOKENS}|${DECODE_MAX_BATCHED_TOKENS}|g"
        ;;
```

### 步骤 3.2：实现 ha_active_standby 模式

- [ ] 在 case 分支中添加 ha_active_standby 处理

**添加代码：**
```bash
    ha_active_standby)
        HA_REPLICAS=$(jq -r '.ha_replicas // 2' "$CONFIG_FILE")
        HA_MIN_REPLICAS=$(jq -r '.ha_min_replicas // 1' "$CONFIG_FILE")
        HA_MAX_REPLICAS=$(jq -r '.ha_max_replicas // 4' "$CONFIG_FILE")
        NPU_NODE_LABEL=$(jq -r '.npu_node_label // "npu.ascend.com/Ascend910"' "$CONFIG_FILE")
        SELECTED_NODE=$(jq -r '.selected_nodes[0] // .recommended_nodes[0]' "$DETECTION_FILE")
        NPU_COUNT=$(jq -r '.nodes[] | select(.name=="'$SELECTED_NODE'") | .npu_count // 8' "$DETECTION_FILE")
        
        fill_template "$TEMPLATE_DIR/ha-active-standby.yaml" "$OUTPUT_DIR/all.yaml" \
            "-e s|\${HA_REPLICAS}|${HA_REPLICAS}|g \
             -e s|\${HA_MIN_REPLICAS}|${HA_MIN_REPLICAS}|g \
             -e s|\${HA_MAX_REPLICAS}|${HA_MAX_REPLICAS}|g \
             -e s|\${NPU_NODE_LABEL}|${NPU_NODE_LABEL}|g \
             -e s|\${NPU_COUNT}|${NPU_COUNT}|g"
        ;;
```

### 步骤 3.3：完善 multi_node 模式（按节点生成独立清单）

- [ ] 修改 multi_node 分支，为每个 worker 生成独立 YAML

**修改后：**
```bash
    multi_node)
        WORLD_SIZE=$(jq -r '.nodes | length' "$DETECTION_FILE")
        MASTER_NODE_IP=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .ip' "$DETECTION_FILE")
        NPU_COUNT_PER_NODE=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .npu_count // 8' "$DETECTION_FILE")
        
        # 生成 master YAML
        fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/master.yaml" \
            "-e s|\${MASTER_NODE_NAME}|${SELECTED_MASTER}|g \
             -e s|\${MASTER_NODE_IP}|${MASTER_NODE_IP}|g \
             -e s|\${WORLD_SIZE}|${WORLD_SIZE}|g \
             -e s|\${NPU_COUNT_PER_NODE}|${NPU_COUNT_PER_NODE}|g \
             -e s|\${WORKER_RANK}|0|g \
             -e s|\${WORKER_NODE_NAME}|${SELECTED_MASTER}|g \
             -e s|\${WORKER_NODE_IP}|${MASTER_NODE_IP}|g"
        
        # 为每个 worker 生成独立 YAML
        WORKER_INDEX=1
        for worker_node in $(jq -r '.recommended_nodes[1:][]' "$DETECTION_FILE"); do
            WORKER_IP=$(jq -r '.nodes[] | select(.name=="'$worker_node'") | .ip' "$DETECTION_FILE")
            fill_template "$TEMPLATE_DIR/multi-node.yaml" "$OUTPUT_DIR/worker-${WORKER_INDEX}.yaml" \
                "-e s|\${MASTER_NODE_NAME}|${SELECTED_MASTER}|g \
                 -e s|\${MASTER_NODE_IP}|${MASTER_NODE_IP}|g \
                 -e s|\${WORLD_SIZE}|${WORLD_SIZE}|g \
                 -e s|\${NPU_COUNT_PER_NODE}|${NPU_COUNT_PER_NODE}|g \
                 -e s|\${WORKER_RANK}|${WORKER_INDEX}|g \
                 -e s|\${WORKER_NODE_NAME}|${worker_node}|g \
                 -e s|\${WORKER_NODE_IP}|${WORKER_IP}|g"
            WORKER_INDEX=$((WORKER_INDEX + 1))
        done
        
        # 合并所有 YAML
        cat "$OUTPUT_DIR/master.yaml" "$OUTPUT_DIR"/worker-*.yaml > "$OUTPUT_DIR/all.yaml"
        ;;
```

### 步骤 3.4：移除 warning 分支，改为完整实现

- [ ] 删除原有的 warning 分支（第 103-106 行）

**删除：**
```bash
    *)
        echo "Warning: deploy_mode '$DEPLOY_MODE' may need additional configuration"
        ;;
```

**替换为：**
```bash
    *)
        echo "Error: Unknown deploy_mode '$DEPLOY_MODE'" >&2
        echo "Supported modes: single_node, multi_node, pd_separate, ha_active_standby" >&2
        exit 1
        ;;
```

- [ ] Commit

```bash
git add vllm-deploy-execute/scripts/fill-template.sh
git commit -m "fix(skill-execute): implement all 4 deploy modes in fill-template.sh with proper placeholder filling"
```

---

## 任务 4：添加 Pod 内脚本分发机制

**目标：** 让 detect-container-npu.sh 和 deploy.sh 能在 Pod 内执行

**文件：**
- 修改：`vllm-deploy-prepare/templates/single-node.yaml`
- 修改：`vllm-deploy-prepare/templates/multi-node.yaml`
- 修改：`vllm-deploy-prepare/templates/pd-separate.yaml`
- 修改：`vllm-deploy-prepare/templates/ha-active-standby.yaml`
- 修改：`vllm-deploy-execute/scripts/fill-template.sh`

### 步骤 4.1：为所有模板添加 ConfigMap 挂载结构

- [ ] 在 single-node.yaml 添加脚本 ConfigMap 定义

**在 Namespace 定义后添加（约第 13 行之后）：**
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vllm-scripts
  namespace: ${NAMESPACE}
data:
  detect-container-npu.sh: |
#!/bin/bash
    # 容器内 NPU 环境探测脚本
    set -e
    echo "=== Container NPU Detection ===" >&2
    NPU_DEVICES=""
    for i in $(seq 0 15); do
      if [ -e "/dev/davinci$i" ]; then
        NPU_DEVICES="$NPU_DEVICES /dev/davinci$i"
      fi
    done
    NPU_COUNT=$(echo "$NPU_DEVICES" | wc -w)
    echo "NPU Count: $NPU_COUNT" >&2
    cat <<EOF
{
  "pod_name": "${HOSTNAME:-unknown}",
  "npu_count": $NPU_COUNT
}
EOF
  deploy.sh: |
#!/bin/bash
    # vLLM 启动脚本
    set -e
    vllm serve ${MODEL_PATH} \
      --served-model-name ${MODEL_NAME} \
      --tensor-parallel-size ${TENSOR_PARALLEL_SIZE} \
      --max-model-len ${MAX_MODEL_LEN} \
      --max-num-seqs ${MAX_NUM_SEQS} \
      --port 8000 \
      --trust-remote-code
```

- [ ] 在 Deployment 的 volumeMounts 添加脚本挂载（约第 101 行之后）

**添加 volumes 定义：**
```yaml
      volumes:
      - name: vllm-scripts
        configMap:
          name: vllm-scripts
          defaultMode: 0755
```

**添加 volumeMounts：**
```yaml
        volumeMounts:
        - name: vllm-scripts
          mountPath: /scripts
          readOnly: true
```

- [ ] Commit single-node.yaml

```bash
git add vllm-deploy-prepare/templates/single-node.yaml
git commit -m "fix(skill-prepare): add ConfigMap for scripts mounting in single-node.yaml"
```

### 步骤 4.2：为 multi-node.yaml 添加脚本 ConfigMap

- [ ] 添加与 single-node.yaml 相同的 ConfigMap 结构

**添加位置：Namespace 定义后**

- [ ] 添加 Ray 集群引导命令（Critical：多节点 Ray 启动）

**修改 Deployment command 部分，添加 Ray 引导：**

```yaml
        command:
        - /bin/bash
        - -c
        - |
          # Ray 集群引导
          if [ "${RANK}" == "0" ]; then
            ray start --head --port=${MASTER_PORT}
          else
            ray start --address=${MASTER_NODE_IP}:${MASTER_PORT}
          fi
          # 启动 vLLM
          /scripts/deploy.sh
```

- [ ] Commit multi-node.yaml

```bash
git add vllm-deploy-prepare/templates/multi-node.yaml
git commit -m "fix(skill-prepare): add ConfigMap and Ray cluster bootstrap in multi-node.yaml"
```

### 步骤 4.3：为 pd-separate.yaml 和 ha-active-standby.yaml 添加脚本 ConfigMap

- [ ] 同样添加 ConfigMap 定义和 volumeMounts

- [ ] Commit

```bash
git add vllm-deploy-prepare/templates/pd-separate.yaml vllm-deploy-prepare/templates/ha-active-standby.yaml
git commit -m "fix(skill-prepare): add ConfigMap for scripts mounting in pd-separate.yaml and ha-active-standby.yaml"
```

### 步骤 4.4：更新 fill-template.sh 生成脚本 ConfigMap

- [ ] 在 fill-template.sh 输出部分添加脚本 ConfigMap YAML 生成

**添加位置：生成 apply-all.sh 之前（约第 107 行）**

```bash
# 生成脚本 ConfigMap YAML（包含 detect-container-npu.sh 和 deploy.sh）
cat <<EOF > "$OUTPUT_DIR/scripts-configmap.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: vllm-scripts
  namespace: ${NAMESPACE}
data:
  detect-container-npu.sh: |
#!/bin/bash
    set -e
    echo "=== Container NPU Detection ===" >&2
    NPU_DEVICES=""
    for i in $(seq 0 15); do
      if [ -e "/dev/davinci\$i" ]; then
        NPU_DEVICES="\$NPU_DEVICES /dev/davinci\$i"
      fi
    done
    NPU_COUNT=\$(echo "\$NPU_DEVICES" | wc -w)
    echo "NPU Count: \$NPU_COUNT" >&2
    printf '{"pod_name": "%s", "npu_count": %d}\n' "\${HOSTNAME:-unknown}" "\$NPU_COUNT"
  deploy.sh: |
#!/bin/bash
    set -e
    vllm serve ${MODEL_PATH} \
      --served-model-name ${MODEL_NAME} \
      --tensor-parallel-size ${TENSOR_PARALLEL_SIZE} \
      --max-model-len ${MAX_MODEL_LEN} \
      --max-num-seqs ${MAX_NUM_SEQS} \
      --port 8000 \
      --trust-remote-code
EOF

echo "Generated: $OUTPUT_DIR/scripts-configmap.yaml"
```

- [ ] Commit

```bash
git add vllm-deploy-execute/scripts/fill-template.sh
git commit -m "fix(skill-execute): generate scripts ConfigMap for Pod execution in fill-template.sh"
```

---

## 任务 5：改进 Phase 3 文档解析针对性

**目标：** 根据用户选择的 HW_SPEC 和 DEPLOY_MODE 只解析对应部分

**文件：**
- 修改：`vllm-deploy-prepare/scripts/parse-model-doc.sh`

### 步骤 5.1：实现针对性文档解析

- [ ] 添加 HW_SPEC 和 DEPLOY_MODE 过滤逻辑

**修改 parse-model-doc.sh（第 25-52 行）：**

```bash
#!/bin/bash
# Phase 3: 解析模型文档，提取启动脚本和镜像版本
# 根据用户选择的 HW_SPEC 和 DEPLOY_MODE 进行针对性解析

set -e

usage() {
    echo "Usage: $0 --url <URL> --hw-spec <A3|A2> --deploy-mode <single_node|multi_node|pd_separate>" >&2
    exit 1
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --url) URL="$2"; shift 2 ;;
        --hw-spec) HW_SPEC="$2"; shift 2 ;;
        --deploy-mode) DEPLOY_MODE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$URL" ] || [ -z "$HW_SPEC" ] || [ -z "$DEPLOY_MODE" ]; then
    usage
fi

echo "Parsing: $URL" >&2
echo "HW Spec: $HW_SPEC" >&2
echo "Deploy Mode: $DEPLOY_MODE" >&2

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}' >&2
    exit 1
fi

# 根据部署模式确定搜索关键词
case "$DEPLOY_MODE" in
    single_node)
        SEARCH_PATTERN="single.*node|单机|standalone"
        ;;
    multi_node)
        SEARCH_PATTERN="multi.*node|分布式|distributed|Ray"
        ;;
    pd_separate)
        SEARCH_PATTERN="PD.*分离|prefill.*decode|kv.*transfer|Mooncake"
        ;;
    *)
        SEARCH_PATTERN=""
        ;;
esAC

# 根据硬件规格确定 NPU 数量提示
case "$HW_SPEC" in
    A3)
        NPU_COUNT_HINT="16"
        ;;
    A2)
        NPU_COUNT_HINT="8"
        ;;
    *)
        NPU_COUNT_HINT=""
        ;;
esac

# 针对性提取镜像版本（优先匹配用户选择的部署模式区域）
# 策略：先定位部署模式章节，再在其中查找镜像版本
if [ -n "$SEARCH_PATTERN" ]; then
    # 提取匹配部署模式的章节内容
    SECTION_CONTENT=$(echo "$HTML" | grep -iA 50 "$SEARCH_PATTERN" | head -100)
    
    # 在该章节中提取镜像版本
    IMAGE_VERSION=$(echo "$SECTION_CONTENT" | grep -o 'vllm-ascend:v[0-9.]*' | head -1 | sed 's/vllm-ascend://')
else
    # 回退到全局搜索
    IMAGE_VERSION=$(echo "$HTML" | grep -o 'vllm-ascend:v[0-9.]*' | head -1 | sed 's/vllm-ascend://')
fi

if [ -z "$IMAGE_VERSION" ]; then
    IMAGE_VERSION="unknown"
fi

SOURCE_IMAGE="quay.io/vllm-ascend/vllm-ascend:$IMAGE_VERSION"

# 针对性提取参数（在匹配章节中查找）
if [ -n "$SEARCH_PATTERN" ]; then
    MAX_MODEL_LEN=$(echo "$SECTION_CONTENT" | grep -o 'max-model-len[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")
    TENSOR_PARALLEL=$(echo "$SECTION_CONTENT" | grep -o 'tensor-parallel-size[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")
else
    MAX_MODEL_LEN=$(echo "$HTML" | grep -o 'max-model-len[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")
    TENSOR_PARALLEL=$(echo "$HTML" | grep -o 'tensor-parallel-size[[:space:]]*[=:][[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1 || echo "")
fi

# 输出 JSON（使用 jq）
if command -v jq &> /dev/null; then
    jq -n \
        --arg img_ver "$IMAGE_VERSION" \
        --arg src_img "$SOURCE_IMAGE" \
        --arg hw "$HW_SPEC" \
        --arg mode "$DEPLOY_MODE" \
        --arg max_len "$MAX_MODEL_LEN" \
        --arg tp "$TENSOR_PARALLEL" \
        '{
            image_version: $img_ver,
            source_image: $src_img,
            hw_spec: $hw,
            deploy_mode: $mode,
            extracted_params: {
                max_model_len: (if $max_len == "" then null else ($max_len | tonumber) end),
                tensor_parallel_size: (if $tp == "" then null else ($tp | tonumber) end)
            }
        }'
else
    printf '{\n'
    printf '  "image_version": "%s",\n' "$IMAGE_VERSION"
    printf '  "source_image": "%s",\n' "$SOURCE_IMAGE"
    printf '  "hw_spec": "%s",\n' "$HW_SPEC"
    printf '  "deploy_mode": "%s",\n' "$DEPLOY_MODE"
    printf '  "extracted_params": {\n'
    if [ -n "$MAX_MODEL_LEN" ]; then
        printf '    "max_model_len": %s,\n' "$MAX_MODEL_LEN"
    else
        printf '    "max_model_len": null,\n'
    fi
    if [ -n "$TENSOR_PARALLEL" ]; then
        printf '    "tensor_parallel_size": %s\n' "$TENSOR_PARALLEL"
    else
        printf '    "tensor_parallel_size": null\n'
    fi
    printf '  }\n'
    printf '}\n'
fi
```

- [ ] Commit

```bash
git add vllm-deploy-prepare/scripts/parse-model-doc.sh
git commit -m "fix(skill-prepare): implement targeted document parsing based on HW_SPEC and DEPLOY_MODE"
```

---

## 任务 6：节点确认流程接入生成链路

**目标：** 将用户确认的节点选择持久化并传入 fill-template.sh

**文件：**
- 修改：`vllm-deploy-execute/scripts/fill-template.sh`
- 新增：节点确认输入处理

### 步骤 6.1：修改 fill-template.sh 支持多节点选择输入

- [ ] 添加节点配置文件输入参数

**修改参数检查部分（第 7-22 行）：**
```bash
# 参数检查
CONFIG_FILE="${1:-.vllm-deploy/config.json}"
DETECTION_FILE="${2:-.vllm-deploy/detection-result.json}"
NODES_FILE="${3:-.vllm-deploy/selected-nodes.json}"  # 新增：用户确认的节点选择
OUTPUT_DIR="${4:-.vllm-deploy/k8s}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found at $CONFIG_FILE" >&2
    echo "Please run /vllm-deploy-prepare first" >&2
    exit 1
fi

if [ ! -f "$DETECTION_FILE" ]; then
    echo "Error: detection-result.json not found at $DETECTION_FILE" >&2
    echo "Please run K8s environment detection first" >&2
    exit 1
fi

# 如果没有节点选择文件，使用探测结果中的推荐节点
if [ ! -f "$NODES_FILE" ]; then
    echo "Warning: selected-nodes.json not found, using recommended_nodes from detection" >&2
    SELECTED_MASTER=$(jq -r '.recommended_nodes[0]' "$DETECTION_FILE")
else
    SELECTED_MASTER=$(jq -r '.master_node // .nodes[0]' "$NODES_FILE")
fi
```

### 步骤 6.2：读取多节点选择配置

- [ ] 在 multi_node 分支读取 worker 节点列表

**修改 multi_node 分支（约第 91-101 行）：**
```bash
    multi_node)
        # 读取节点选择配置
        if [ -f "$NODES_FILE" ]; then
            WORLD_SIZE=$(jq -r '.nodes | length' "$NODES_FILE")
            MASTER_NODE_IP=$(jq -r '.nodes[0].ip // .nodes[0]' "$NODES_FILE")
            WORKER_NODES=$(jq -r '.nodes[1:] | @json' "$NODES_FILE")
        else
            WORLD_SIZE=$(jq -r '.nodes | length' "$DETECTION_FILE")
            MASTER_NODE_IP=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .ip' "$DETECTION_FILE")
            WORKER_NODES=$(jq -r '.recommended_nodes[1:] | @json' "$DETECTION_FILE")
        fi
        
        # ... 后续生成逻辑
```

- [ ] Commit

```bash
git add vllm-deploy-execute/scripts/fill-template.sh
git commit -m "fix(skill-execute): integrate node confirmation workflow into fill-template.sh"
```

---

## 任务 7：修复多节点 Ray 分布式启动

**目标：** 确保 Ray 集群正确引导，Master 和 Worker 能连接

**文件：**
- 修改：`vllm-deploy-prepare/scripts/start-multi-node-master.sh`
- 修改：`vllm-deploy-prepare/scripts/start-multi-node-worker.sh`

### 步骤 7.1：添加 Ray 集群引导到 Master 启动脚本

- [ ] 在 start-multi-node-master.sh 添加 Ray head 启动

**修改（第 41-49 行）：**
```bash
# ============ Ray 集群引导（Master 作为 Head）============
echo "Starting Ray cluster as Head node..." >&2
ray start --head --port=${MASTER_PORT} --node-ip-address=${HCCL_IF_IP}

# 等待 Ray 集群稳定
sleep 5

# ============ 启动 vLLM ============
echo "Starting vLLM serve as Master (Rank ${RANK})..." >&2
echo "Model: ${MODEL_PATH}" >&2
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}" >&2
echo "World Size: ${WORLD_SIZE}" >&2
echo "Master Addr: ${MASTER_ADDR}" >&2
echo "Master Port: ${MASTER_PORT}" >&2

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --distributed-executor-backend ray \
    --port 8000 \
    --trust-remote-code

echo "vLLM Master service started" >&2
```

### 步骤 7.2：添加 Ray Worker 连接到 Worker 启动脚本

- [ ] 在 start-multi-node-worker.sh 添加 Ray worker 连接

**修改（第 41-49 行）：**
```bash
# ============ Ray Worker 连接到 Head ============
echo "Connecting to Ray cluster at ${MASTER_ADDR}:${MASTER_PORT}..." >&2
ray start --address=${MASTER_ADDR}:${MASTER_PORT} --node-ip-address=${HCCL_IF_IP}

# 等待连接稳定
sleep 3

# ============ 启动 vLLM Worker ============
echo "Starting vLLM serve as Worker (Rank ${RANK})..." >&2
echo "Model: ${MODEL_PATH}" >&2
echo "Tensor Parallel Size: ${TENSOR_PARALLEL_SIZE}" >&2
echo "World Size: ${WORLD_SIZE}" >&2
echo "Master Addr: ${MASTER_ADDR}" >&2
echo "Connecting to Master..." >&2

vllm serve "${MODEL_PATH}" \
    --served-model-name "${MODEL_NAME:-default}" \
    --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --distributed-executor-backend ray \
    --port 8000 \
    --trust-remote-code

echo "vLLM Worker service started (Rank ${RANK})" >&2
```

- [ ] Commit

```bash
git add vllm-deploy-prepare/scripts/start-multi-node-master.sh vllm-deploy-prepare/scripts/start-multi-node-worker.sh
git commit -m "fix(skill-prepare): add Ray cluster bootstrap steps to multi-node startup scripts"
```

---

## 任务 8：最终验证和测试

**目标：** 确保所有修复正确工作

### 步骤 8.1：验证 JSON 输出纯净

- [ ] 运行脚本检查 JSON 输出

```bash
# 测试 fetch-model-list.sh
cd vllm-deploy-prepare/scripts
./fetch-model-list.sh > output.json 2> log.txt
jq . output.json  # 应成功解析
cat log.txt       # 应包含日志，无 JSON

# 测试 detect-k8s-env.sh（需要 K8s 环境）
cd vllm-deploy-execute/scripts
./detect-k8s-env.sh > output.json 2> log.txt
jq . output.json  # 应成功解析，nodes 数组格式正确

# 测试 detect-container-npu.sh（需要在容器内）
./detect-container-npu.sh > output.json 2> log.txt
jq . output.json  # 应成功解析
```

### 步骤 8.2：验证 fill-template.sh 所有模式

- [ ] 创建测试配置文件

```bash
mkdir -p .vllm-deploy
cat > .vllm-deploy/config.json <<EOF
{
  "namespace": "test-vllm",
  "selected_model": "GLM-5",
  "model_path": "/data/models/GLM-5",
  "target_image": "harbor.test.com/vllm:v0.6.0",
  "deploy_mode": "pd_separate",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 8,
  "prefill_tp_size": 8,
  "decode_tp_size": 8
}
EOF

cat > .vllm-deploy/detection-result.json <<EOF
{
  "cluster_connected": true,
  "nodes": [
    {"name": "node-1", "ip": "192.168.1.100", "npu_count": 16},
    {"name": "node-2", "ip": "192.168.1.101", "npu_count": 16}
  ],
  "recommended_nodes": ["node-1", "node-2"]
}
EOF
```

- [ ] 运行 fill-template.sh 测试各模式

```bash
# 测试 single_node
jq '.deploy_mode = "single_node"' .vllm-deploy/config.json > .vllm-deploy/config-test.json
./fill-template.sh .vllm-deploy/config-test.json .vllm-deploy/detection-result.json .vllm-deploy/k8s-test
cat .vllm-deploy/k8s-test/all.yaml | grep -A5 "kind: Deployment"  # 应有完整 Deployment

# 测试 multi_node
jq '.deploy_mode = "multi_node"' .vllm-deploy/config.json > .vllm-deploy/config-test.json
./fill-template.sh .vllm-deploy/config-test.json .vllm-deploy/detection-result.json .vllm-deploy/k8s-test
ls .vllm-deploy/k8s-test/  # 应有 master.yaml 和 worker-1.yaml

# 测试 pd_separate
jq '.deploy_mode = "pd_separate"' .vllm-deploy/config.json > .vllm-deploy/config-test.json
./fill-template.sh .vllm-deploy/config-test.json .vllm-deploy/detection-result.json .vllm-deploy/k8s-test
cat .vllm-deploy/k8s-test/all.yaml | grep "role: prefill"  # 应有 prefill 和 decode Deployment

# 测试 ha_active_standby
jq '.deploy_mode = "ha_active_standby"' .vllm-deploy/config.json > .vllm-deploy/config-test.json
./fill-template.sh .vllm-deploy/config-test.json .vllm-deploy/detection-result.json .vllm-deploy/k8s-test
cat .vllm-deploy/k8s-test/all.yaml | grep "kind: PodDisruptionBudget"  # 应有 PDB 定义
```

### 步骤 8.3：验证 YAML 包含脚本 ConfigMap

- [ ] 检查生成的 YAML 包含脚本挂载

```bash
cat .vllm-deploy/k8s-test/all.yaml | grep "vllm-scripts"  # 应有 ConfigMap 名称
cat .vllm-deploy/k8s-test/all.yaml | grep "mountPath: /scripts"  # 应有挂载路径
```

### 步骤 8.4：最终 Commit

- [ ] Commit 所有修改

```bash
git add -A
git commit -m "fix: resolve all Critical and Important issues from code review

- Fix JSON output protocol: redirect logs to stderr in all scripts
- Fix node JSON concatenation in detect-k8s-env.sh
- Extend NPU scan range to 0-15 for A3 16-card support
- Implement all 4 deploy modes in fill-template.sh
- Add ConfigMap for script mounting in Pod
- Add Ray cluster bootstrap steps for multi-node
- Implement targeted document parsing based on HW_SPEC/DEPLOY_MODE
- Integrate node confirmation workflow into generation chain"
```

---

## 修复后预期状态

| 问题 | 修复后状态 |
|------|-----------|
| JSON 输出不稳定 | 所有日志到 stderr，JSON 到 stdout |
| 多节点 JSON 拼坏 | 使用 jq 正确拼接数组 |
| fill-template 模式不全 | 支持所有 4 种模式 |
| 容器内 NPU 只扫 0-7 | 扫描 0-15 |
| 脚本无法进入 Pod | ConfigMap 挂载到 /scripts |
| 文档解析不针对性 | 根据部署模式过滤章节 |
| 节点确认未接入 | 支持 selected-nodes.json 输入 |
| Ray 未引导启动 | 添加 ray start 步骤 |

---

## 执行顺序建议

按任务编号顺序执行（1→2→3→4→5→6→7→8），因为：
- 任务 1 是基础：JSON 协议稳定后才能串联各阶段
- 任务 2-4 依赖任务 1 完成后才能正确测试
- 任务 5-7 是功能性改进
- 任务 8 是最终验证

建议每完成一个任务就运行步骤 8.1 的验证，确保修复正确。