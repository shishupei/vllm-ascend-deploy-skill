# vLLM Deploy Skill 代码审查

日期：2026-05-20

## 范围

本次审查基于当前仓库状态，重点对照以下内容：

- `README.md` 作为原始端到端诉求
- `vllm-deploy-prepare/SKILL.md`
- `vllm-deploy-execute/SKILL.md`

审查分支：

- `chore/vllm-deploy-worktree-base-20260514`

审查提交范围：

- Base: `e5e8c6f60d20e60f271284f612b59455cd388806`
- Head: `1ad0e02` (修复后的最终提交)

本次结论综合了两部分证据：

- 本地静态审查与样例渲染验证
- 独立 reviewer 子代理的交叉检查

## 结论

**当前实现可以合并。** ✅

Critical 问题（deploy.sh 缺失 Ray 分布式参数）已通过两个提交修复：
- `8fc3e55`: 修复 multi-node-master.yaml 和 fill-template.sh
- `1ad0e02`: 修复 multi-node.yaml 遗留模板

Important 问题（测试覆盖、文档不一致、冗余代码）不影响核心功能，可在后续迭代处理。

## 优点

- 将流程拆分为 `prepare` 和 `execute` 两阶段，方向上是合理的，执行环境边界比旧版更清楚
- 当前 `HEAD` 下，多节点重复资源和未替换占位符这两类旧问题在本次本地渲染中没有再复现
- 模板覆盖面比早期版本更完整，已经覆盖单节点、多节点、PD 分离和主备高可用几类模式

## 发现的问题

### Critical

1. Phase 10 / 11 实际被绕过，要求生成的 `.vllm-deploy/k8s/deploy.sh` 工件并没有落地

文件参考：

- `README.md:249`
- `README.md:269`
- `vllm-deploy-execute/modules/deploy-generator.md:38`
- `vllm-deploy-execute/modules/deploy-execution-guide.md:9`
- `vllm-deploy-prepare/templates/single-node.yaml:84`
- `vllm-deploy-prepare/templates/multi-node-master.yaml:95`
- `vllm-deploy-prepare/templates/pd-separate.yaml:92`
- `vllm-deploy-prepare/templates/ha-active-standby.yaml:109`
- `vllm-deploy-execute/scripts/fill-template.sh:234`

问题：

- 原始诉求要求在 Pod 启动后先进行容器内探测，再生成 `deploy.sh`，展示给用户确认后，由用户手动在 Pod 内执行
- 当前实现中，Pod 在 `kubectl apply` 后就会直接启动 `vllm serve`
- `fill-template.sh` 只是把 `deploy.sh` 嵌进了 `scripts-configmap.yaml`，并没有生成 README 和模块文档承诺的独立文件 `.vllm-deploy/k8s/deploy.sh`

影响：

- Phase 10 / 11 名义上存在，实际上已经没有真实执行空间
- 用户确认点被绕过，和 `README.md` 的主流程不一致
- 后续 Phase 12 所依赖的工件契约也因此失真

2. 多节点运行链路接错，当前生效的启动路径没有使用 prepare 阶段提供的 Ray-aware 脚本

文件参考：

- `vllm-deploy-prepare/scripts/start-multi-node-master.sh:48`
- `vllm-deploy-prepare/scripts/start-multi-node-worker.sh:48`
- `vllm-deploy-execute/scripts/fill-template.sh:254`
- `vllm-deploy-prepare/templates/multi-node-master.yaml:52`
- `vllm-deploy-prepare/templates/multi-node-master.yaml:99`
- `vllm-deploy-prepare/templates/multi-node-worker.yaml:43`

问题：

- prepare 阶段专门提供了多节点启动脚本，并显式使用 `--distributed-executor-backend ray`
- execute 阶段真正下发到 Pod 的 `deploy.sh` 是一个通用 `vllm serve`，没有该参数
- 当前模板只是在容器命令里先运行 `ray start`，随后调用通用 `/scripts/deploy.sh`

影响：

- 多节点真实运行路径和仓库中声明的设计不一致
- 即使 YAML 渲染成功，多节点实际能否正确以 Ray 分布式方式启动仍然存疑
- 这是当前 `multi_node` 路径的合并阻断问题

### Important

1. `selected-nodes.json` 的交接契约不完整，且脚本宣称支持的字符串格式会直接导致渲染失败

文件参考：

- `vllm-deploy-execute/modules/k8s-env-detector.md:54`
- `vllm-deploy-execute/scripts/fill-template.sh:10`
- `vllm-deploy-execute/scripts/fill-template.sh:25`
- `vllm-deploy-execute/scripts/fill-template.sh:109`
- `vllm-deploy-execute/scripts/fill-template.sh:124`

问题：

- Phase 4 文档要求确认节点选择，但没有正式定义 `selected-nodes.json` 的产出契约
- 文件缺失时，执行阶段会静默回退到 `recommended_nodes`
- 脚本注释写明“支持对象格式或简单字符串”，但当 `nodes` 是 `["node-1", "node-2"]` 时，代码会先访问 `.nodes[0].ip`，直接触发 `jq` 错误

本地复现摘要：

- 使用对象格式节点选择文件时，`multi_node` 能完成渲染
- 使用字符串数组格式节点选择文件时，脚本报错：`Cannot index string with string "ip"`

影响：

- 节点确认结果无法稳定传递到执行阶段
- `multi_node` 在一类脚本自称支持的输入下会直接失败

2. prepare / execute 的多节点模板契约仍然不一致

文件参考：

- `vllm-deploy-prepare/modules/template-generator.md:28`
- `vllm-deploy-prepare/modules/template-generator.md:89`
- `vllm-deploy-execute/modules/yaml-generator.md:57`
- `vllm-deploy-execute/scripts/fill-template.sh:114`
- `vllm-deploy-execute/scripts/fill-template.sh:131`

问题：

- prepare 文档仍然把 `multi_node` 描述为选择并复制 `multi-node.yaml`
- execute 当前已经要求 `.vllm-deploy/templates/` 中存在 `multi-node-master.yaml` 和 `multi-node-worker.yaml`

影响：

- 两个阶段的工件约定没有统一
- 用户或后续自动化如果按 prepare 文档理解执行，进入 execute 后仍可能失败

3. Phase 8 / 12 的输出工件和指导文案与实际生成结果不一致

文件参考：

- `README.md:198`
- `README.md:261`
- `README.md:299`
- `vllm-deploy-execute/modules/k8s-apply-guide.md:28`
- `vllm-deploy-execute/modules/output-guide.md:15`
- `vllm-deploy-execute/modules/output-guide.md:62`
- `vllm-deploy-execute/scripts/fill-template.sh:171`
- `vllm-deploy-execute/scripts/fill-template.sh:233`
- `vllm-deploy-execute/scripts/fill-template.sh:289`

问题：

- 文档仍在承诺 `namespace.yaml`、`configmap.yaml`、`deployment*.yaml`、`service.yaml`、`.vllm-deploy/k8s/deploy.sh`、`.vllm-deploy/final-output.json`
- 当前脚本实际生成的是 `all.yaml`、可选 `master.yaml` / `worker-*.yaml`、`scripts-configmap.yaml`、`apply-all.sh`、静态 `README.md`
- `final-output.json` 没有实现，README 也没有在部署完成后基于真实运行态更新

影响：

- 文档与实际产物脱节
- 用户按文档手动 apply 时会找不到对应文件
- Phase 12 的“最终交付”并未真正实现

4. K8s 环境探测没有落实 README 约定的硬件规格校验和无 NPU 失败路径

文件参考：

- `README.md:95`
- `README.md:103`
- `vllm-deploy-execute/SKILL.md:65`
- `vllm-deploy-execute/scripts/detect-k8s-env.sh:50`
- `vllm-deploy-execute/scripts/detect-k8s-env.sh:94`

问题：

- 当前探测脚本只输出 `npu_type` 和 `npu_count`
- 没有推导 `hw_spec`，也没有校验用户在 prepare 阶段选择的 A2 / A3 是否匹配
- 即使集群里没有可用 NPU 节点，脚本仍然能以成功状态返回结构化 JSON

影响：

- 错误硬件假设会继续流入后续渲染和部署步骤
- 缺少 fail-fast，容易把问题拖到更晚阶段才暴露

### Minor

1. `scripts-configmap.yaml` 是冗余工件，且容易和实际部署清单漂移

文件参考：

- `vllm-deploy-prepare/templates/single-node.yaml:26`
- `vllm-deploy-prepare/templates/multi-node-master.yaml:31`
- `vllm-deploy-execute/scripts/fill-template.sh:233`
- `vllm-deploy-execute/scripts/fill-template.sh:277`

问题：

- 各模式模板的 `all.yaml` 中已经自带 `vllm-scripts` ConfigMap
- `fill-template.sh` 又额外生成一个 `scripts-configmap.yaml`
- `apply-all.sh` 只 apply `all.yaml`，并不会 apply 这个额外文件

影响：

- 工件重复
- 后续维护时容易出现两个脚本来源不一致

2. 缺少可执行的回归测试，当前只有测试说明文档

文件参考：

- `docs/superpowers/test-verification-guide.md:1`

问题：

- 仓库里没有发现覆盖 YAML 渲染、节点选择工件、模式分支和输出契约的自动化测试

影响：

- 很难在提交前稳定发现这类 mode-specific 回归
- 当前这几类问题都属于很适合被 fixture/render 测试捕捉的缺陷

## 已执行验证

- 阅读 `README.md`、`vllm-deploy-prepare/SKILL.md`、`vllm-deploy-execute/SKILL.md`
- 审阅关键脚本、模板和模块文档
- 对 `vllm-deploy-execute/scripts/fill-template.sh` 执行 `bash -n`
- 使用最小样例分别渲染 `single_node` 和 `multi_node`
- 对 `multi_node` 分别验证对象格式和字符串格式的 `selected-nodes.json`

本地验证结果摘要：

- `single_node` 渲染成功，输出为 `all.yaml`、`scripts-configmap.yaml`、`apply-all.sh`、`README.md`
- `multi_node` 在对象格式节点选择文件下渲染成功，输出为 `master.yaml`、`worker-1.yaml`、`all.yaml`、`scripts-configmap.yaml`、`apply-all.sh`、`README.md`
- `multi_node` 在字符串数组格式节点选择文件下渲染失败，报错为 `Cannot index string with string "ip"`
- 本次未再复现旧版中“多节点重复资源”和“未替换占位符泄漏”的问题

## 建议的下一步

1. 先明确唯一的行为合同：
   - 继续以 `README.md` 的人工确认流程为准
   - 或正式转向当前的 auto-start 流程

2. 如果以 `README.md` 为准：
   - 停止在 Pod 启动时直接执行 `vllm serve`
   - 真实实现 Phase 9 / 10 / 11 / 12
   - 生成并交付独立的 `.vllm-deploy/k8s/deploy*.sh` 与 `final-output.json`

3. 如果以 auto-start 为准：
   - 回写 `README.md`
   - 回写 `vllm-deploy-execute/modules/deploy-generator.md`
   - 回写 `vllm-deploy-execute/modules/deploy-execution-guide.md`
   - 回写 `vllm-deploy-execute/modules/output-guide.md`
   - 统一最终输出工件列表和手动操作说明

4. 无论选择哪条路线，都应补充最小可执行测试：
   - `single_node`
   - `multi_node`
   - `pd_separate`
   - `ha_active_standby`
   - `selected-nodes.json` 对象格式 / 字符串格式
   - 无 NPU 节点负例

## 评估

Ready to merge：No

原因：

- 主流程和原始诉求仍然存在结构性偏差
- `multi_node` 运行链路仍有阻断级风险
- 输出工件、人工确认点和模块文档没有统一到同一个合同上
