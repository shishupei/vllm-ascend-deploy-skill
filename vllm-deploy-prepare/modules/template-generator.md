# Phase 7: 生成模板文件

## 目标

根据部署方式选择对应的 K8s YAML 模板，复制到输出目录。

## 输入

- config.json（包含 deploy_mode）
- templates/ 目录下的模板文件

## 可用模板

| 模板文件 | 适用部署方式 | 说明 |
|----------|--------------|------|
| `single-node.yaml` | 单节点部署 | 标准 Deployment，适合单机推理 |
| `multi-node-master.yaml` + `multi-node-worker.yaml` | 多节点分布式 | Ray 分布式，Master + Worker 模式 |
| `pd-separate.yaml` | PD 分离（标准 K8s） | Prefill/Decode 分离，使用 kv-transfer-config |
| `pd-separate-kthena.yaml` | PD 分离（Kthena） | 使用 Volcano Kthena CRD |
| `ha-active-standby.yaml` | 主备高可用 | 多副本 + PDB + HPA |

## 模板选择逻辑

根据 `config.json` 中的 `deploy_mode` 选择：

| deploy_mode | 使用的模板 |
|-------------|------------|
| `single_node` | `single-node.yaml` |
| `multi_node` | `multi-node-master.yaml` + `multi-node-worker.yaml` |
| `pd_separate` | `pd-separate.yaml` 或 `pd-separate-kthena.yaml` |
| `ha_active_standby` | `ha-active-standby.yaml` |

## PD 分离模板选择

如果 `deploy_mode` 为 `pd_separate`，询问用户：

```
PD 分离有两种部署方式：
1. 标准 Kubernetes Deployment - 适用于通用 K8s 环境
2. Kthena CRD - 适用于华为昇腾 + Volcano 环境

请选择：1 或 2
```

## 占位符说明

各模板使用 `${VAR}` 格式的占位符，需要 Skill 2 填充：

### 通用占位符
- `${NAMESPACE}` - K8s Namespace
- `${MODEL_NAME}` - 模型名称
- `${MODEL_PATH}` - 模型路径
- `${IMAGE}` - 容器镜像
- `${NPU_RESOURCE_TYPE}` - NPU 资源类型（如 `huawei.com/Ascend910`）
- `${NPU_COUNT}` - NPU 数量
- `${SERVICE_PORT}` - NodePort 端口

### 多节点专属占位符
- `${MASTER_NODE_NAME}` - Master 节点名
- `${MASTER_NODE_IP}` - Master 节点 IP
- `${WORKER_RANK}` - Worker Rank 编号
- `${WORKER_NODE_NAME}` - Worker 节点名
- `${WORKER_NODE_IP}` - Worker 节点 IP
- `${WORLD_SIZE}` - 分布式世界大小
- `${MASTER_PORT}` - Ray Master 端口

### PD 分离专属占位符
- `${PREFILL_REPLICAS}` - Prefill 副本数
- `${DECODE_REPLICAS}` - Decode 副本数
- `${PREFILL_TP_SIZE}` - Prefill 张量并行大小
- `${DECODE_TP_SIZE}` - Decode 张量并行大小
- `${PREFILL_NPU_COUNT}` - Prefill NPU 数量
- `${DECODE_NPU_COUNT}` - Decode NPU 数量
- `${KV_CONNECTOR}` - KV 连接器类型（标准 PD 模板可配置；Kthena 模板控制面当前固定为 `mooncake`）
- `${DECODE_MAX_BATCHED_TOKENS}` - Decode 最大 batch tokens

### 高可用专属占位符
- `${HA_REPLICAS}` - 副本数
- `${HA_MIN_REPLICAS}` - HPA 最小副本
- `${HA_MAX_REPLICAS}` - HPA 最大副本
- `${NPU_NODE_LABEL}` - NPU 节点标签

## 输出目录

```
.vllm-deploy/
├── config.json
├── image-info.json
└── templates/
    ├── <selected-template>.yaml    # 选中的模板文件
    ├── multi-node-master.yaml      # 仅 multi_node
    └── multi-node-worker.yaml      # 仅 multi_node
```

## AI 执行指南

1. 读取 `config.json` 获取 `deploy_mode`
2. 根据部署方式选择对应模板文件
3. 如果是 PD 分离，询问用户选择标准 K8s 或 Kthena
4. 创建 `.vllm-deploy/templates/` 目录
5. 复制选中的模板文件到输出目录
6. 告知用户模板已生成，说明使用的模板类型
7. 提示用户运行 `/vllm-deploy-execute` 在 K8s 管理节点继续

## 完成提示

```
准备阶段完成！输出文件已生成到 .vllm-deploy/

部署方式：${DEPLOY_MODE}
使用模板：${TEMPLATE_NAME}

下一步：
1. 将 .vllm-deploy/ 目录复制到 K8s 管理节点
2. 运行 /vllm-deploy-execute 继续部署
```
