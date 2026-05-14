# vLLM-Deploy Skill 设计规格

**日期**: 2026-05-14
**作者**: buchuibuhei
**状态**: 待审查

---

## 概述

从 vLLM-Ascend 文档自动提取部署脚本，根据 K8s 环境自动修改参数，生成一键执行的 K8s YAML。

**设计决策**: 分拆为两个 Skill，分离准备阶段和执行阶段，允许用户在不同环境执行。

---

## Skill 1: vllm-deploy-prepare

### 元数据

| 属性 | 值 |
|------|---|
| name | vllm-deploy-prepare |
| description | vLLM-Ascend 部署准备 - 获取模型列表、解析文档、处理镜像、生成配置 |
| version | 1.0.0 |
| triggers | `/vllm-deploy-prepare`, `vllm 部署准备` |
| dependencies | curl/wget (网络请求), docker (镜像处理，可选) |
| output_dir | `.vllm-deploy/` |

### 执行环境

任意有网络和 Docker 的节点（本地开发机、笔记本等）。

### 负责 Phase

| Phase | 功能 | 说明 |
|-------|------|------|
| Phase 1 | 快速获取模型列表 | Web 抓取，无需 K8s |
| Phase 2 | 用户选择 | 模型、规格、部署方式、镜像仓库 |
| Phase 3 | 针对性文档解析 | 只解析用户选择的模型文档 |
| Phase 5 | 镜像处理 | 拉取、打标签、推送到用户仓库 |
| Phase 6 | 交互配置 | Namespace、模型路径、性能参数 |
| Phase 7 | 生成模板文件 | YAML 模板 + apply-all.sh 模板（含占位符） |

### 模块文件

| 文件 | 功能 | 输入 | 输出 |
|------|------|------|------|
| `model-list-fetcher.md` | 抓取模型列表页，提取名称和链接 | 默认 URL | 模型列表 JSON |
| `user-selector.md` | 问答式选择模型、规格、部署方式、镜像仓库 | 模型列表 | 用户选择 JSON |
| `doc-parser.md` | 解析指定模型文档，提取脚本和镜像版本 | 用户选择 + URL | 脚本模板 + 镜像信息 |
| `image-handler.md` | 拉取/推送镜像（Docker 可用时执行） | 源镜像 + 目标仓库 | 镜像处理结果 |
| `config-guide.md` | 交互问答配置 Namespace、模型路径等 | 用户选择 | 完整配置 JSON |
| `template-generator.md` | 生成 YAML 模板文件（含占位符） | 配置 JSON + 脚本模板 | 模板文件集 |

### 辅助脚本

| 文件 | 功能 | 调用时机 |
|------|------|---------|
| `fetch-model-list.sh` | 抓取模型列表页 HTML 并提取模型名称/链接 | Phase 1 |
| `parse-model-doc.sh` | 解析模型文档页面，提取启动脚本和镜像版本 | Phase 3 |

### 模板文件

| 文件 | 功能 | 占位符 |
|------|------|--------|
| `k8s-namespace.yaml` | Namespace 定义 | `${NAMESPACE}`, `${MODEL_NAME}` |
| `k8s-configmap.yaml` | ConfigMap 配置参数 | `${NAMESPACE}`, `${MODEL_PATH}`, `${MAX_MODEL_LEN}`, `${MAX_NUM_SEQS}`, `${TENSOR_PARALLEL_SIZE}` |
| `k8s-deployment.yaml.template` | Deployment 模板（多节点时复制多份） | `${NODE_NAME}`, `${NAMESPACE}`, `${IMAGE}`, `${NPU_RESOURCE_TYPE}`, `${NPU_COUNT}`, `${MODEL_MOUNT_PATH}`, `${MODEL_PATH_HOST}` |
| `k8s-service.yaml` | Service 暴露端口 | `${NAMESPACE}`, `${SERVICE_PORT}` |
| `deploy.sh.template` | Pod 内 vllm serve 启动脚本 | `${MODEL_PATH}`, `${MAX_MODEL_LEN}`, `${MAX_NUM_SEQS}`, `${TENSOR_PARALLEL_SIZE}`, `${MASTER_ADDR}`, `${MASTER_PORT}`, `${RANK}`, `${WORLD_SIZE}` |
| `apply-all.sh.template` | 一键 apply 脚本 | `${NAMESPACE}` |

### 输出目录结构

```
.vllm-deploy/
├── config.json           # 用户配置汇总（供 Skill 2 读取）
├── image-info.json       # 镜像信息
└── templates/
    ├── k8s-namespace.yaml
    ├── k8s-configmap.yaml
    ├── k8s-deployment.yaml.template
    ├── k8s-service.yaml
    ├── deploy.sh.template
    └── apply-all.sh.template
```

### 执行流程

```
用户触发 /vllm-deploy-prepare
    ↓
读取 model-list-fetcher.md → 调用 fetch-model-list.sh
    ↓
展示模型列表 → 读取 user-selector.md → 问答选择
    ↓
读取 doc-parser.md → 调用 parse-model-doc.sh（只解析用户选择的）
    ↓
读取 image-handler.md → 检测 Docker → 执行镜像处理（可选）
    ↓
读取 config-guide.md → 问答配置参数
    ↓
读取 template-generator.md → 生成模板文件到 .vllm-deploy/templates/
    ↓
输出 config.json（汇总所有配置）→ 提示用户运行 vllm-deploy-execute
```

---

## Skill 2: vllm-deploy-execute

### 元数据

| 属性 | 值 |
|------|---|
| name | vllm-deploy-execute |
| description | vLLM-Ascend 部署执行 - K8s 环境探测、生成 YAML、执行部署 |
| version | 1.0.0 |
| triggers | `/vllm-deploy-execute`, `vllm 部署执行` |
| dependencies | kubectl (K8s 管理权限), `.vllm-deploy/` 目录存在 |
| prerequisite_skill | vllm-deploy-prepare |
| output_dir | `.vllm-deploy/k8s/` |

### 执行环境

K8s 管理节点（需 kubectl 和集群管理权限）。

### 负责 Phase

| Phase | 功能 | 说明 |
|-------|------|------|
| Phase 4 | K8s 环境探测 | 探测节点、NPU 数量、推荐节点 |
| Phase 7（补）| 填充模板生成 YAML | 根据探测结果填充模板占位符 |
| Phase 8 | 执行 K8s Apply | 用户执行 apply-all.sh |
| Phase 9 | 容器内环境探测 | 验证 Pod 内 NPU 映射 |
| Phase 10 | 生成部署脚本 | 根据容器内 NPU 数量生成 deploy.sh |
| Phase 11 | 执行部署脚本 | 用户在 Pod 内执行 |
| Phase 12 | 输出交付 | 最终结果汇总 |

### 模块文件

| 文件 | 功能 | 输入 | 输出 |
|------|------|------|------|
| `k8s-env-detector.md` | 探测 K8s 集群节点、NPU 数量、硬件规格 | 无（自动执行） | 节点列表 + NPU 信息 |
| `yaml-generator.md` | 读取模板 + 探测结果 → 填充占位符生成最终 YAML | config.json + 模板 + 探测结果 | k8s/*.yaml 文件 |
| `k8s-apply-guide.md` | 指导用户执行 apply-all.sh | k8s/*.yaml | 用户操作指引 |
| `container-env-detector.md` | 进入 Pod 探测 NPU 设备映射 | Pod 名称 | 容器内 NPU 信息 |
| `deploy-generator.md` | 根据容器内 NPU 数量生成 deploy.sh | NPU 信息 + config.json | deploy.sh |
| `deploy-execution-guide.md` | 指导用户在 Pod 内执行 deploy.sh | deploy.sh | 用户操作指引 |
| `output-guide.md` | 汇总最终输出，生成 README.md | 所有文件 + 结果 | 最终交付文档 |

### 辅助脚本

| 文件 | 功能 | 调用时机 |
|------|------|---------|
| `detect-k8s-env.sh` | 探测 kubectl 可用性、集群连接、节点 NPU 数量 | Phase 4 |
| `detect-container-npu.sh` | 在 Pod 内执行 npu-smi 探测 NPU 设备 | Phase 9 |
| `fill-template.sh` | 替换模板占位符生成最终 YAML | Phase 7 补 |

### 输出目录结构

```
.vllm-deploy/
├── k8s/
│   ├── namespace.yaml        # 已填充
│   ├── configmap.yaml        # 已填充
│   ├── deployment-node1.yaml # 已填充
│   ├── deployment-node2.yaml # 已填充（多节点时）
│   ├── service.yaml          # 已填充
│   ├── apply-all.sh          # 已填充
│   ├── deploy.sh             # Pod 内执行脚本
│   └── README.md             # 执行指南
├── detection-result.json     # K8s 环境探测结果
└── final-output.json         # 最终部署信息（Service IP、端口等）
```

### 执行流程

```
用户触发 /vllm-deploy-execute
    ↓
检查前置条件：.vllm-deploy/config.json 是否存在
    ↓
读取 k8s-env-detector.md → 调用 detect-k8s-env.sh
    ↓
输出节点信息 + 推荐节点列表 → 确认用户选择
    ↓
读取 yaml-generator.md → 调用 fill-template.sh
    ↓
生成 .vllm-deploy/k8s/*.yaml 文件
    ↓
读取 k8s-apply-guide.md → 提示用户执行 apply-all.sh
    ↓
【用户手动执行】→ 等待用户确认 Pod 启动成功
    ↓
读取 container-env-detector.md → 调用 detect-container-npu.sh
    ↓
输出容器内 NPU 数量 → 确认
    ↓
读取 deploy-generator.md → 生成 deploy.sh
    ↓
读取 deploy-execution-guide.md → 提示用户在 Pod 内执行
    ↓
【用户手动执行】→ 等待用户确认部署成功
    ↓
读取 output-guide.md → 汇总输出 + 生成 README.md
    ↓
完成，输出 Service 访问信息
```

### 用户确认点

| 确认点 | 用户操作 | AI 等待 |
|--------|---------|--------|
| K8s 探测结果 | 确认节点选择 | 等待用户回复 |
| YAML 生成后 | 执行 `bash apply-all.sh` | 等待用户确认 Pod 启动 |
| Pod NPU 探测后 | 执行 `kubectl exec ... deploy.sh` | 等待用户确认部署成功 |

---

## 两个 Skill 的衔接

### 衔接点

- Skill 1 输出 `config.json`，包含用户的所有选择
- Skill 2 读取 `config.json`，结合 K8s 环境探测结果，填充模板生成最终 YAML

### config.json 格式

```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 8,
  "master_addr": "待填充",
  "master_port": 29500
}
```

---

## 完整文件结构

```
vllm-skill/
├── README.md                         # 项目说明（已存在）
│
├── skill-prepare/
│   ├── skill.md                      # Skill 入口
│   ├── skill.yaml                    # Skill 元数据
│   ├── modules/
│   │   ├── model-list-fetcher.md
│   │   ├── user-selector.md
│   │   ├── doc-parser.md
│   │   ├── image-handler.md
│   │   ├── config-guide.md
│   │   └── template-generator.md
│   ├── scripts/
│   │   ├── fetch-model-list.sh
│   │   └── parse-model-doc.sh
│   └── templates/
│       ├── k8s-namespace.yaml
│       ├── k8s-configmap.yaml
│       ├── k8s-deployment.yaml.template
│       ├── k8s-service.yaml
│       ├── deploy.sh.template
│       └── apply-all.sh.template
│
├── skill-execute/
│   ├── skill.md                      # Skill 入口
│   ├── skill.yaml                    # Skill 元数据
│   ├── modules/
│   │   ├── k8s-env-detector.md
│   │   ├── yaml-generator.md
│   │   ├── k8s-apply-guide.md
│   │   ├── container-env-detector.md
│   │   ├── deploy-generator.md
│   │   ├── deploy-execution-guide.md
│   │   └── output-guide.md
│   └── scripts/
│       ├── detect-k8s-env.sh
│       ├── detect-container-npu.sh
│       └── fill-template.sh
```

---

## 文件数量统计

| 类别 | Skill 1 | Skill 2 | 合计 |
|------|---------|---------|------|
| skill.md | 1 | 1 | 2 |
| skill.yaml | 1 | 1 | 2 |
| modules/*.md | 6 | 7 | 13 |
| scripts/*.sh | 2 | 3 | 5 |
| templates/*.yaml/*.sh.template | 6 | 0 | 6 |
| **总计** | **16** | **12** | **28** |

---

## 错误处理

| 场景 | 处理方式 |
|-----|---------|
| 默认 URL 无法访问 | 提示检查网络或 vLLM-Ascend 文档站点状态 |
| 模型列表提取失败 | 建议手动指定模型教程 URL |
| 脚本块未找到 | 建议手动提供脚本 |
| Docker 不可用（镜像处理） | 提示在有 Docker 的节点执行，或跳过此步骤 |
| 镜像仓库登录失败 | 提示检查镜像仓库地址和认证信息 |
| config.json 不存在 | 提示先运行 vllm-deploy-prepare |
| kubectl 不可用 | 提示安装 kubectl 并配置 kubeconfig |
| K8s 集群连接失败 | 提示检查 kubeconfig 配置和网络连通性 |
| NPU 资源未注册 | 提示检查 Ascend Device Plugin 是否正确安装 |
| Pod 启动失败 | 提示检查镜像、资源和节点状态 |
| 容器内 NPU 映射异常 | 提示检查 Device Plugin 配置 |

---

## 范围界定

本设计覆盖 README.md 中描述的所有 12 个 Phase，分拆为两个 Skill 实现。

**不包含**：
- PD 分离部署模式的高级配置（预留扩展点）
- 自动化 CI/CD 集成
- 多模型并行部署

---

## 下一步

设计批准后，调用 `writing-plans` 技能创建详细实现计划。