# vLLM-Ascend Deploy Skill

一套面向 AI 代理的 vLLM-Ascend 部署技能包，将昇腾 NPU + Kubernetes 环境下的模型部署过程编排为可复用的自动化工作流。

## 这是什么

本仓库不是传统的命令行工具或部署程序，而是一组遵循 `SKILL.md` 规范的 AI 代理技能（Skill）。代理通过读取仓库中的技能定义、模块文档、Shell 脚本和 YAML 模板，与用户交互完成以下工作：

- 从 vLLM-Ascend 官方文档自动抓取模型列表
- 解析用户选定模型的硬件规格和启动参数
- 探测 Kubernetes 集群的节点和 NPU 资源
- 根据模板生成可直接 apply 的 K8s 部署文件
- 提取和分析昇腾 NPU 运行时日志，诊断故障根因

它解决的核心痛点是：官方文档中的模型页面、镜像版本、硬件规格和启动方式分散在各处，手动查文档、改 YAML、确认 NPU 资源的过程繁琐且容易出错。本仓库将这些动作整理为代理可执行的标准化流程。

## 技能概览

仓库包含三个独立的 Skill，覆盖部署全生命周期：

| Skill | 用途 | 运行环境 |
|-------|------|----------|
| `vllm-deploy-prepare` | 部署准备：获取模型列表、解析文档、处理镜像、生成配置 | 任意有网络的机器 |
| `vllm-deploy-execute` | 部署执行：探测 K8s 环境、填充模板、生成 YAML、指导 apply | K8s 管理节点 |
| `vllm-log-analyze` | 日志诊断：提取昇腾 plog 日志、预筛错误模式、AI 诊断根因 | 可访问 plog 路径的节点 |

前两个 Skill 是一条流水线的上下半段，中间通过 `.vllm-deploy/` 目录衔接。第三个 Skill 可独立使用，也可在部署出问题后单独调用。

## 支持的部署模式

| 模式 | 说明 | 关键特性 |
|------|------|----------|
| `single_node` | 单节点部署 | 一个 Deployment，手动执行 deploy.sh 启动服务 |
| `multi_node` | Master/Worker 多节点分布式 | Ray 集群，Master 启动 head，Worker 自动加入 |
| `pd_separate` | Prefill/Decode 分离 | KV Cache 传输，Prefill 和 Decode 独立扩缩容 |
| `ha_active_standby` | 主备高可用 | 多副本 + PodDisruptionBudget + 反亲和性调度 |

不同模式对应不同的模板文件：

- `single_node` → `single-node.yaml`
- `multi_node` → `multi-node-master.yaml` + `multi-node-worker.yaml`
- `pd_separate` → `pd-separate.yaml` / `pd-separate-kthena.yaml`
- `ha_active_standby` → `ha-active-standby.yaml`

## 快速开始

### 环境要求

| 阶段 | 依赖 |
|------|------|
| 准备 | 能访问 `docs.vllm.com.cn` 的网络；`jq`；可选 `docker`（镜像处理） |
| 执行 | K8s 集群（已安装 Ascend Device Plugin）；`kubectl`、`jq`、`envsubst`；目标节点已部署昇腾驱动和固件；模型文件已就位 |
| 日志分析 | 可访问昇腾驱动日志目录（默认 `/usr/local/Ascend/driver/log`）；`jq`、`awk` |

### 安装

将子目录安装为代理的 Skill。以 Claude Code 为例：

```bash
mkdir -p ~/.claude/skills
cp -r vllm-deploy-prepare ~/.claude/skills/
cp -r vllm-deploy-execute ~/.claude/skills/
cp -r vllm-log-analyze ~/.claude/skills/
```

其他代理平台请将目录放到对应的 skills 路径。

### 使用

| Skill | 触发方式 |
|-------|----------|
| vllm-deploy-prepare | `/vllm-deploy-prepare` 或 `vllm 部署准备` |
| vllm-deploy-execute | `/vllm-deploy-execute` 或 `vllm 部署执行` |
| vllm-log-analyze | `/vllm-log-analyze` 或 `vllm 日志分析` |

典型流程：先在有网络的机器上触发 `/vllm-deploy-prepare` 完成准备，将生成的 `.vllm-deploy/` 目录带到 K8s 管理节点，再触发 `/vllm-deploy-execute` 完成部署。详细步骤见 [使用手册](docs/USER_GUIDE.md)。

## 仓库结构

```
vllm-ascend-deploy-skill/
├── README.md
├── docs/
│   ├── USER_GUIDE.md                  # 详细使用手册
│   └── superpowers/                   # 设计文档和审查记录
├── tests/                             # 测试用例和验证脚本
├── vllm-deploy-prepare/               # 部署准备 Skill
│   ├── SKILL.md
│   ├── modules/                       # 模块文档
│   ├── scripts/                       # 可执行脚本
│   └── templates/                     # K8s YAML 模板
├── vllm-deploy-execute/               # 部署执行 Skill
│   ├── SKILL.md
│   ├── modules/
│   └── scripts/
└── vllm-log-analyze/                  # 日志分析 Skill
    ├── SKILL.md
    ├── modules/
    ├── scripts/
    ├── knowledge/                     # 昇腾错误模式知识库
    └── templates/
```

## 设计原则

- **安全优先：** 使用 `envsubst` 而非 `sed` 进行模板填充，避免注入风险；使用 `jq --arg` 机制查询 JSON，防止变量注入
- **人工把关：** `kubectl apply` 和 Pod 内启动命令均需用户手动确认
- **环境适配：** 自动探测集群 NPU 资源，智能推荐部署节点
- **错误可诊断：** 内置昇腾 NPU 7 大类错误模式知识库，支持自动化日志分析和根因定位
- **产物可校验：** `validate-generated.sh` 自动检查生成产物的完整性和正确性

## 不负责什么

- 不负责安装 Kubernetes 集群
- 不负责安装昇腾驱动、固件或 Ascend Device Plugin
- 不负责准备模型文件本身
- 不保证零人工介入的一键上线
- 不替代你对生成 YAML 和启动命令的最终审查

## 参考链接

- vLLM-Ascend 官方文档：<https://docs.vllm.com.cn/projects/ascend/en/latest/>
- 详细使用手册：[docs/USER_GUIDE.md](docs/USER_GUIDE.md)
