#!/bin/bash
# 模板占位符填充脚本
# 读取模板文件，填充占位符，生成最终 YAML
# 使用 envsubst 进行安全模板填充，避免 sed 注入风险

set -e

if ! command -v envsubst >/dev/null 2>&1; then
    echo "Error: envsubst is required but not installed." >&2
    echo "Install it with: apt-get install gettext  or  yum install gettext" >&2
    exit 1
fi

# 参数检查 - 支持新旧两种契约
# 新契约（4参数）：CONFIG, DETECTION, NODES_FILE, OUTPUT_DIR
# 旧契约（3参数）：CONFIG, DETECTION, OUTPUT_DIR（NODES_FILE 使用默认值）
if [ $# -eq 3 ]; then
    CONFIG_FILE="$1"
    DETECTION_FILE="$2"
    OUTPUT_DIR="$3"
    NODES_FILE=".vllm-deploy/selected-nodes.json"
elif [ $# -ge 4 ]; then
    CONFIG_FILE="$1"
    DETECTION_FILE="$2"
    NODES_FILE="$3"
    OUTPUT_DIR="$4"
else
    CONFIG_FILE="${1:-.vllm-deploy/config.json}"
    DETECTION_FILE="${2:-.vllm-deploy/detection-result.json}"
    NODES_FILE="${3:-.vllm-deploy/selected-nodes.json}"
    OUTPUT_DIR="${4:-.vllm-deploy/k8s}"
fi

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

# 如果没有节点选择文件，则根据 detection-result.json 回填一个默认产物
create_default_nodes_file() {
    local source_file="$1"
    local output_file="$2"

    mkdir -p "$(dirname "$output_file")"
    jq -n --slurpfile det "$source_file" '
        ($det[0]) as $d |
        (($d.recommended_nodes // [])) as $recommended |
        {
          master_node: ($d.recommended_nodes[0] // ($d.nodes[0].name // null)),
          nodes: (
            if (($recommended | length) > 0) then
              [ $recommended[] as $name
                | $d.nodes[]
                | select(.name == $name)
                | {name, ip, npu_count} ]
            else
              [ $d.nodes[] | {name, ip, npu_count} ]
            end
          )
        }' > "$output_file"
}

if [ ! -f "$NODES_FILE" ]; then
    echo "Warning: selected-nodes.json not found, using recommended_nodes from detection" >&2
    create_default_nodes_file "$DETECTION_FILE" "$NODES_FILE"
    echo "Generated default node selection: $NODES_FILE" >&2
fi

echo "Using node selection from: $NODES_FILE"
SELECTED_MASTER=$(jq -r '.master_node // (if .nodes[0] | type == "object" then .nodes[0].name else .nodes[0] end)' "$NODES_FILE")

echo "=== Filling Templates ==="
echo "Config: $CONFIG_FILE"
echo "Detection: $DETECTION_FILE"
echo "Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# 读取配置并导出为环境变量（envsubst 使用）
slugify_k8s_name() {
    local input="$1"
    printf '%s' "$input" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
        | cut -c1-63 \
        | sed -E 's/-+$//'
}

export NAMESPACE=$(jq -r '.namespace' "$CONFIG_FILE")
export MODEL_NAME=$(jq -r '.selected_model' "$CONFIG_FILE")
export MODEL_RESOURCE_NAME=$(slugify_k8s_name "$MODEL_NAME")
if [ -z "$MODEL_RESOURCE_NAME" ]; then
    echo "Error: selected_model '$MODEL_NAME' cannot be converted to a Kubernetes resource name" >&2
    exit 1
fi
export MODEL_PATH=$(jq -r '.model_path' "$CONFIG_FILE")
export IMAGE=$(jq -r '.target_image' "$CONFIG_FILE")
DEPLOY_MODE=$(jq -r '.deploy_mode' "$CONFIG_FILE")
export MAX_MODEL_LEN=$(jq -r '.max_model_len' "$CONFIG_FILE")
export MAX_NUM_SEQS=$(jq -r '.max_num_seqs' "$CONFIG_FILE")
export TENSOR_PARALLEL_SIZE=$(jq -r '.tensor_parallel_size' "$CONFIG_FILE")
export MASTER_PORT=$(jq -r '.master_port // 29500' "$CONFIG_FILE")

# 资源默认值
export CPU_REQUEST="${CPU_REQUEST:-4}"
export MEMORY_REQUEST="${MEMORY_REQUEST:-32Gi}"
export CPU_LIMIT="${CPU_LIMIT:-8}"
export MEMORY_LIMIT="${MEMORY_LIMIT:-64Gi}"
export SERVICE_PORT="${SERVICE_PORT:-30000}"
export MODEL_MOUNT_PATH="${MODEL_MOUNT_PATH:-/data}"
export MODEL_PATH_HOST="$MODEL_PATH"
export SHM_SIZE_LIMIT="${SHM_SIZE_LIMIT:-8Gi}"

# 遗留模板 multi-node.yaml 使用 MASTER_ADDR，在 fill_template 中动态设为 MASTER_NODE_IP 的值
# 当前拆分模板不再使用此变量

# 读取探测结果
export NPU_RESOURCE_TYPE=$(jq -r '.nodes[0].npu_type // "huawei.com/Ascend910"' "$DETECTION_FILE")

# 所有可能的 envsubst 变量名（envsubst 只替换模板中实际出现的变量）
ALL_VARS='$NAMESPACE $MODEL_NAME $MODEL_RESOURCE_NAME $MODEL_PATH $IMAGE $NPU_RESOURCE_TYPE $MAX_MODEL_LEN $MAX_NUM_SEQS $TENSOR_PARALLEL_SIZE $CPU_LIMIT $MEMORY_LIMIT $CPU_REQUEST $MEMORY_REQUEST $SERVICE_PORT $MODEL_MOUNT_PATH $MODEL_PATH_HOST $MASTER_PORT $SHM_SIZE_LIMIT $NPU_COUNT $MASTER_NODE_NAME $MASTER_NODE_IP $MASTER_ADDR $WORLD_SIZE $NPU_COUNT_PER_NODE $WORKER_RANK $WORKER_NODE_NAME $WORKER_NODE_IP $PREFILL_TP_SIZE $DECODE_TP_SIZE $PREFILL_NPU_COUNT $DECODE_NPU_COUNT $PREFILL_REPLICAS $DECODE_REPLICAS $KV_CONNECTOR $DECODE_MAX_BATCHED_TOKENS $HA_REPLICAS $HA_MIN_REPLICAS $HA_MAX_REPLICAS $NPU_NODE_LABEL $MODEL_SOURCE'

# 填充函数（使用 envsubst，安全无注入风险）
fill_template() {
    local template_file="$1"
    local output_file="$2"

    # 遗留模板使用 MASTER_ADDR，每次填充前动态同步为 MASTER_NODE_IP
    export MASTER_ADDR="${MASTER_NODE_IP:-}"

    envsubst "$ALL_VARS" < "$template_file" > "$output_file"
    echo "Generated: $output_file"
}

# 使用 jq --arg 机制查询节点信息（防止变量注入）
query_node_ip() {
    local node_name="$1"
    local source_file="$2"
    jq -r --arg name "$node_name" '.nodes[] | select(.name==$name) | .ip' "$source_file"
}

query_node_npu_count() {
    local node_name="$1"
    local source_file="$2"
    jq -r --arg name "$node_name" '.nodes[] | select(.name==$name) | .npu_count // 8' "$source_file"
}

# 根据部署方式生成
TEMPLATE_DIR=".vllm-deploy/templates"

case "$DEPLOY_MODE" in
    single_node)
        export NPU_COUNT=$(query_node_npu_count "$SELECTED_MASTER" "$DETECTION_FILE")

        fill_template "$TEMPLATE_DIR/single-node.yaml" "$OUTPUT_DIR/all.yaml"
        ;;

    multi_node)
        if [ -f "$NODES_FILE" ]; then
            WORLD_SIZE=$(jq -r '.nodes | length' "$NODES_FILE")
            export WORLD_SIZE
            NODE_TYPE=$(jq -r '.nodes[0] | type' "$NODES_FILE")

            if [ "$NODE_TYPE" = "object" ]; then
                export MASTER_NODE_IP=$(jq -r --arg name "$SELECTED_MASTER" '.nodes[] | select(.name==$name) | .ip // empty' "$NODES_FILE")
                export NPU_COUNT_PER_NODE=$(jq -r --arg name "$SELECTED_MASTER" '.nodes[] | select(.name==$name) | .npu_count // 8' "$NODES_FILE")
            else
                MASTER_NODE_IP=""
                export NPU_COUNT_PER_NODE=8
            fi

            if [ -z "$MASTER_NODE_IP" ]; then
                export MASTER_NODE_IP=$(query_node_ip "$SELECTED_MASTER" "$DETECTION_FILE")
            fi

            export MASTER_NODE_NAME="$SELECTED_MASTER"

            fill_template "$TEMPLATE_DIR/multi-node-master.yaml" "$OUTPUT_DIR/master.yaml"

            WORKER_INDEX=1
            while IFS= read -r worker_entry; do
                [ -z "$worker_entry" ] && continue
                WORKER_NAME=$(echo "$worker_entry" | jq -r 'if type == "object" then .name else . end')
                WORKER_IP=$(echo "$worker_entry" | jq -r 'if type == "object" then .ip else empty end')
                if [ -z "$WORKER_IP" ]; then
                    WORKER_IP=$(query_node_ip "$WORKER_NAME" "$DETECTION_FILE")
                fi

                export WORKER_RANK="$WORKER_INDEX"
                export WORKER_NODE_NAME="$WORKER_NAME"
                export WORKER_NODE_IP="$WORKER_IP"

                fill_template "$TEMPLATE_DIR/multi-node-worker.yaml" "$OUTPUT_DIR/worker-${WORKER_INDEX}.yaml"

                WORKER_INDEX=$((WORKER_INDEX + 1))
            done < <(if [ "$NODE_TYPE" = "object" ]; then
                        jq -c --arg master "$SELECTED_MASTER" '.nodes[] | select(.name != $master)' "$NODES_FILE"
                    else
                        jq -c --arg master "$SELECTED_MASTER" '.nodes[] | select(. != $master)' "$NODES_FILE"
                    fi)
        else
            WORLD_SIZE=$(jq -r '.recommended_nodes | length' "$DETECTION_FILE")
            export WORLD_SIZE
            export MASTER_NODE_IP=$(query_node_ip "$SELECTED_MASTER" "$DETECTION_FILE")
            export NPU_COUNT_PER_NODE=$(query_node_npu_count "$SELECTED_MASTER" "$DETECTION_FILE")
            export MASTER_NODE_NAME="$SELECTED_MASTER"

            fill_template "$TEMPLATE_DIR/multi-node-master.yaml" "$OUTPUT_DIR/master.yaml"

            WORKER_INDEX=1
            while IFS= read -r worker_node; do
                [ -z "$worker_node" ] && continue
                WORKER_IP=$(query_node_ip "$worker_node" "$DETECTION_FILE")

                export WORKER_RANK="$WORKER_INDEX"
                export WORKER_NODE_NAME="$worker_node"
                export WORKER_NODE_IP="$WORKER_IP"

                fill_template "$TEMPLATE_DIR/multi-node-worker.yaml" "$OUTPUT_DIR/worker-${WORKER_INDEX}.yaml"

                WORKER_INDEX=$((WORKER_INDEX + 1))
            done < <(jq -r '.recommended_nodes[1:][]' "$DETECTION_FILE")
        fi

        if ls "$OUTPUT_DIR"/worker-*.yaml 1>/dev/null 2>&1; then
            cat "$OUTPUT_DIR/master.yaml" "$OUTPUT_DIR"/worker-*.yaml > "$OUTPUT_DIR/all.yaml"
        else
            cp "$OUTPUT_DIR/master.yaml" "$OUTPUT_DIR/all.yaml"
        fi
        ;;

    pd_separate)
        export PREFILL_TP_SIZE=$(jq -r '.prefill_tp_size // 8' "$CONFIG_FILE")
        export DECODE_TP_SIZE=$(jq -r '.decode_tp_size // 8' "$CONFIG_FILE")
        export PREFILL_NPU_COUNT=$(jq -r '.prefill_npu_count // 8' "$CONFIG_FILE")
        export DECODE_NPU_COUNT=$(jq -r '.decode_npu_count // 8' "$CONFIG_FILE")
        export PREFILL_REPLICAS=$(jq -r '.prefill_replicas // 1' "$CONFIG_FILE")
        export DECODE_REPLICAS=$(jq -r '.decode_replicas // 1' "$CONFIG_FILE")
        export KV_CONNECTOR=$(jq -r '.kv_connector // "MooncakeConnectorV1"' "$CONFIG_FILE")
        export DECODE_MAX_BATCHED_TOKENS=$(jq -r '.decode_max_batched_tokens // 16384' "$CONFIG_FILE")
        export MODEL_SOURCE=$(jq -r '.model_source // .model_path' "$CONFIG_FILE")

        PD_TEMPLATE="$TEMPLATE_DIR/pd-separate.yaml"
        if [ -f "$TEMPLATE_DIR/pd-separate-kthena.yaml" ]; then
            PD_TEMPLATE_TYPE=$(jq -r '.pd_template_type // "standard"' "$CONFIG_FILE")
            if [ "$PD_TEMPLATE_TYPE" = "kthena" ]; then
                if [ "$KV_CONNECTOR" != "MooncakeConnectorV1" ]; then
                    echo "Error: pd-separate-kthena currently requires kv_connector=MooncakeConnectorV1; got '$KV_CONNECTOR'" >&2
                    exit 1
                fi
                PD_TEMPLATE="$TEMPLATE_DIR/pd-separate-kthena.yaml"
            fi
        fi

        fill_template "$PD_TEMPLATE" "$OUTPUT_DIR/all.yaml"
        ;;

    ha_active_standby)
        export HA_REPLICAS=$(jq -r '.ha_replicas // 2' "$CONFIG_FILE")
        export HA_MIN_REPLICAS=$(jq -r '.ha_min_replicas // 1' "$CONFIG_FILE")
        export HA_MAX_REPLICAS=$(jq -r '.ha_max_replicas // 4' "$CONFIG_FILE")
        export NPU_NODE_LABEL=$(jq -r '.npu_node_label // "npu.ascend.com/Ascend910"' "$CONFIG_FILE")

        # 优先使用 NODES_FILE 中的用户选择，回退到 DETECTION_FILE 推荐节点
        if [ -f "$NODES_FILE" ]; then
            SELECTED_NODE=$(jq -r '.master_node // (if .nodes[0] | type == "object" then .nodes[0].name else .nodes[0] end)' "$NODES_FILE")
        else
            SELECTED_NODE=$(jq -r '.recommended_nodes[0]' "$DETECTION_FILE")
        fi
        export NPU_COUNT=$(query_node_npu_count "$SELECTED_NODE" "$DETECTION_FILE")

        fill_template "$TEMPLATE_DIR/ha-active-standby.yaml" "$OUTPUT_DIR/all.yaml"
        ;;

    *)
        echo "Error: Unknown deploy_mode '$DEPLOY_MODE'" >&2
        echo "Supported modes: single_node, multi_node, pd_separate, ha_active_standby" >&2
        exit 1
        ;;
esac

# 生成 apply-all.sh
cat <<EOF > "$OUTPUT_DIR/apply-all.sh"
#!/bin/bash
# 一键部署脚本
set -e

echo "=== Deploying to K8s ==="
echo "Namespace: ${NAMESPACE}"

kubectl apply -f all.yaml

echo "=== Deployment Complete ==="
echo "Service exposed on NodePort: ${SERVICE_PORT}"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n ${NAMESPACE}"
EOF

chmod +x "$OUTPUT_DIR/apply-all.sh"
echo "Generated: $OUTPUT_DIR/apply-all.sh"

# 生成 README.md（根据部署模式包含不同步骤）
if [ "$DEPLOY_MODE" = "single_node" ]; then
    cat <<EOF > "$OUTPUT_DIR/README.md"
# vLLM 部署指南

## 部署信息

- **模型**: ${MODEL_NAME}
- **Namespace**: ${NAMESPACE}
- **部署方式**: ${DEPLOY_MODE}
- **镜像**: ${IMAGE}

## 部署步骤

1. 创建 K8s 资源：
   \`\`\`bash
   cd ${OUTPUT_DIR}
   bash apply-all.sh
   \`\`\`

2. 等待 Pod 进入 Running：
   \`\`\`bash
   kubectl get pods -n ${NAMESPACE} -w
   # 对 single_node 而言，先到 Running 即可；执行 deploy.sh 后才会变 Ready
   \`\`\`

3. 将 deploy.sh 复制到 Pod 内并执行：
   \`\`\`bash
   POD_NAME=\$(kubectl get pods -n ${NAMESPACE} -l app=vllm-deploy,model=${MODEL_RESOURCE_NAME} -o jsonpath='{.items[0].metadata.name}')
   kubectl cp deploy.sh -n ${NAMESPACE} "\$POD_NAME":/tmp/deploy.sh
   kubectl exec -n ${NAMESPACE} "\$POD_NAME" -- bash /tmp/deploy.sh
   \`\`\`

4. 访问服务：
   \`\`\`bash
   curl http://<node-ip>:${SERVICE_PORT}/v1/models
   \`\`\`

## 清理

\`\`\`bash
kubectl delete -f all.yaml
\`\`\`
EOF
elif [ "$DEPLOY_MODE" = "multi_node" ]; then
    cat <<EOF > "$OUTPUT_DIR/README.md"
# vLLM 部署指南（多节点模式）

## 部署信息

- **模型**: ${MODEL_NAME}
- **Namespace**: ${NAMESPACE}
- **部署方式**: ${DEPLOY_MODE}
- **镜像**: ${IMAGE}

## 部署步骤

1. 创建 K8s 资源：
   \`\`\`bash
   cd ${OUTPUT_DIR}
   bash apply-all.sh
   \`\`\`

2. 等待所有 Pod 进入 Running（Master 和 Worker）：
   \`\`\`bash
   kubectl get pods -n ${NAMESPACE} -w
   # 多节点模式先到 Running 即可；执行 deploy.sh 后相关 Pod 才会逐步变 Ready
   \`\`\`

3. 将 deploy.sh 复制到 Master Pod 内并执行（Worker 已通过 ray start 加入集群，无需执行 deploy.sh）：
   \`\`\`bash
   # Master Pod
   MASTER_POD=\$(kubectl get pods -n ${NAMESPACE} -l app=vllm-deploy,model=${MODEL_RESOURCE_NAME},role=master -o jsonpath='{.items[0].metadata.name}')
   kubectl cp deploy.sh -n ${NAMESPACE} "\$MASTER_POD":/tmp/deploy.sh
   kubectl exec -n ${NAMESPACE} "\$MASTER_POD" -- bash /tmp/deploy.sh
   \`\`\`

4. 访问服务：
   \`\`\`bash
   curl http://<node-ip>:${SERVICE_PORT}/v1/models
   \`\`\`

## 清理

\`\`\`bash
kubectl delete -f all.yaml
\`\`\`
EOF
else
    cat <<EOF > "$OUTPUT_DIR/README.md"
# vLLM 部署指南

## 部署信息

- **模型**: ${MODEL_NAME}
- **Namespace**: ${NAMESPACE}
- **部署方式**: ${DEPLOY_MODE}
- **镜像**: ${IMAGE}

## 部署步骤

1. 执行一键部署：
   \`\`\`bash
   cd ${OUTPUT_DIR}
   bash apply-all.sh
   \`\`\`

2. 检查 Pod 状态：
   \`\`\`bash
   kubectl get pods -n ${NAMESPACE} -w
   \`\`\`

3. 访问服务：
   \`\`\`bash
   curl http://<node-ip>:${SERVICE_PORT}/v1/models
   \`\`\`

## 清理

\`\`\`bash
kubectl delete -f all.yaml
\`\`\`
EOF
fi

echo "Generated: $OUTPUT_DIR/README.md"
echo ""
echo "=== Template Filling Complete ==="
