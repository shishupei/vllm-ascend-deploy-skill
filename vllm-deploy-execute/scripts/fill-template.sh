#!/bin/bash
# 模板占位符填充脚本
# 读取模板文件，填充占位符，生成最终 YAML

set -e

# 参数检查
CONFIG_FILE="${1:-.vllm-deploy/config.json}"
DETECTION_FILE="${2:-.vllm-deploy/detection-result.json}"
NODES_FILE="${3:-.vllm-deploy/selected-nodes.json}"  # 用户确认的节点选择
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
    echo "Using node selection from: $NODES_FILE"
    SELECTED_MASTER=$(jq -r '.master_node // .nodes[0].name // .nodes[0]' "$NODES_FILE")
fi

echo "=== Filling Templates ==="
echo "Config: $CONFIG_FILE"
echo "Detection: $DETECTION_FILE"
echo "Output: $OUTPUT_DIR"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 读取配置
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
CPU_REQUEST="${CPU_REQUEST:-4}"
MEMORY_REQUEST="${MEMORY_REQUEST:-32Gi}"
CPU_LIMIT="${CPU_LIMIT:-8}"
MEMORY_LIMIT="${MEMORY_LIMIT:-64Gi}"
SERVICE_PORT="${SERVICE_PORT:-30000}"
MODEL_MOUNT_PATH="${MODEL_MOUNT_PATH:-/data}"
MODEL_PATH_HOST="$MODEL_PATH"

# 读取探测结果
NPU_RESOURCE_TYPE=$(jq -r '.nodes[0].npu_type // "huawei.com/Ascend910"' "$DETECTION_FILE")

# 填充函数
fill_template() {
    local template_file="$1"
    local output_file="$2"
    local extra_subs="$3"

    # 基础替换
    sed -e "s|\${NAMESPACE}|${NAMESPACE}|g" \
        -e "s|\${MODEL_NAME}|${MODEL_NAME}|g" \
        -e "s|\${MODEL_PATH}|${MODEL_PATH}|g" \
        -e "s|\${IMAGE}|${IMAGE}|g" \
        -e "s|\${NPU_RESOURCE_TYPE}|${NPU_RESOURCE_TYPE}|g" \
        -e "s|\${MAX_MODEL_LEN}|${MAX_MODEL_LEN}|g" \
        -e "s|\${MAX_NUM_SEQS}|${MAX_NUM_SEQS}|g" \
        -e "s|\${TENSOR_PARALLEL_SIZE}|${TENSOR_PARALLEL_SIZE}|g" \
        -e "s|\${CPU_LIMIT}|${CPU_LIMIT}|g" \
        -e "s|\${MEMORY_LIMIT}|${MEMORY_LIMIT}|g" \
        -e "s|\${CPU_REQUEST}|${CPU_REQUEST}|g" \
        -e "s|\${MEMORY_REQUEST}|${MEMORY_REQUEST}|g" \
        -e "s|\${SERVICE_PORT}|${SERVICE_PORT}|g" \
        -e "s|\${MODEL_MOUNT_PATH}|${MODEL_MOUNT_PATH}|g" \
        -e "s|\${MODEL_PATH_HOST}|${MODEL_PATH_HOST}|g" \
        -e "s|\${MASTER_PORT}|${MASTER_PORT}|g" \
        $extra_subs "$template_file" > "$output_file"

    echo "Generated: $output_file"
}

# 根据部署方式生成
TEMPLATE_DIR=".vllm-deploy/templates"

case "$DEPLOY_MODE" in
    single_node)
        NPU_COUNT=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .npu_count // 8' "$DETECTION_FILE")

        fill_template "$TEMPLATE_DIR/single-node.yaml" "$OUTPUT_DIR/all.yaml" \
            "-e s|\${NPU_COUNT}|${NPU_COUNT}|g"
        ;;

    multi_node)
        # 读取节点选择配置，优先使用 NODES_FILE
        if [ -f "$NODES_FILE" ]; then
            # 从 selected-nodes.json 读取用户确认的节点
            WORLD_SIZE=$(jq -r '.nodes | length' "$NODES_FILE")
            MASTER_NODE_IP=$(jq -r '.nodes[0].ip // .nodes[0]' "$NODES_FILE")
            NPU_COUNT_PER_NODE=$(jq -r '.nodes[0].npu_count // 8' "$NODES_FILE")
            SELECTED_MASTER=$(jq -r '.nodes[0].name // .nodes[0]' "$NODES_FILE")

            # 生成 master YAML（使用 master-only 模板）
            fill_template "$TEMPLATE_DIR/multi-node-master.yaml" "$OUTPUT_DIR/master.yaml" \
                "-e s|\${MASTER_NODE_NAME}|${SELECTED_MASTER}|g \
                 -e s|\${MASTER_NODE_IP}|${MASTER_NODE_IP}|g \
                 -e s|\${WORLD_SIZE}|${WORLD_SIZE}|g \
                 -e s|\${NPU_COUNT_PER_NODE}|${NPU_COUNT_PER_NODE}|g"

            # 为每个 worker 生成独立 YAML（使用 worker-only 模板）
            WORKER_INDEX=1
            while IFS= read -r worker_entry; do
                [ -z "$worker_entry" ] && continue
                # 支持对象格式 {name, ip} 或简单字符串
                WORKER_NAME=$(echo "$worker_entry" | jq -r '.name // .')
                WORKER_IP=$(echo "$worker_entry" | jq -r '.ip // empty')
                # 如果没有 ip 字段，从 detection-result.json 查找
                if [ -z "$WORKER_IP" ]; then
                    WORKER_IP=$(jq -r '.nodes[] | select(.name=="'$WORKER_NAME'") | .ip' "$DETECTION_FILE")
                fi
                fill_template "$TEMPLATE_DIR/multi-node-worker.yaml" "$OUTPUT_DIR/worker-${WORKER_INDEX}.yaml" \
                    "-e s|\${MASTER_NODE_NAME}|${SELECTED_MASTER}|g \
                     -e s|\${MASTER_NODE_IP}|${MASTER_NODE_IP}|g \
                     -e s|\${WORLD_SIZE}|${WORLD_SIZE}|g \
                     -e s|\${NPU_COUNT_PER_NODE}|${NPU_COUNT_PER_NODE}|g \
                     -e s|\${WORKER_RANK}|${WORKER_INDEX}|g \
                     -e s|\${WORKER_NODE_NAME}|${WORKER_NAME}|g \
                     -e s|\${WORKER_NODE_IP}|${WORKER_IP}|g"
                WORKER_INDEX=$((WORKER_INDEX + 1))
            done < <(jq -c '.nodes[1:][]' "$NODES_FILE")
        else
            # 原有逻辑：从 detection-result.json 读取推荐节点
            WORLD_SIZE=$(jq -r '.nodes | length' "$DETECTION_FILE")
            MASTER_NODE_IP=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .ip' "$DETECTION_FILE")
            NPU_COUNT_PER_NODE=$(jq -r '.nodes[] | select(.name=="'$SELECTED_MASTER'") | .npu_count // 8' "$DETECTION_FILE")

            # 生成 master YAML（使用 master-only 模板）
            fill_template "$TEMPLATE_DIR/multi-node-master.yaml" "$OUTPUT_DIR/master.yaml" \
                "-e s|\${MASTER_NODE_NAME}|${SELECTED_MASTER}|g \
                 -e s|\${MASTER_NODE_IP}|${MASTER_NODE_IP}|g \
                 -e s|\${WORLD_SIZE}|${WORLD_SIZE}|g \
                 -e s|\${NPU_COUNT_PER_NODE}|${NPU_COUNT_PER_NODE}|g"

            # 为每个 worker 生成独立 YAML（使用 worker-only 模板）
            WORKER_INDEX=1
            while IFS= read -r worker_node; do
                [ -z "$worker_node" ] && continue
                WORKER_IP=$(jq -r '.nodes[] | select(.name=="'$worker_node'") | .ip' "$DETECTION_FILE")
                fill_template "$TEMPLATE_DIR/multi-node-worker.yaml" "$OUTPUT_DIR/worker-${WORKER_INDEX}.yaml" \
                    "-e s|\${MASTER_NODE_NAME}|${SELECTED_MASTER}|g \
                     -e s|\${MASTER_NODE_IP}|${MASTER_NODE_IP}|g \
                     -e s|\${WORLD_SIZE}|${WORLD_SIZE}|g \
                     -e s|\${NPU_COUNT_PER_NODE}|${NPU_COUNT_PER_NODE}|g \
                     -e s|\${WORKER_RANK}|${WORKER_INDEX}|g \
                     -e s|\${WORKER_NODE_NAME}|${worker_node}|g \
                     -e s|\${WORKER_NODE_IP}|${WORKER_IP}|g"
                WORKER_INDEX=$((WORKER_INDEX + 1))
            done < <(jq -r '.recommended_nodes[1:][]' "$DETECTION_FILE")
        fi

        # 合并所有 YAML（检查是否有 worker 文件）
        if ls "$OUTPUT_DIR"/worker-*.yaml 1>/dev/null 2>&1; then
            cat "$OUTPUT_DIR/master.yaml" "$OUTPUT_DIR"/worker-*.yaml > "$OUTPUT_DIR/all.yaml"
        else
            cp "$OUTPUT_DIR/master.yaml" "$OUTPUT_DIR/all.yaml"
        fi
        ;;

    pd_separate)
        PREFILL_TP_SIZE=$(jq -r '.prefill_tp_size // 8' "$CONFIG_FILE")
        DECODE_TP_SIZE=$(jq -r '.decode_tp_size // 8' "$CONFIG_FILE")
        PREFILL_NPU_COUNT=$(jq -r '.prefill_npu_count // 8' "$CONFIG_FILE")
        DECODE_NPU_COUNT=$(jq -r '.decode_npu_count // 8' "$CONFIG_FILE")
        PREFILL_REPLICAS=$(jq -r '.prefill_replicas // 1' "$CONFIG_FILE")
        DECODE_REPLICAS=$(jq -r '.decode_replicas // 1' "$CONFIG_FILE")
        KV_CONNECTOR=$(jq -r '.kv_connector // "MooncakeConnectorV1"' "$CONFIG_FILE")
        DECODE_MAX_BATCHED_TOKENS=$(jq -r '.decode_max_batched_tokens // 16384' "$CONFIG_FILE")

        # 动态选择模板：检查 prepare 阶段复制了哪个模板
        PD_TEMPLATE="$TEMPLATE_DIR/pd-separate.yaml"
        if [ -f "$TEMPLATE_DIR/pd-separate-kthena.yaml" ]; then
            # 检查 config.json 中的模板类型偏好
            PD_TEMPLATE_TYPE=$(jq -r '.pd_template_type // "standard"' "$CONFIG_FILE")
            if [ "$PD_TEMPLATE_TYPE" = "kthena" ]; then
                PD_TEMPLATE="$TEMPLATE_DIR/pd-separate-kthena.yaml"
            fi
        fi

        fill_template "$PD_TEMPLATE" "$OUTPUT_DIR/all.yaml" \
            "-e s|\${PREFILL_TP_SIZE}|${PREFILL_TP_SIZE}|g \
             -e s|\${DECODE_TP_SIZE}|${DECODE_TP_SIZE}|g \
             -e s|\${PREFILL_NPU_COUNT}|${PREFILL_NPU_COUNT}|g \
             -e s|\${DECODE_NPU_COUNT}|${DECODE_NPU_COUNT}|g \
             -e s|\${PREFILL_REPLICAS}|${PREFILL_REPLICAS}|g \
             -e s|\${DECODE_REPLICAS}|${DECODE_REPLICAS}|g \
             -e s|\${KV_CONNECTOR}|${KV_CONNECTOR}|g \
             -e s|\${DECODE_MAX_BATCHED_TOKENS}|${DECODE_MAX_BATCHED_TOKENS}|g"
        ;;

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

    *)
        echo "Error: Unknown deploy_mode '$DEPLOY_MODE'" >&2
        echo "Supported modes: single_node, multi_node, pd_separate, ha_active_standby" >&2
        exit 1
        ;;
esac

# 根据部署模式生成 deploy.sh 内容
if [ "$DEPLOY_MODE" = "multi_node" ]; then
    DEPLOY_SH_CONTENT="vllm serve ${MODEL_PATH} \
      --served-model-name ${MODEL_NAME} \
      --tensor-parallel-size ${TENSOR_PARALLEL_SIZE} \
      --max-model-len ${MAX_MODEL_LEN} \
      --max-num-seqs ${MAX_NUM_SEQS} \
      --distributed-executor-backend ray \
      --port 8000 \
      --trust-remote-code"
else
    DEPLOY_SH_CONTENT="vllm serve ${MODEL_PATH} \
      --served-model-name ${MODEL_NAME} \
      --tensor-parallel-size ${TENSOR_PARALLEL_SIZE} \
      --max-model-len ${MAX_MODEL_LEN} \
      --max-num-seqs ${MAX_NUM_SEQS} \
      --port 8000 \
      --trust-remote-code"
fi

# 生成脚本 ConfigMap YAML
cat <<EOF > "$OUTPUT_DIR/scripts-configmap.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: vllm-scripts
  namespace: ${NAMESPACE}
data:
  detect-npu.sh: |
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
    ${DEPLOY_SH_CONTENT}
EOF

echo "Generated: $OUTPUT_DIR/scripts-configmap.yaml"

# 生成 apply-all.sh
cat <<EOF > "$OUTPUT_DIR/apply-all.sh"
#!/bin/bash
# 一键部署脚本
set -e

echo "=== Deploying to K8s ==="
echo "Namespace: $NAMESPACE"

kubectl apply -f all.yaml

echo "=== Deployment Complete ==="
echo "Service exposed on NodePort: $SERVICE_PORT"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n $NAMESPACE"
EOF

chmod +x "$OUTPUT_DIR/apply-all.sh"
echo "Generated: $OUTPUT_DIR/apply-all.sh"

# 生成 README.md
cat <<EOF > "$OUTPUT_DIR/README.md"
# vLLM 部署指南

## 部署信息

- **模型**: $MODEL_NAME
- **Namespace**: $NAMESPACE
- **部署方式**: $DEPLOY_MODE
- **镜像**: $IMAGE

## 部署步骤

1. 执行一键部署：
   \`\`\`bash
   cd $OUTPUT_DIR
   bash apply-all.sh
   \`\`\`

2. 检查 Pod 状态：
   \`\`\`bash
   kubectl get pods -n $NAMESPACE -w
   \`\`\`

3. 访问服务：
   \`\`\`bash
   curl http://<node-ip>:$SERVICE_PORT/v1/models
   \`\`\`

## 清理

\`\`\`bash
kubectl delete -f all.yaml
\`\`\`
EOF

echo "Generated: $OUTPUT_DIR/README.md"
echo ""
echo "=== Template Filling Complete ==="