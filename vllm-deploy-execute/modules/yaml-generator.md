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
3. 为每个 Worker 节点生成独立 Deployment
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
    ├── deployment-worker-1.yaml    # multi_node 时
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