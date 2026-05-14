# vLLM-Deploy Skill 设计说明

## 目标

以当前的 [README.md](/home/shishupei/app/vllm-skill/README.md) 作为唯一事实来源，重建 `vllm-deploy` skill 包，并确保该 skill 同时可被 Codex 和 Claude Code 使用。

## 范围

本设计覆盖 README 中描述的整套 skill 产物：

- Skill 入口文档与元数据
- 按 Phase 划分的模块说明文档
- 辅助 shell 脚本
- 用于生成部署产物的 YAML 与 shell 模板

本次工作不做以下扩展：

- 不添加超出 README 的新行为
- 不引入新的运行时依赖
- 不为了“生产级网页抓取”去扩展复杂实现，只提供可靠的最小 shell 方案

## 交付物

重建后的包将包含以下内容：

- `SKILL.md`，作为跨 agent 的主入口
- `skill.md` 和 `skill.yaml`，用于兼容 README 中约定的结构
- `modules/` 目录，包含 12 个 phase 指南文件
- `scripts/` 目录，包含 5 个可执行 shell 辅助脚本
- `templates/` 目录，包含 6 个模板文件
- `docs/superpowers/plans/` 目录下的实现计划文档，在本设计获批后创建

## 架构

整个 skill 包分为四层。

### 1. 入口层

入口层负责让 skill 能被不同 agent 运行时发现和理解。

- `SKILL.md` 是面向 Codex 风格 skill 加载方式的主入口。
- `skill.md` 保留与 README 一致的操作说明，兼容文档和可能依赖该命名的环境。
- `skill.yaml` 提供最小元数据，保持与 README 目录结构一致。

入口内容需要明确说明：

- 什么时候使用该 skill
- 需要什么执行环境
- 12 个 phase 的完整流程
- 每个 phase 会用到哪些模块、脚本和模板
- 哪些动作需要用户确认，例如 `kubectl apply` 和容器内部署脚本执行

### 2. 模块层

`modules/` 下每个文件对应 README 中的一个 phase。12 个模块文件统一采用相同结构，便于 agent 连续消费：

- 目的
- 输入
- 执行位置
- 步骤
- 输出
- 失败处理
- 关联脚本或模板

这样既能保持 skill 的可读性，也能严格保留 README 中定义的 phase 顺序：

1. `model-list-fetcher.md`
2. `user-selector.md`
3. `doc-parser.md`
4. `k8s-env-detector.md`
5. `image-handler.md`
6. `config-guide.md`
7. `k8s-yaml-generator.md`
8. `k8s-apply-guide.md`
9. `container-env-detector.md`
10. `deploy-generator.md`
11. `deploy-execution-guide.md`
12. `output-guide.md`

### 3. 脚本层

`scripts/` 下每个脚本都是独立的 Bash CLI，统一具备以下特征：

- 支持 `--help`
- 显式参数校验
- 失败时返回非 0 退出码
- 输出结构化结果，便于 agent 消费

脚本实现坚持“最小依赖、能明确失败”的原则。它们在常见 shell 工具存在时可以执行任务；当环境前置条件不满足时，需要给出清晰错误。

各脚本的职责如下：

- `fetch-model-list.sh`：抓取模型索引页，提取模型名称和链接
- `parse-model-doc.sh`：抓取选定模型页面，提取部署脚本块、镜像引用和参数提示
- `detect-k8s-env.sh`：探测集群连通性、节点列表、节点 IP 以及 NPU 相关信号
- `detect-container-npu.sh`：探测目标 Pod 中映射的 NPU 设备并汇总结果
- `push-image.sh`：校验镜像参数，并执行拉取、重打标签、推送到目标仓库

涉及网络访问或集群变更的步骤会保持显式表达。脚本本身可以执行 README 中描述的动作，但 skill 文档仍然保留 README 要求的用户确认节点。

### 4. 模板层

`templates/` 下的模板统一使用 `${VAR}` 占位符，并严格对应 README 中定义的替换参数。

模板集合如下：

- `k8s-namespace.yaml`
- `k8s-configmap.yaml`
- `k8s-deployment.yaml`
- `k8s-service.yaml`
- `deploy.sh`
- `apply-all.sh`

模板需要覆盖 README 中描述的三种部署模式：

- 单节点
- 多节点
- PD 分离

模式差异通过模板变量和生成说明表达，而不是拆成多套模板树，以保持包体结构稳定、可预测。

## 兼容策略

该 skill 需要在不破坏 README 既有目录结构的前提下，同时兼容 Codex 和 Claude Code 的使用方式。

- `SKILL.md` 使用标准 skill frontmatter，并直接引用各模块文件。
- `skill.md` 保留，作为 README 约定结构的兼容入口，并与主入口保持一致语义。
- `skill.yaml` 提供简单元数据，兼容依赖独立 YAML 描述的生态。

三份文件在语义上保持一致，但 `SKILL.md` 作为 agent 执行指引的主来源。

## 运行边界

该 skill 的目标运行位置是具备集群访问能力的 Kubernetes 管理节点。文档中需要明确以下前置条件：

- 集群探测和工作负载操作依赖 `kubectl`
- 镜像处理依赖 Docker
- 某些路径必须保留人工确认或人工执行，尤其是应用 YAML 和在 Pod 内执行最终部署脚本

重建后的 skill 必须保留 README 的阶段式交互模型，不能把这些用户确认节点静默吞掉。

## 错误处理

README 已经定义了主要失败场景。重建后的包要在两个层面保留这些约束：

- 模块文档负责说明 agent 在每类失败下应该如何响应
- 脚本负责对缺失工具、缺失参数、连接失败、解析失败或不支持状态返回清晰错误

这样文档和脚本的职责是闭环的：文档给流程决策，脚本给执行信号。

## 测试策略

本次重建至少在三个层面做验证。

### 文档结构

验证预期文件是否存在，以及 phase 映射是否与 README 完全一致。

### 脚本接口

验证每个脚本都满足：

- 具有可执行权限
- `--help` 能输出用法
- 缺失必填参数时会以非 0 退出

### 模板完整性

验证每个模板文件都存在，并且包含 README 为该模板定义的关键占位符。

## 非目标

本次重建不会做以下事情：

- 不增加 Python 或第三方解析依赖
- 不承诺完美解析所有上游文档格式
- 不引入 README 之外的新 phase 或替代流程
- 不把 skill 包改造成一个脱离 skill 结构的独立应用

## 实施说明

当前仓库只保留了 README，而此前已被 git 跟踪的实现文件在工作树中已删除。因此“从头重建”意味着：

- 保留 git 已有的目录布局
- 不把旧实现内容当作事实来源
- 以 README 和本设计文档作为所有重建文件的规格来源

## 成功标准

当满足以下条件时，可认为本设计被正确实现：

- 仓库中重新具备 README 描述的完整文件集合
- skill 入口可同时被 Codex 和 Claude Code 使用
- 12 个 phase 都有清晰、可消费的模块说明
- 5 个脚本都暴露出可用的 CLI 接口
- 6 个模板都包含与 README 对齐的占位符
- 整个包读起来是完整、可执行的 skill，而不是半成品脚手架
