# vLLM-Deploy Skill

从 vLLM-Ascend 文档自动提取部署脚本，根据 K8s 环境自动修改参数，生成一键执行的 K8s YAML。

**执行环境：** K8s 管理节点（需有 kubectl 和集群管理权限）

## 端到端流程

```
快速获取模型列表 → 用户选择（含镜像仓库） → 针对性文档解析 → K8s 环境探测 → 
镜像处理 → 交互配置 → 生成 K8s YAML → 用户 apply → 容器内探测 → 
生成部署脚本 → 用户确认执行 → 输出交付
```

---

## Phase 1：快速获取模型列表

**模块：** `modules/model-list-fetcher.md`

**输入：** 默认 URL：[vLLM-Ascend 模型列表页](https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html)

**处理：**
1. 抓取模型列表页 HTML
2. 快速提取所有模型名称和链接（不详细解析脚本内容）
3. 展示模型列表供用户选择

**输出：**
```json
{
  "models": [
    {"name": "GLM-5", "url": "GLM5.html"},
    {"name": "Qwen2.5-7B", "url": "Qwen2.5-7B.html"},
    {"name": "DeepSeek-V3.1", "url": "DeepSeek-V3.1.html"}
  ]
}
```

---

## Phase 2：用户选择

**模块：** `modules/user-selector.md`

**输入：** Phase 1 模型列表

**处理：**
1. 用户选择模型（从列表选择）
2. 用户选择硬件规格（A3/A2）
3. 用户选择部署方式：
   - **单节点**：使用 1 个节点部署
   - **多节点**：使用多个节点进行分布式部署
   - **PD分离**：Prefill 和 Decode 节点分离部署
4. 用户输入目标镜像仓库地址（如 `harbor.example.com/library`）

**输出：**
```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library"
}
```

---

## Phase 3：针对性文档解析

**模块：** `modules/doc-parser.md`

**输入：** Phase 2 用户选择结果

**处理：**
1. 只抓取用户选择的模型页面
2. 只解析用户选择的硬件规格（A3 或 A2）的脚本
3. 只解析用户选择的部署方式的脚本（单节点/多节点/PD分离）
4. 提取镜像版本
5. 提取参数模板

**输出：** 针对性脚本模板（含镜像版本）

---

## Phase 4：K8s 环境探测

**模块：** `modules/k8s-env-detector.md`

**执行位置：** K8s 管理节点

**输入：** 无（自动执行）

**处理：**
1. 检查 `kubectl` 是否可用
2. 检查 K8s 集群连接状态
3. 获取集群节点列表（`kubectl get nodes`）
4. 获取各节点 IP 地址（`kubectl get nodes -o wide`）
5. 探测各节点 NPU 设备数量：
   - 方式1：通过节点标签（`kubectl get nodes --show-labels`，查找 `ascend-npu` 相关标签）
   - 方式2：通过资源容量（`kubectl describe node <name>`，查看 `davinci` 资源）
   - 方式3：远程 SSH 到工作节点执行 `npu-smi`
6. 判断硬件规格：A3（16卡）或 A2（8卡）
7. 根据用户选择的部署模式推荐使用的节点

**输出：**
```json
{
  "kubectl_available": true,
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-1",
      "ip": "192.168.1.100",
      "npu_count": 16,
      "hw_spec": "A3"
    },
    {
      "name": "node-2",
      "ip": "192.168.1.101",
      "npu_count": 16,
      "hw_spec": "A3"
    }
  ],
  "recommended_nodes": ["node-1", "node-2"]
}
```

---

## Phase 5：镜像处理

**模块：** `modules/image-handler.md`

**执行位置：** 有 Docker 环境的节点（管理节点或工作节点）

**输入：** 
- Phase 3 提取的源镜像版本（如 `quay.io/vllm-ascend/vllm-ascend:v0.6.0`）
- Phase 2 用户指定的目标镜像仓库地址

**处理：**
1. 确认 Docker 环境可用
2. 登录目标镜像仓库（`docker login`）
3. 拉取官方镜像（如 `quay.io/vllm-ascend/vllm-ascend:v0.6.0`）
4. 重新打标签为用户仓库地址（`docker tag`）
5. 推送镜像到用户仓库（`docker push`）

**输出：**
```json
{
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "push_success": true
}
```

---

## Phase 6：交互配置

**模块：** `modules/config-guide.md`

**输入：** Phase 2-5 结果 + Phase 3 脚本模板

**问答流程：**

| 问答 | 内容 | 输出参数 |
|-----|------|---------|
| Q1 | Namespace 名称 | `namespace` |
| Q2 | 模型路径输入 | `model_path` |
| Q3 | 性能参数确认（max-model-len 等） | `max_model_len`、`max_num_seqs` |
| Q4 | PD分离配置（如适用） | `prefill_nodes`、`decode_nodes` |

**说明：** 镜像仓库地址已在 Phase 2 输入，镜像版本从文档解析自动提取，此阶段只需确认部署参数。

**输出：** 完整用户配置参数集

---

## Phase 7：生成 K8s YAML

**模块：** `modules/k8s-yaml-generator.md`

**输入：** 脚本模板 + Phase 2-6 配置结果

**处理：**
1. 根据硬件规格选择模板（A3/A2）
2. 使用用户仓库的镜像地址生成 Deployment
3. 生成 Namespace YAML
4. 生成 ConfigMap YAML（存储配置参数）
5. 生成各节点 Deployment YAML：
   - 单节点：1 个 Deployment
   - 多节点：多个 Deployment + 分布式配置
   - PD分离：Prefill Deployment + Decode Deployment
6. 生成 Service YAML（暴露服务端口）
7. 生成 `apply-all.sh` 一键执行脚本

**输出文件：**
```
.vllm-deploy/k8s/
├── namespace.yaml
├── configmap.yaml
├── deployment-node1.yaml
├── deployment-node2.yaml
├── service.yaml
└── apply-all.sh
```

---

## Phase 8：用户执行 K8s Apply

**模块：** `modules/k8s-apply-guide.md`

**用户操作：** 执行生成的 K8s YAML

```bash
cd .vllm-deploy/k8s
bash apply-all.sh
```

或手动 apply 各 YAML 文件。

---

## Phase 9：容器内环境探测

**模块：** `modules/container-env-detector.md`

**触发时机：** 用户确认 Pod 已成功启动后

**处理：**
1. 获取 Pod 状态（`kubectl get pods -n <namespace>`）
2. 进入 Pod 探测 NPU 设备映射情况
3. 验证 NPU 设备是否正确挂载
4. 确定容器内实际可用的硬件规格

**输出：**
```json
{
  "pod_name": "vllm-deploy-node1-xxx",
  "container_npu_count": 8,
  "devices_mapped": ["davinci0", "davinci1", ...]
}
```

---

## Phase 10：生成部署脚本

**模块：** `modules/deploy-generator.md`

**输入：** 容器内探测结果 + 用户配置

**处理：**
1. 根据容器内 NPU 数量生成 `vllm serve` 启动命令
2. 设置正确的 `--tensor-parallel-size`
3. 生成 Pod 内执行的部署脚本
4. 展示脚本内容供用户确认

**输出文件：**
```
.vllm-deploy/k8s/
└── deploy.sh            # 在 Pod 内执行 vllm serve
```

---

## Phase 11：用户确认并执行部署脚本

**模块：** `modules/deploy-execution-guide.md`

**用户操作：**

1. **确认脚本内容**：查看生成的 `deploy.sh` 脚本
2. **手动执行部署**：确认无误后在 Pod 内执行

```bash
# 查看脚本内容
cat .vllm-deploy/k8s/deploy.sh

# 确认后执行
kubectl exec -n <namespace> <pod-name> -- bash deploy.sh
```

---

## Phase 12：输出交付

**模块：** `modules/output-guide.md`

**输入：** Phase 6-11 生成的所有文件

**处理：**
1. 创建 `.vllm-deploy/k8s/` 输出目录
2. 写入所有 YAML 和脚本文件
3. 生成 `README.md` 执行指南（包含分步执行说明）

**最终交付：**
```
.vllm-deploy/k8s/
├── README.md            # 执行指南
├── all.yaml             # 合并的 YAML（单节点模式）
│   # 或分立的 YAML（多节点模式）：
│   ├── master.yaml      # Master Deployment + Service
│   └── worker-*.yaml    # Worker Deployment(s)
├── deploy.sh            # 用户确认后手动执行的 vLLM 启动脚本
└── apply-all.sh         # 一键 apply 所有 YAML
```

---

## 快速开始

1. 触发 Skill：输入 `/vllm-deploy`
2. 系统快速获取模型列表
3. **用户选择模型、规格（A3/A2）、部署方式、目标镜像仓库**
4. 系统针对性解析文档（只解析用户选择的）
5. 系统自动探测 K8s 环境和节点信息
6. 系统自动处理镜像（拉取、打标签、推送）
7. 通过问答确认配置参数（Namespace、模型路径、性能参数）
8. 获取生成的 K8s YAML 文件
9. **手动执行 `apply-all.sh`**
10. 系统探测 Pod 内 NPU 环境
11. 系统生成部署脚本（`deploy.sh`）
12. **用户确认脚本内容并手动执行部署**

---

## 文件结构

```
vllm-skill/
├── skill.md                    # Skill 入口
├── skill.yaml                  # Skill 元数据
├── modules/
│   ├── model-list-fetcher.md        # 快速获取模型列表模块
│   ├── user-selector.md             # 用户选择模块（含镜像仓库）
│   ├── doc-parser.md                # 针对性文档解析模块
│   ├── k8s-env-detector.md          # K8s 环境探测模块
│   ├── image-handler.md             # 镜像处理模块
│   ├── config-guide.md              # 交互配置模块
│   ├── k8s-yaml-generator.md        # K8s YAML 生成
│   ├── k8s-apply-guide.md           # Phase 8 用户操作指南
│   ├── container-env-detector.md    # 容器内环境探测模块
│   ├── deploy-generator.md          # 部署脚本生成模块
│   ├── deploy-execution-guide.md    # Phase 11 用户操作指南
│   └── output-guide.md              # 输出交付模块
├── scripts/
│   ├── fetch-model-list.sh          # 抓取模型列表脚本
│   ├── parse-model-doc.sh           # 解析模型文档脚本
│   ├── detect-k8s-env.sh            # K8s 环境探测脚本
│   ├── detect-container-npu.sh      # 容器内 NPU 探测脚本
│   └── push-image.sh                # 镜像处理脚本
└── templates/
    ├── k8s-namespace.yaml            # Namespace 模板
    ├── k8s-configmap.yaml            # ConfigMap 模板
    ├── k8s-deployment.yaml           # Deployment 模板
    ├── k8s-service.yaml              # Service 模板
    ├── deploy.sh                     # vllm serve 部署脚本模板
    └── apply-all.sh                  # K8s 一键 apply 脚本模板
```

---

## 目录说明

### modules/

模块指南文件，描述各阶段的处理逻辑和参数。AI 读取模块描述后调用对应脚本执行操作。

### scripts/

预置辅助脚本，提供可靠的执行能力：

| 脚本 | 用途 | 调用阶段 |
|------|------|---------|
| `fetch-model-list.sh` | 抓取模型列表页并提取模型名称和链接 | Phase 1 |
| `parse-model-doc.sh` | 解析指定模型的文档页面，提取脚本和镜像版本 | Phase 3 |
| `detect-k8s-env.sh` | 探测 K8s 集群节点信息、NPU 数量、硬件规格 | Phase 4 |
| `detect-container-npu.sh` | 在 Pod 内探测 NPU 设备映射情况 | Phase 9 |
| `push-image.sh` | 拉取官方镜像、打标签、推送到用户仓库 | Phase 5 |

### templates/

### k8s-namespace.yaml

Namespace 模板，用于创建部署隔离空间：
- 替换参数：`${NAMESPACE}`、`${MODEL_NAME}`

### k8s-configmap.yaml

ConfigMap 模板，存储部署配置参数：
- 替换参数：`${NAMESPACE}`、`${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}`

### k8s-deployment.yaml

Deployment 模板，定义 Pod 运行配置：
- 替换参数：`${NODE_NAME}`、`${NAMESPACE}`、`${IMAGE}`、`${NPU_RESOURCE_TYPE}`、`${NPU_COUNT}`、`${MODEL_MOUNT_PATH}`、`${MODEL_PATH_HOST}`
- 支持 NPU 资源限制（`davinci` 或 `huawei.com/Ascend910`）

### k8s-service.yaml

Service 模板，暴露服务端口：
- 替换参数：`${NAMESPACE}`、`${SERVICE_PORT}`
- 默认端口 8000，NodePort 方式暴露

### deploy.sh

vllm serve 启动脚本模板，在 Pod 内执行：
- 支持三种部署模式：单节点、多节点、PD分离
- 替换参数：`${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}`、`${MASTER_ADDR}`、`${MASTER_PORT}`、`${RANK}`

### apply-all.sh

K8s 一键 apply 脚本模板：
- 按顺序 apply 所有 YAML 文件
- 自动等待 Pod 就绪
- 替换参数：`${NAMESPACE}`

---

## 错误处理

| 场景 | 处理方式 |
|-----|---------|
| 默认 URL 无法访问 | 提示检查网络或 vLLM-Ascend 文档站点状态 |
| 模型列表提取失败 | 建议手动指定模型教程 URL |
| 脚本块未找到 | 建议手动提供脚本 |
| kubectl 不可用 | 提示安装 kubectl 并配置 kubeconfig |
| 非管理节点执行 | 提示切换到管理节点或确保有集群管理权限 |
| K8s 集群连接失败 | 提示检查 kubeconfig 配置和网络连通性 |
| Docker 不可用（镜像处理） | 提示在有 Docker 的节点执行镜像处理步骤 |
| 镜像仓库登录失败 | 提示检查镜像仓库地址和认证信息 |
| 镜像推送失败 | 提示检查镜像仓库权限和网络连通性 |
| NPU 资源未注册 | 提示检查 Ascend Device Plugin 是否正确安装 |
| Pod 启动失败 | 提示检查镜像、资源和节点状态 |
| 容器内 NPU 映射异常 | 提示检查 Device Plugin 配置 |