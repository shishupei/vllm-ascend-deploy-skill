# vLLM Deploy Skill 检视意见

日期：2026-06-03

审查对象：

- 分支：`master`
- HEAD：`9d4a290370c05a0f13e858553700d5d545654776`
- 审查范围：当前工作区未提交改动
- 需求真源：`原始需求.md`

## 范围

本次检视聚焦当前工作区相对 `HEAD` 的改动，重点检查：

- `vllm-deploy-execute/scripts/fill-template.sh` 的模板填充和输出契约
- `vllm-deploy-prepare/templates/*.yaml` 的 K8s 可应用性
- `vllm-deploy-execute/modules/*.md`、`README.md` 与真实生成物是否一致
- 原始需求中 Phase 8-11 的用户执行链路是否仍可走通

## 结论

当前改动仍不满足合并条件。

与上一版检视相比，以下问题已有明显改善：

- `multi_node` 的执行侧已改为读取 `multi-node-master.yaml` 和 `multi-node-worker.yaml`
- `selected-nodes.json` 字符串数组格式的入口解析已改为类型判断
- 生成的 `.vllm-deploy/k8s/README.md` 已补充 `kubectl cp deploy.sh` 和 `kubectl exec` 步骤

但当前仍有两个阻断级问题：

1. K8s 资源名直接拼接原始模型名，示例模型名含大写和点号，`kubectl apply` 会因资源名不满足 Kubernetes 命名约束而失败。
2. 原始需求要求 Phase 10 根据容器内 NPU 探测结果生成 `deploy.sh`，当前实现仍在模板填充阶段提前生成脚本，且 `--tensor-parallel-size` 只来自 `config.json`。

另有若干重要问题会继续误导代理或用户操作。

## 发现的问题

### Critical

1. K8s 资源名直接使用原始 `selected_model`，常见模型名会生成非法资源名

参考：

- `原始需求.md:32`
- `原始需求.md:33`
- `原始需求.md:34`
- `原始需求.md:59`
- `vllm-deploy-execute/scripts/fill-template.sh:82`
- `vllm-deploy-prepare/templates/single-node.yaml:52`
- `vllm-deploy-prepare/templates/multi-node-master.yaml:58`
- `vllm-deploy-prepare/templates/multi-node-worker.yaml:9`
- `vllm-deploy-prepare/templates/pd-separate.yaml:62`
- `vllm-deploy-prepare/templates/pd-separate.yaml:183`
- `vllm-deploy-prepare/templates/ha-active-standby.yaml:54`
- `vllm-deploy-prepare/templates/ha-active-standby.yaml:187`
- `vllm-deploy-prepare/templates/ha-active-standby.yaml:219`
- `vllm-deploy-prepare/templates/pd-separate-kthena.yaml:27`
- `vllm-deploy-prepare/templates/pd-separate-kthena.yaml:265`
- `vllm-deploy-prepare/templates/pd-separate-kthena.yaml:291`

问题：

- 原始需求和准备阶段示例里的模型名包括 `GLM-5`、`Qwen2.5-7B`、`DeepSeek-V3.1`。
- `fill-template.sh` 将 `config.json.selected_model` 原样导出为 `MODEL_NAME`。
- 多个模板把 `${MODEL_NAME}` 直接拼进 `metadata.name`，例如 `vllm-${MODEL_NAME}`、`vllm-${MODEL_NAME}-master`、`${MODEL_NAME}-server`。
- Kubernetes 资源名通常要求 DNS-1123 风格的小写名称；上述示例会生成包含大写字母的资源名，`kubectl apply` 阶段会被 API 校验拦截。

影响：

- 用户按当前主流程选择 `GLM-5` 或 `Qwen2.5-7B` 后，生成的 YAML 无法可靠 apply。
- 这会阻断 Phase 8，后续 Phase 9-11 无法开始。

建议：

- 增加独立的 K8s 安全名称变量，例如 `MODEL_RESOURCE_NAME` 或 `APP_NAME`。
- 该变量应由 `selected_model` 规范化得到：小写、非法字符替换为 `-`、去除首尾 `-`、必要时截断。
- `metadata.name`、固定 label selector、README 中的 `kubectl get -l ...` 使用规范化变量。
- `vllm serve --served-model-name` 保留原始模型名，避免改变 API 暴露的模型名称。

2. Phase 9 容器内探测结果仍未进入 Phase 10，`deploy.sh` 不是按原始需求生成

参考：

- `原始需求.md:249`
- `原始需求.md:253`
- `原始需求.md:256`
- `原始需求.md:257`
- `vllm-deploy-execute/modules/container-env-detector.md:23`
- `vllm-deploy-execute/modules/container-env-detector.md:61`
- `vllm-deploy-execute/modules/deploy-generator.md:9`
- `vllm-deploy-execute/modules/deploy-generator.md:11`
- `vllm-deploy-execute/modules/deploy-generator.md:12`
- `vllm-deploy-execute/scripts/fill-template.sh:86`
- `vllm-deploy-execute/scripts/fill-template.sh:88`
- `vllm-deploy-execute/scripts/fill-template.sh:269`
- `vllm-deploy-execute/scripts/fill-template.sh:283`
- `vllm-deploy-execute/scripts/fill-template.sh:285`

问题：

- 原始需求写明 Phase 10 输入是“容器内探测结果 + 用户配置”，并要求根据容器内 NPU 数量设置 `--tensor-parallel-size`。
- 当前 `deploy.sh` 在 `fill-template.sh` 中生成，发生在 Phase 7 模板填充阶段，而不是 Phase 9 容器内探测之后。
- `deploy.sh` 中的 `--tensor-parallel-size` 使用 `${TENSOR_PARALLEL_SIZE}`，该变量来自 `config.json`，没有读取 `/scripts/detect-npu.sh` 或 Phase 9 输出。
- `deploy-generator.md` 也已改成只列出 `config.json` 和 `detection-result.json`，不再列出容器内探测结果。

影响：

- 如果容器内实际可见 NPU 数量和配置值不一致，生成脚本仍会用旧配置启动。
- Phase 9 在当前链路里只剩“人工观察”价值，没有对 Phase 10 的生成结果产生约束。
- 这与 `原始需求.md` 的 Phase 9 -> Phase 10 数据闭环不一致。

建议：

- 如果原始需求仍有效，应把 `deploy.sh` 的生成移动到容器内探测之后，或至少让脚本读取保存下来的容器探测 JSON。
- 如果决定废弃该闭环，应同步修改 `原始需求.md`、`container-env-detector.md`、`deploy-generator.md` 和 README，明确 Phase 9 只做诊断不参与脚本参数生成。

### Important

1. 多节点文档要求在每个 Worker Pod 内执行同一份 `deploy.sh`，与 Ray Worker 的职责边界冲突

参考：

- `README.md:271`
- `README.md:273`
- `README.md:275`
- `vllm-deploy-execute/modules/deploy-execution-guide.md:36`
- `vllm-deploy-execute/modules/deploy-execution-guide.md:45`
- `vllm-deploy-execute/modules/deploy-execution-guide.md:47`
- `vllm-deploy-execute/modules/deploy-generator.md:51`
- `vllm-deploy-execute/modules/deploy-generator.md:60`
- `vllm-deploy-execute/scripts/fill-template.sh:272`
- `vllm-deploy-execute/scripts/fill-template.sh:283`
- `vllm-deploy-execute/scripts/fill-template.sh:288`
- `vllm-deploy-prepare/templates/multi-node-worker.yaml:45`
- `vllm-deploy-prepare/templates/multi-node-worker.yaml:46`
- `vllm-deploy-prepare/templates/multi-node-worker.yaml:49`

问题：

- Worker 模板已经在容器启动命令中执行 `ray start --address=...`，然后 `tail -f /dev/null`。
- 生成的多节点 `deploy.sh` 是完整的 `vllm serve ... --distributed-executor-backend ray --port 8000`。
- README 和模块文档要求把同一份 `deploy.sh` 先后复制到 Master 和每个 Worker Pod 内执行。
- 这意味着每个 Worker 都会再启动一份 vLLM API server/engine，而不是只作为 Ray worker 提供资源。

影响：

- 在真实多节点 Ray 部署中，这很可能导致重复服务进程、资源竞争，或多个 Pod 同时尝试调度同一 Ray 集群资源。
- 当前没有真实集群验证证明“每个 worker 都执行同一份 `vllm serve`”是 vLLM-Ray 的正确操作模型。

建议：

- 明确多节点启动契约：通常应由 Worker Pod 加入 Ray 集群，`vllm serve` 只在 Master/Head 上执行一次。
- 如果确实需要 Worker 执行不同脚本，应生成 `deploy-master.sh` 和 `deploy-worker.sh`，不要让所有 Pod 执行同一份完整 API server 脚本。
- 在有 K8s + NPU 的真实环境中补充多节点端到端验证。

2. `envsubst` 成为执行阶段硬依赖，但前置条件和错误处理没有声明

参考：

- `README.md:151`
- `README.md:156`
- `vllm-deploy-execute/SKILL.md:8`
- `vllm-deploy-execute/SKILL.md:11`
- `vllm-deploy-execute/scripts/fill-template.sh:4`
- `vllm-deploy-execute/scripts/fill-template.sh:118`

问题：

- 当前模板填充从 `sed` 改为 `envsubst`。
- README 的执行阶段前置条件只写了 `kubectl` 和 `jq`。
- `vllm-deploy-execute/SKILL.md` 前置条件只写了 `kubectl` 和 kubeconfig。
- 脚本没有在开头检查 `envsubst` 是否存在。

影响：

- 在没有安装 `gettext`/`envsubst` 的 K8s 管理节点上，Phase 7 会直接 `command not found`。
- 用户会以为前置条件满足，却在模板填充中断。

建议：

- 在 `fill-template.sh` 开头增加 `command -v envsubst` 检查和明确报错。
- README 与 `vllm-deploy-execute/SKILL.md` 增加 `envsubst` 或 `gettext` 依赖说明。

3. Phase 8 apply 指导仍展示旧文件名，和当前生成物不一致

参考：

- `vllm-deploy-execute/modules/k8s-apply-guide.md:29`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:30`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:31`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:32`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:33`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:41`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:42`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:45`
- `vllm-deploy-execute/modules/yaml-generator.md:75`
- `vllm-deploy-execute/modules/yaml-generator.md:80`
- `vllm-deploy-execute/scripts/fill-template.sh:212`
- `vllm-deploy-execute/scripts/fill-template.sh:213`
- `vllm-deploy-execute/scripts/fill-template.sh:325`

问题：

- 当前脚本生成并 apply 的核心文件是 `all.yaml`。
- 多节点额外生成 `master.yaml` 和 `worker-*.yaml`，但 `apply-all.sh` 仍只执行 `kubectl apply -f all.yaml`。
- `k8s-apply-guide.md` 的指导输出仍列出 `namespace.yaml`、`configmap.yaml`、`deployment*.yaml`、`service.yaml`，并提供这些旧文件的手动 apply 命令。

影响：

- 代理按该模块提示用户时，会给出不存在的文件名。
- 用户如果选择“手动 apply”路径，会在 Phase 8 直接失败。

建议：

- 将 Phase 8 指导输出改为以 `all.yaml` 为主。
- 手动 apply 备选方案应是 `kubectl apply -f all.yaml`，多节点分文件只作为调试查看对象，不作为默认 apply 路径。

### Medium

1. `deploy-generator.md` 已被改成“按模式生成脚本”，但执行链路实际仍由 `fill-template.sh` 生成脚本

参考：

- `vllm-deploy-execute/modules/deploy-generator.md:43`
- `vllm-deploy-execute/modules/deploy-generator.md:47`
- `vllm-deploy-execute/scripts/fill-template.sh:269`
- `vllm-deploy-execute/scripts/fill-template.sh:312`
- `vllm-deploy-execute/scripts/fill-template.sh:313`

问题：

- `deploy-generator.md` 描述 Phase 10 负责“生成脚本到 `.vllm-deploy/k8s/`”。
- 实际脚本生成逻辑已经在 Phase 7 的 `fill-template.sh` 内完成。

影响：

- 模块边界和真实实现不一致，后续维护时容易继续把 Phase 10 写成独立生成步骤。
- 这也是 Phase 9 探测结果无法参与 Phase 10 的直接原因之一。

建议：

- 要么把脚本生成从 `fill-template.sh` 拆回 Phase 10。
- 要么把 `deploy-generator.md` 改成“展示并校验已生成脚本”，并明确不会重新生成。

## 已执行验证

本次已执行：

- `git status --short --branch`
- `git diff --stat`
- `git diff --name-status`
- 审阅 `README.md`
- 审阅 `原始需求.md`
- 审阅 `vllm-deploy-execute/SKILL.md`
- 审阅 `vllm-deploy-execute/modules/k8s-apply-guide.md`
- 审阅 `vllm-deploy-execute/modules/container-env-detector.md`
- 审阅 `vllm-deploy-execute/modules/deploy-generator.md`
- 审阅 `vllm-deploy-execute/modules/deploy-execution-guide.md`
- 审阅 `vllm-deploy-execute/modules/yaml-generator.md`
- 审阅 `vllm-deploy-execute/scripts/fill-template.sh`
- 审阅 `vllm-deploy-execute/scripts/detect-container-npu.sh`
- 审阅 `vllm-deploy-execute/scripts/detect-k8s-env.sh`
- 审阅 `vllm-deploy-prepare/templates/*.yaml` 的关键改动
- 执行 `bash -n` 检查当前改动涉及的 shell 脚本语法
- 执行 `command -v envsubst`，确认当前审查环境存在 `/usr/bin/envsubst`
- 执行 `command -v kubectl`，当前审查环境未安装 `kubectl`
- 使用 `rg` 交叉检查 `${MODEL_NAME}`、`envsubst`、输出文件名和 Phase 8-11 文档口径

本次未执行：

- 真实 K8s 集群 `kubectl apply`
- Kubernetes API server 对生成 YAML 的服务端校验
- Pod 内真实 `/scripts/detect-npu.sh` 执行
- vLLM-Ray 多节点真实启动验证
- 昇腾 NPU 设备挂载验证

## 建议的下一步

1. 先修复 K8s 安全资源名问题，引入原始模型名和资源名两个变量。
2. 决定是否保留原始需求中的 Phase 9 -> Phase 10 数据闭环：
   - 保留：把 `deploy.sh` 生成移动到容器探测之后，并消费探测结果。
   - 废弃：同步修改原始需求和所有 Phase 9/10 文档。
3. 重新确认多节点 vLLM-Ray 启动模型，避免在所有 Worker 上执行同一份完整 `vllm serve`。
4. 补齐 `envsubst` 依赖检查和文档前置条件。
5. 更新 `k8s-apply-guide.md`，删除旧的 `namespace.yaml/configmap.yaml/deployment.yaml/service.yaml` 手动 apply 指导。

## 评估

Ready to merge：**No**

Reasoning：

当前改动已经修复了上一轮中的部分契约漂移，但仍存在会阻断 `kubectl apply` 的资源命名问题，以及原始需求定义的容器探测到脚本生成的数据闭环缺失。多节点启动步骤也需要真实环境验证或架构修正后再进入合并。

## 2026-06-03 修复验证更新

本轮已修复：

- K8s 资源名规范化
- Phase 9 容器探测结果进入 Phase 10 `deploy.sh` 生成
- 多节点 `deploy.sh` 改为 Master Pod 专用
- `envsubst` / `jq` / `kubectl` 依赖声明和脚本检查
- Phase 8-10 文档口径统一

本轮已执行：

- `bash -n vllm-deploy-prepare/scripts/*.sh vllm-deploy-execute/scripts/*.sh`
- `bash tests/run-local-verification.sh`
- 生成物未替换变量扫描
- 旧文件名和旧多节点执行指令扫描

仍未执行：

- 真实 K8s 集群 `kubectl apply`
- 真实 Pod 内 NPU 探测
- 真实 vLLM-Ray 多节点启动
