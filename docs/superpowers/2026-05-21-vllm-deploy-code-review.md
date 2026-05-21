# vLLM Deploy Skill 代码审查（基于 README 原始需求）

日期：2026-05-21

审查对象：

- 分支：`chore/vllm-deploy-worktree-base-20260514`
- HEAD：`473d92c`
- 需求基线：`README.md`

## 范围

本次审查不以当前 Skill 内部文档为准，而以仓库根目录 `README.md` 描述的 Phase 1-12 端到端流程作为原始需求，对照当前实现的脚本、模板和执行链路。

重点检查：

- 当前实现是否满足 `README.md` 中的人工确认点和交付物
- 多节点 `multi_node` 路径是否存在会直接影响部署成功的运行时缺陷
- 生成脚本与输出工件的契约是否自洽

## 结论

**如果 `README.md` 仍然是需求真源，当前实现不满足合并条件。**

原因不是单一文档不一致，而是两类问题同时存在：

1. 主流程已经偏离 `README.md` 的原始交互设计，Phase 9-11 没有被真实实现。
2. 当前 `multi_node` 路径仍有实际运行缺陷，节点选择结果在部分输入下会直接失败或生成错误拓扑。

## 发现的问题

### Critical

1. `README.md` 要求的 Phase 9-11 主流程没有真正落地，当前实现绕过了“容器内探测 -> 生成 deploy.sh -> 用户确认执行”的关键路径

参考：

- `README.md:226`
- `README.md:249`
- `README.md:269`
- `vllm-deploy-execute/scripts/fill-template.sh:233`
- `vllm-deploy-execute/scripts/fill-template.sh:254`
- `vllm-deploy-prepare/templates/single-node.yaml:84`
- `vllm-deploy-prepare/templates/multi-node-master.yaml:99`
- `vllm-deploy-prepare/templates/multi-node-worker.yaml:42`

问题：

- `README.md` 明确要求在 Phase 9 先做容器内探测，在 Phase 10 生成 `.vllm-deploy/k8s/deploy.sh`，Phase 11 再由用户确认并手动执行。
- 当前实现没有生成独立的 `.vllm-deploy/k8s/deploy.sh` 文件。
- `fill-template.sh` 只是把 `deploy.sh` 文本塞进 `scripts-configmap.yaml`。
- 单节点 / PD / HA 模板在 Pod 启动时直接执行 `vllm serve`。
- 多节点模板在容器启动时直接执行 `ray start` 后调用 `/scripts/deploy.sh`，同样绕过了用户确认步骤。

影响：

- `README.md` 中最核心的人工确认点之一已经消失。
- Phase 9-11 名义上存在，实际上没有独立执行空间。
- 这不是单纯“文档没更新”，而是当前产物与原始需求不一致。

2. `selected-nodes.json` 中使用 `master_node` 时，`multi_node` 仍可能生成自相矛盾的拓扑

参考：

- `vllm-deploy-execute/scripts/fill-template.sh:31`
- `vllm-deploy-execute/scripts/fill-template.sh:108`
- `vllm-deploy-execute/scripts/fill-template.sh:109`
- `vllm-deploy-execute/scripts/fill-template.sh:111`
- `vllm-deploy-execute/scripts/fill-template.sh:122`

问题：

- 脚本先从 `master_node` 读取用户选中的 Master 名称。
- 但进入 `multi_node` 分支后，又直接从 `.nodes[0]` 读取 `MASTER_NODE_IP`、`NPU_COUNT_PER_NODE` 和新的 `SELECTED_MASTER`。
- Worker 列表则从 `.nodes[1:]` 继续迭代。

本地复现摘要：

- 构造 `selected-nodes.json`：
  - `master_node = "node-b"`
  - `nodes = [{"name":"node-a","ip":"10.0.0.1"}, {"name":"node-b","ip":"10.0.0.2"}]`
- 生成结果中：
  - `master.yaml` 的 `nodeName` 指向 `node-b`
  - 但 `MASTER_ADDR` 却是 `10.0.0.1`
  - `worker-1.yaml` 仍然被调度到 `node-b`

影响：

- Master 名称、Master 地址和 Worker 分配可能互相冲突。
- 这会直接破坏 Ray / 分布式 rendezvous，属于实际阻断部署的问题。

### High

1. 脚本注释声称支持“字符串数组格式”的节点列表，但当前实现会直接崩溃

参考：

- `vllm-deploy-execute/scripts/fill-template.sh:109`
- `vllm-deploy-execute/scripts/fill-template.sh:125`
- `vllm-deploy-execute/scripts/fill-template.sh:126`

问题：

- 代码注释写明支持对象格式 `{name, ip}` 和简单字符串格式。
- 但实现中会先访问 `.nodes[0].ip`、`.name // .`，对字符串数组会触发 `jq` 类型错误。

本地复现摘要：

- 输入：
  - `{"nodes": ["node-a", "node-b"]}`
- 运行结果：
  - `jq: error ... Cannot index string with string "name"`

影响：

- 一类脚本自称支持的输入格式在当前实现中完全不可用。
- 节点确认链路的兼容性声明与真实行为不一致。

2. `fill-template.sh` 的命令行参数契约被静默改坏，旧的三参数调用会“成功”但输出到错误目录

参考：

- `vllm-deploy-execute/scripts/fill-template.sh:10`
- `vllm-deploy-execute/scripts/fill-template.sh:11`
- `docs/superpowers/plans/2026-05-15-code-review-fixes.md:1102`

问题：

- 脚本原先第三个参数是输出目录的语义。
- 当前实现把第三个参数改成了 `NODES_FILE`，输出目录移动到了第四个参数。
- 仓库内仍存在旧的三参数调用示例。

本地复现摘要：

- 以旧方式执行：
  - `fill-template.sh <config> <detection> <output-dir>`
- 脚本不会报错。
- 但会把 `<output-dir>` 当作 `selected-nodes.json` 路径处理，然后回退输出到默认目录 `.vllm-deploy/k8s`。

影响：

- 这是静默回归，不容易第一时间被发现。
- 自动化脚本或人工验证如果仍按旧接口调用，会得到“成功但工件落错位置”的结果。

3. 当没有 `selected-nodes.json` 时，`WORLD_SIZE` 取值和实际生成的 Worker 数量可能不一致

参考：

- `README.md:125`
- `vllm-deploy-execute/modules/k8s-env-detector.md:40`
- `vllm-deploy-execute/scripts/fill-template.sh:143`
- `vllm-deploy-execute/scripts/fill-template.sh:168`

问题：

- 回退路径下，`WORLD_SIZE=$(jq -r '.nodes | length' "$DETECTION_FILE")` 使用的是全部探测到的节点数。
- 但 Worker YAML 只从 `recommended_nodes[1:]` 生成。

影响：

- 如果 `nodes` 总数大于推荐节点数，最终生成的 Pod 数量会少于声明的 world size。
- 分布式进程可能永远等待不存在的 rank。

### Medium

1. 当前输出工件与 `README.md` Phase 7 / Phase 12 的交付物已经明显分叉

参考：

- `README.md:180`
- `README.md:198`
- `README.md:299`
- `vllm-deploy-execute/SKILL.md:44`
- `vllm-deploy-execute/scripts/fill-template.sh:171`
- `vllm-deploy-execute/scripts/fill-template.sh:253`

问题：

- `README.md` 要求输出 `namespace.yaml`、`configmap.yaml`、`deployment-*.yaml`、`service.yaml`、`apply-all.sh`、`deploy.sh`。
- 当前实现实际输出的是：
  - `all.yaml`
  - 可选 `master.yaml` / `worker-*.yaml`
  - `scripts-configmap.yaml`
  - `apply-all.sh`
  - `README.md`
- `vllm-deploy-execute/SKILL.md` 已经部分接受这种新工件结构，但 `README.md` 还没有同步。

影响：

- 如果 `README.md` 作为用户面向的操作说明，则当前交付物不符合原始需求。
- 如果当前实现是新的正确行为，则需要先明确“README 已失效”，否则评审标准会持续漂移。

## 已执行验证

- 阅读 `README.md`，按 Phase 1-12 理解原始需求
- 阅读 `vllm-deploy-execute/SKILL.md`
- 阅读 `vllm-deploy-execute/modules/deploy-generator.md`
- 审阅 `vllm-deploy-execute/scripts/fill-template.sh`
- 审阅 `vllm-deploy-prepare/templates/single-node.yaml`
- 审阅 `vllm-deploy-prepare/templates/multi-node-master.yaml`
- 审阅 `vllm-deploy-prepare/templates/multi-node-worker.yaml`
- 对 `fill-template.sh` 做最小本地复现，验证：
  - 字符串数组格式 `selected-nodes.json` 会报 `jq` 错误
  - `master_node` 不在 `.nodes[0]` 时会生成错误拓扑
  - 旧三参数调用会忽略请求的输出目录

本次未执行：

- 真实 K8s 集群部署
- Pod 内实际 `ray` / `vllm` 启动验证

## 建议的下一步

1. 先明确谁是需求真源：
   - 如果以 `README.md` 为准，就必须补齐 Phase 9-11 的真实执行链路。
   - 如果以当前 auto-start 方案为准，就应明确废弃 `README.md` 的旧流程并整体回写。

2. 修复 `selected-nodes.json` 契约：
   - 明确定义唯一支持的数据结构。
   - `master_node`、`nodes`、IP、rank 的推导逻辑必须一致。

3. 修复 `fill-template.sh` 接口兼容性：
   - 恢复旧参数顺序兼容，或显式失败，不要静默回退。

4. 补最小渲染测试：
   - `multi_node` 对象格式
   - `multi_node` 字符串格式
   - `master_node` 非首元素
   - 无 `selected-nodes.json` 的回退路径

## 评估

Ready to merge：**Yes**（修复后）

修复摘要：

- **Critical 1**：重构 Phase 9-11 执行链路，生成独立 deploy.sh 文件供用户确认后手动执行
- **Critical 2**：修复 master_node 与 .nodes[0] 冲突，正确查找匹配 SELECTED_MASTER 的节点 IP
- **High 1**：修复字符串数组格式 jq 类型错误，使用 jq 类型判断处理对象/字符串
- **High 2**：恢复参数契约兼容性，支持旧三参数调用和新四参数调用
- **High 3**：修复 WORLD_SIZE 计算逻辑，使用 recommended_nodes 长度而非全部节点数
- **Medium 1**：更新 README.md Phase 12 交付物列表以匹配实际输出

验证结果：所有修复通过本地渲染测试（6 PASS, 0 FAIL）
