# vLLM-Ascend Deploy Skill

这个仓库不是一个直接执行的部署程序，而是一组给支持 `SKILL.md` 的 AI 代理使用的 Skill。它把 vLLM-Ascend 在 Kubernetes + 昇腾 NPU 环境中的部署过程拆成两个阶段：

- `vllm-deploy-prepare`：做部署前准备
- `vllm-deploy-execute`：在 K8s 管理节点上生成最终 YAML 并指导执行

代理会读取仓库中的 `SKILL.md`、`modules/*.md`、`scripts/*.sh` 和 `templates/*.yaml`，再和用户交互完成模型选择、文档解析、环境探测、模板填充和最终部署。

下面的说明以仓库当前的 `SKILL.md`、脚本和模板的实际行为为准。

## 这个项目是干什么的

它解决的是这样一件事：用户想把 vLLM-Ascend 部署到 Kubernetes 集群里，但官方文档里的模型页面、镜像版本、硬件规格和启动方式比较分散，需要反复查文档、改命令、改 YAML、确认 NPU 资源和节点分配。

这个仓库把这些动作整理成了一个可复用的代理工作流：

- 从 vLLM-Ascend 官方文档抓取模型列表
- 只解析用户选中的模型页面、硬件规格和部署模式
- 可选地做镜像重标记和推送
- 探测 K8s 集群节点、IP 和 NPU 资源
- 根据模板生成最终部署文件
- 在关键步骤要求用户手动确认执行危险操作

它更像“面向 AI 代理的部署流程编排包”，不是普通的命令行工具。

## 适用场景

- 需要在昇腾 NPU 集群上部署 vLLM-Ascend 推理服务
- 希望把“查文档 + 填模板 + 改参数 + 生成脚本”交给代理辅助完成
- 准备阶段和执行阶段可能发生在不同机器上
- 可以接受关键步骤仍由人手动确认，而不是全自动直接执行

## 项目组成

### 1. `vllm-deploy-prepare`

部署准备阶段，适合在有网络的机器上运行。

负责的事情：

- 获取模型列表
- 让用户选择模型、硬件规格、部署模式、镜像仓库
- 解析目标模型文档，提取镜像版本和默认参数
- 可选处理镜像
- 收集部署参数
- 准备模板和中间产物

关键文件：

- `vllm-deploy-prepare/SKILL.md`
- `vllm-deploy-prepare/modules/`
- `vllm-deploy-prepare/scripts/fetch-model-list.sh`
- `vllm-deploy-prepare/scripts/parse-model-doc.sh`
- `vllm-deploy-prepare/templates/`

### 2. `vllm-deploy-execute`

部署执行阶段，必须在有 `kubectl` 和集群访问权限的 K8s 管理节点上运行。

负责的事情：

- 探测集群节点和 NPU 资源
- 根据探测结果填充模板
- 生成最终 YAML、`apply-all.sh`，以及在需要时生成 `deploy.sh`
- 指导用户 `kubectl apply`
- 指导用户在 Pod 内做最终启动

关键文件：

- `vllm-deploy-execute/SKILL.md`
- `vllm-deploy-execute/modules/`
- `vllm-deploy-execute/scripts/detect-k8s-env.sh`
- `vllm-deploy-execute/scripts/fill-template.sh`
- `vllm-deploy-execute/scripts/detect-container-npu.sh`

## 工作流程

整个流程分成两段，中间通过 `.vllm-deploy/` 目录传递上下文。

| 阶段 | Skill | 运行环境 | 主要动作 | 主要输出 |
|------|-------|----------|----------|----------|
| 1 | `vllm-deploy-prepare` | 任意有网络的机器 | 获取模型列表、用户选择、解析文档、可选镜像处理、收集配置、准备模板 | `.vllm-deploy/config.json`、`.vllm-deploy/image-info.json`、`.vllm-deploy/templates/` |
| 2 | `vllm-deploy-execute` | K8s 管理节点 | 探测集群、选择节点、填充模板、生成部署文件、指导 apply 和服务启动 | `.vllm-deploy/detection-result.json`、`.vllm-deploy/selected-nodes.json`、`.vllm-deploy/k8s/` |

### 阶段 1：部署准备

当前仓库中，准备阶段大致按下面顺序工作：

1. 运行 `fetch-model-list.sh`，从 vLLM-Ascend 文档抓模型列表。
2. 通过问答让用户选择：
   - 模型
   - 硬件规格：`A3` 或 `A2`
   - 部署方式：`single_node`、`multi_node`、`pd_separate`、`ha_active_standby`
   - 目标镜像仓库
3. 运行 `parse-model-doc.sh`，只解析用户选中的模型页面和部署模式。
4. 可选处理镜像：拉取官方镜像，重打标签，推送到目标仓库。
5. 收集部署参数，例如：
   - `namespace`
   - `model_path`
   - `max_model_len`
   - `max_num_seqs`
   - `tensor_parallel_size`
6. 准备后续执行需要的模板和配置。

### 阶段 2：部署执行

执行阶段大致按下面顺序工作：

1. 运行 `detect-k8s-env.sh` 检查：
   - `kubectl` 是否存在
   - `kubeconfig` 是否可用
   - 集群是否可连接
   - 哪些节点暴露了 NPU 资源
2. 根据探测结果确认使用哪些节点。
3. 运行 `fill-template.sh` 填充模板，生成：
   - `all.yaml`
   - `master.yaml` / `worker-*.yaml`（多节点时）
   - `apply-all.sh`
   - `deploy.sh`（仅 `single_node` / `multi_node`）
   - `.vllm-deploy/k8s/README.md`
4. 用户手动执行 `bash apply-all.sh`。
5. Pod 启动后，代理继续指导容器内探测和服务启动。

### 人工确认点

这个仓库刻意把高风险动作保留给用户手动确认：

- `kubectl apply` 不会默认自动执行
- `deploy.sh`（仅 `single_node` / `multi_node`）不会默认自动在 Pod 内执行
- 镜像推送依赖用户自己的仓库认证

## 支持的部署模式

仓库当前包含以下模式和模板：

| 模式 | 说明 | 相关模板 |
|------|------|----------|
| `single_node` | 单节点部署 | `single-node.yaml` |
| `multi_node` | Master/Worker 多节点分布式部署 | `multi-node-master.yaml`、`multi-node-worker.yaml` |
| `pd_separate` | Prefill/Decode 分离部署 | `pd-separate.yaml`、`pd-separate-kthena.yaml` |
| `ha_active_standby` | 主备高可用部署 | `ha-active-standby.yaml` |

说明：

- 仓库里还保留了 `multi-node.yaml`，但当前执行脚本 `fill-template.sh` 实际消费的是拆分后的 `multi-node-master.yaml` 和 `multi-node-worker.yaml`。
- `pd_separate` 支持标准 K8s 模板和 Kthena 模板两种变体。

## 怎么使用

### 前置条件

- 你在使用一个支持 `SKILL.md` 的代理环境
- 准备阶段所在机器能访问 vLLM-Ascend 官方文档
- 执行阶段所在机器能访问 Kubernetes 集群
- 执行阶段机器安装了 `kubectl`、`jq` 和 `envsubst`（`gettext` 包）
- 如果要处理镜像，准备阶段机器还需要 `docker`
- 目标节点上已经有模型文件，并且路径可通过 `hostPath` 挂载
- 集群已经正确暴露昇腾 NPU 资源

### 安装

把两个子目录分别安装成两个 Skill。以 Codex 默认目录为例：

```bash
mkdir -p ~/.codex/skills
cp -r vllm-deploy-prepare ~/.codex/skills/
cp -r vllm-deploy-execute ~/.codex/skills/
```

如果你使用的是别的代理，请把这两个目录放到对应的 skills 目录中即可。

### 最短使用路径

1. 在有网络的机器上触发 `vllm-deploy-prepare`。
2. 完成模型、部署模式、镜像仓库和部署参数选择。
3. 得到 `.vllm-deploy/` 目录。
4. 如果执行环境是另一台机器，把 `.vllm-deploy/` 目录带到 K8s 管理节点。
5. 在 K8s 管理节点触发 `vllm-deploy-execute`。
6. 让代理完成环境探测、模板填充和产物生成。
7. 用户手动执行生成的部署脚本和启动脚本。

### 触发方式

根据两个 `SKILL.md` 的定义，触发词是：

- `vllm-deploy-prepare`
- `vllm 部署准备`
- `vllm-deploy-execute`
- `vllm 部署执行`

你的代理如果支持斜杠命令，通常也可以使用：

```text
/vllm-deploy-prepare
/vllm-deploy-execute
```

### 典型执行过程

#### 1. 运行准备阶段

在有网络的机器上触发准备 Skill。代理会依次做这些事：

- 抓模型列表
- 问你选哪个模型
- 问你选 A2 还是 A3
- 问你选哪种部署模式
- 问你镜像仓库地址
- 问你模型路径和性能参数

准备完成后，核心产物通常是：

```text
.vllm-deploy/
├── config.json
├── image-info.json
└── templates/
```

#### 2. 运行执行阶段

切到 K8s 管理节点触发执行 Skill。代理会：

- 检查 `kubectl` 和集群连接
- 列出节点和 NPU 数量
- 让你确认部署节点
- 生成 `.vllm-deploy/k8s/` 下的 YAML 和脚本

常见输出如下：

```text
.vllm-deploy/
├── detection-result.json
├── selected-nodes.json
└── k8s/
    ├── all.yaml
    ├── master.yaml
    ├── worker-*.yaml
    ├── apply-all.sh
    └── README.md
```

单节点、PD 分离或主备模式下，不一定会同时出现 `master.yaml` 和 `worker-*.yaml`。

#### 3. 手动执行部署

生成产物后，用户自己执行：

```bash
cd .vllm-deploy/k8s
bash apply-all.sh
kubectl get pods -n <namespace> -w
```

对于 `single_node` 和 `multi_node`，这里应等待 Pod 进入 `Running`，不要求 `Ready`。因为这两种模式要等你手动执行 `deploy.sh` 后，服务健康检查才会开始通过。

#### 4. 在 Pod 内完成最终启动

当前实现里，`single_node` 和 `multi_node` 模式通常会先把 Pod 拉起来，然后等待用户把 `deploy.sh` 复制进去执行。

典型命令是：

```bash
kubectl exec -n <namespace> <pod-name> -- bash /scripts/detect-npu.sh
kubectl cp deploy.sh -n <namespace> <pod-name>:/tmp/deploy.sh
kubectl exec -n <namespace> <pod-name> -- bash /tmp/deploy.sh
```

如果是多节点模式，Worker Pod 通过模板中的 ray start --address 加入 Ray 集群；deploy.sh 只复制并执行到 Master Pod。

`pd_separate` 和 `ha_active_standby` 模式的模板里已经内嵌了 `vllm serve` 启动命令，因此通常不会生成独立 `deploy.sh`。使用时应以代理当次生成的文件和提示为准。

#### 5. 验证服务

部署成功后，可以用 NodePort 做基本检查：

```bash
curl http://<node-ip>:<node-port>/health
curl http://<node-ip>:<node-port>/v1/models
```

## 产物说明

### `.vllm-deploy/config.json`

准备阶段的核心配置，执行阶段会直接读取它。里面通常会包含：

- 模型名称
- 硬件规格
- 部署模式
- 目标镜像地址
- namespace
- 模型路径
- 性能参数

### `.vllm-deploy/detection-result.json`

执行阶段生成的集群探测结果，包含：

- 节点名
- 节点 IP
- NPU 资源类型
- NPU 数量
- 推荐节点列表

### `.vllm-deploy/k8s/`

最终交付目录，包含：

- 可 apply 的 YAML
- `apply-all.sh`
- `deploy.sh`（仅 `single_node` / `multi_node`）
- 面向最终部署操作的 `README.md`

## 仓库结构

```text
vllm-ascend-deploy-skill/
├── README.md
├── 原始需求.md
├── docs/
│   └── superpowers/
├── vllm-deploy-prepare/
│   ├── SKILL.md
│   ├── modules/
│   ├── scripts/
│   └── templates/
└── vllm-deploy-execute/
    ├── SKILL.md
    ├── modules/
    └── scripts/
```

各目录职责：

- `vllm-deploy-prepare/`：准备阶段的技能定义、解析脚本和模板来源
- `vllm-deploy-execute/`：执行阶段的技能定义和模板填充脚本
- `docs/superpowers/`：设计、计划和审查文档
- `原始需求.md`：最初的项目需求描述

## 这个项目不负责什么

- 不负责安装 Kubernetes
- 不负责安装 Ascend 驱动或 Device Plugin
- 不负责准备模型文件本身
- 不保证无人工介入的一键上线
- 不替代你对生成 YAML 和启动命令的最终审查

## 相关文件入口

- `vllm-deploy-prepare/SKILL.md`
- `vllm-deploy-execute/SKILL.md`
- `vllm-deploy-prepare/scripts/fetch-model-list.sh`
- `vllm-deploy-prepare/scripts/parse-model-doc.sh`
- `vllm-deploy-execute/scripts/detect-k8s-env.sh`
- `vllm-deploy-execute/scripts/fill-template.sh`

## 参考链接

- vLLM-Ascend 文档：<https://docs.vllm.com.cn/projects/ascend/en/latest/>
