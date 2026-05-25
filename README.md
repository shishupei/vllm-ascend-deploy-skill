# vLLM-Ascend Deploy Skill

自动化 vLLM-Ascend 推理服务部署的 Claude Code Skill，从文档解析到 K8s 部署一站式完成。

## 项目简介

本项目是 Claude Code 的技能包，用于在 **Kubernetes + 昇腾 NPU** 环境中自动化部署 vLLM-Ascend 推理服务。它通过解析 vLLM-Ascend 官方文档，自动提取部署脚本和镜像版本，结合 K8s 环境探测，生成可一键执行的 K8s YAML 和部署脚本。

**核心特性：**
- 📚 **文档驱动**：从官方文档自动提取部署参数，无需手动查文档
- 🔍 **环境自适应**：自动探测 K8s 集群、NPU 设备、节点资源
- 🎯 **针对性解析**：只解析用户选择的模型、硬件规格、部署模式
- 📦 **镜像自动化**：拉取官方镜像 → 重打标签 → 推送到私有仓库
- 🛡️ **安全确认点**：关键操作需用户手动确认执行
- 🚀 **多模式支持**：单节点、多节点分布式、PD分离、HA高可用

## 工作流程

整个部署流程分为两个阶段，由两个协作技能完成：

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1-7: 部署准备（vllm-deploy-prepare）                      │
│  执行环境：任意有网络的节点                                       │
├─────────────────────────────────────────────────────────────────┤
│  1. 获取模型列表 → 用户选择模型                                   │
│  2. 选择硬件规格（A3/A2）、部署模式、镜像仓库                      │
│  3. 针对性解析文档（只解析用户选择的配置）                         │
│  4. 处理镜像（拉取→打标签→推送）                                  │
│  5. 交互配置（Namespace、模型路径、性能参数）                      │
│  6. 生成 K8s 模板和启动脚本                                      │
│                                                                 │
│  输出：.vllm-deploy/ 目录                                        │
├─────────────────────────────────────────────────────────────────┤
│  Phase 4-12: 部署执行（vllm-deploy-execute）                     │
│  执行环境：K8s 管理节点                                          │
├─────────────────────────────────────────────────────────────────┤
│  4. K8s 环境探测（节点列表、NPU 数量、硬件规格）                   │
│  7. 填充模板生成完整 YAML                                        │
│  8. 用户确认并执行 kubectl apply                                 │
│  9. 容器内 NPU 探测                                             │
│  10. 生成部署脚本                                                │
│  11. 用户确认并手动执行部署                                       │
│  12. 输出交付                                                    │
│                                                                 │
│  输出：.vllm-deploy/k8s/ 目录                                    │
└─────────────────────────────────────────────────────────────────┘
```

## 支持的部署模式

| 模式 | 描述 | 适用场景 |
|------|------|----------|
| **单节点** | 在单个节点上部署 | 小规模推理、开发测试 |
| **多节点** | 跨多个节点分布式部署 | 大模型推理、高吞吐场景 |
| **PD分离** | Prefill/Decode 节点分离 | 优化推理延迟 |
| **HA高可用** | 主备节点高可用部署 | 生产环境、服务稳定性要求高 |

## 使用方法

### 前置条件

- **Claude Code CLI** 已安装
- **vllm-deploy-prepare 技能** 已安装到 Claude Code
- **vllm-deploy-execute 技能** 已安装到 Claude Code
- Phase 2 执行需要：
  - K8s 管理节点访问权限
  - `kubectl` 已安装并配置
  - Docker 环境（镜像处理步骤）

### 安装技能

将本项目克隆到 Claude Code 的技能目录：

```bash
# 克隆到 Claude Code skills 目录
cd ~/.claude/skills
git clone <repo-url> vllm-deploy-prepare

# 或手动复制
cp -r vllm-deploy-prepare ~/.claude/skills/
cp -r vllm-deploy-execute ~/.claude/skills/
```

### 快速开始

#### Step 1: 部署准备

在任意有网络的节点启动 Claude Code，运行准备技能：

```bash
claude-code
> /vllm-deploy-prepare
```

或直接说：

```
> vllm 部署准备
```

技能会引导您完成：
1. 从 vLLM-Ascend 文档获取模型列表
2. 选择模型（如 GLM-5、Qwen2.5-7B、DeepSeek-V3.1）
3. 选择硬件规格（A3=16卡 或 A2=8卡）
4. 选择部署模式（单节点/多节点/PD分离/HA）
5. 输入私有镜像仓库地址
6. 确认部署参数（Namespace、模型路径等）

完成后生成 `.vllm-deploy/` 目录。

#### Step 2: 部署执行

切换到 K8s 管理节点，启动 Claude Code：

```bash
claude-code
> /vllm-deploy-execute
```

或：

```
> vllm 部署执行
```

技能会：
1. 自动探测 K8s 集群环境
2. 探测各节点 NPU 设备
3. 填充模板生成完整 YAML
4. 生成 `apply-all.sh` 一键部署脚本

**用户需手动确认执行：**
```bash
cd .vllm-deploy/k8s
bash apply-all.sh
```

#### Step 3: 启动 vLLM 服务

Pod 启动后，技能会生成部署脚本。用户需确认并手动执行：

```bash
# 查看生成的部署脚本
cat .vllm-deploy/k8s/deploy.sh

# 确认无误后执行
kubectl exec -n <namespace> <pod-name> -- bash deploy.sh
```

## 输出文件结构

### 部署准备阶段输出

```
.vllm-deploy/
├── config.json          # 用户配置汇总
├── image-info.json      # 镜像信息
├── templates/           # K8s 模板文件
│   ├── single-node.yaml
│   ├── multi-node.yaml
│   ├── pd-separate.yaml
│   └── ha-active-standby.yaml
└── scripts/             # vLLM 启动脚本模板
    ├── start-single-node.sh
    ├── start-multi-node-master.sh
    ├── start-multi-node-worker.sh
    ├── start-prefill.sh
    └── start-decode.sh
```

### 部署执行阶段输出

```
.vllm-deploy/k8s/
├── README.md            # 部署执行指南
├── all.yaml             # 合并的 K8s 资源清单
│   # 或分文件（多节点模式）：
│   ├── master.yaml      # Master Deployment + Service
│   └── worker-*.yaml    # Worker Deployment(s)
├── scripts-configmap.yaml  # Pod 内脚本 ConfigMap
├── apply-all.sh         # 一键部署脚本
├── deploy.sh            # vLLM 启动脚本（Pod 内执行）
└── detection-result.json  # K8s 环境探测结果
```

## 项目结构

```
vllm-ascend-deploy-skill/
├── vllm-deploy-prepare/         # 部署准备技能
│   ├── SKILL.md                 # 技能入口文件
│   ├── modules/                 # 执行模块指南
│   │   ├── model-list-fetcher.md    # 获取模型列表
│   │   ├── user-selector.md         # 用户选择交互
│   │   ├── doc-parser.md            # 文档解析
│   │   ├── image-handler.md         # 镜像处理
│   │   ├── config-guide.md          # 交互配置
│   │   ├── template-generator.md    # 生成模板
│   │   └── deploy-script-generator.md  # 生成启动脚本
│   ├── scripts/                 # 辅助脚本
│   │   ├── fetch-model-list.sh      # 抓取模型列表
│   │   ├── parse-model-doc.sh       # 解析文档
│   │   └── fetch-k8s-config.sh      # 获取 K8s 配置
│   └── templates/               # K8s YAML 模板
│       ├── single-node.yaml         # 单节点部署模板
│       ├── multi-node.yaml          # 多节点部署模板
│       ├── pd-separate.yaml         # PD分离模板
│       └── ha-active-standby.yaml   # HA高可用模板
│
├── vllm-deploy-execute/         # 部署执行技能
│   ├── SKILL.md                 # 技能入口文件
│   ├── modules/                 # 执行模块指南
│   │   ├── k8s-env-detector.md      # K8s 环境探测
│   │   ├── yaml-generator.md        # YAML 生成
│   │   ├── k8s-apply-guide.md       # K8s Apply 指导
│   │   ├── container-env-detector.md # 容器内探测
│   │   ├── deploy-generator.md      # 部署脚本生成
│   │   ├── deploy-execution-guide.md # 部署执行指导
│   │   └── output-guide.md          # 输出交付
│   └── scripts/                 # 辅助脚本
│       ├── detect-k8s-env.sh        # K8s 环境探测
│       ├── detect-container-npu.sh  # 容器内 NPU 探测
│       └── fill-template.sh         # 模板填充
│
├── docs/                        # 设计文档
│   └── superpowers/
│       ├── specs/               # 规格说明
│       └── plans/               # 实现计划
│
└── 原始需求.md                   # 项目原始需求
```

## 安全设计

本技能采用 **确认执行模式**，关键操作需用户手动确认：

| 确认点 | 用户操作 | 原因 |
|--------|----------|------|
| Phase 8 | 执行 `bash apply-all.sh` | K8s apply 影响集群资源 |
| Phase 11 | 在 Pod 内执行 `deploy.sh` | 启动服务影响生产环境 |

**自动执行的安全操作：**
- 文档解析（只读）
- K8s 环境探测（只读）
- 镜像处理（需用户提前 docker login）
- YAML 和脚本生成（本地文件）

## 常见问题

### Q: 技能未识别？

确保技能目录位于 Claude Code 的 skills 目录：
```bash
ls ~/.claude/skills/vllm-deploy-prepare/SKILL.md
ls ~/.claude/skills/vllm-deploy-execute/SKILL.md
```

### Q: K8s 集群连接失败？

检查 kubeconfig：
```bash
kubectl cluster-info
kubectl get nodes
```

### Q: NPU 资源未识别？

确认 Ascend Device Plugin 已安装：
```bash
kubectl get nodes --show-labels | grep ascend
kubectl describe node <node-name> | grep davinci
```

### Q: 镜像推送失败？

提前登录私有仓库：
```bash
docker login harbor.example.com
```

## 技术栈

- **Claude Code Skills** - AI 驱动的自动化框架
- **vLLM-Ascend** - 昇腾 NPU 上的 vLLM 推理引擎
- **Kubernetes** - 容器编排平台
- **Ascend NPU** - 华为昇腾 AI 处理器

## 相关链接

- [vLLM-Ascend 官方文档](https://docs.vllm.com.cn/projects/ascend/en/latest/)
- [Claude Code Skills 文档](https://github.com/anthropics/claude-code)

## 许可证

MIT License