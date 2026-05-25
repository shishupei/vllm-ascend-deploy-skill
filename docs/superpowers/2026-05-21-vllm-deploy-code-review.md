# vLLM Deploy Skill 检视意见（基于 README 原始需求）

日期：2026-05-21

审查对象：

- 分支：`chore/vllm-deploy-worktree-base-20260514`
- HEAD：`c7e4131`
- 对比基线：`473d92c`
- 需求真源：`README.md`

## 范围

本次检视以仓库根目录 `README.md` 描述的 Phase 1-12 端到端流程作为原始需求，对照当前实现的脚本、模板和执行链路，重点检查：

- 现在的实现是否还能按 `README.md` 指定流程走通
- 输出给用户的文档和脚本是否与真实生成物一致
- `multi_node` 路径是否仍有实际阻断问题

## 结论

**如果 `README.md` 仍然是需求真源，当前实现仍不满足合并条件。**

与前一版审查相比，`deploy.sh` 独立生成、`master_node` 选择冲突、旧三参数兼容、`WORLD_SIZE` 回退逻辑这几项已经修复；但当前 `HEAD` 仍有三类问题：

1. `prepare` 阶段输出的模板与 `execute` 阶段实际消费的模板集合不一致，`multi_node` 在干净环境中会直接失败。
2. Phase 9 探测结果没有被 Phase 10 消费，当前 `deploy.sh` 仍然不是“基于容器内探测结果生成”。
3. 生成给用户的 `README.md` 与实际执行链路不一致，用户按文档操作无法完成部署。

## 发现的问题

### Critical

1. `multi_node` 在干净输出目录中无法生成 YAML，`prepare` 与 `execute` 的模板契约已经断链

参考：

- `vllm-deploy-prepare/modules/template-generator.md:16`
- `vllm-deploy-prepare/modules/template-generator.md:29`
- `vllm-deploy-prepare/modules/template-generator.md:90`
- `vllm-deploy-execute/modules/yaml-generator.md:57`
- `vllm-deploy-execute/scripts/fill-template.sh:111`
- `vllm-deploy-execute/scripts/fill-template.sh:144`
- `vllm-deploy-execute/scripts/fill-template.sh:162`

问题：

- `prepare` 阶段文档声明 `multi_node` 只会复制 `multi-node.yaml` 到 `.vllm-deploy/templates/`。
- `execute` 阶段实际却不再读取 `multi-node.yaml`，而是强依赖 `multi-node-master.yaml` 和 `multi-node-worker.yaml`。
- 这不是单纯文档未同步，而是实际输入工件集合已经变了，但上游交付物没有一起更新。

本地复现摘要：

- 在全新临时目录中只放入 `prepare` 阶段承诺的 `multi-node.yaml`。
- 执行：
  - `bash vllm-deploy-execute/scripts/fill-template.sh .vllm-deploy/config.json .vllm-deploy/detection-result.json .vllm-deploy/k8s`
- 实际报错：
  - `sed: can't read .vllm-deploy/templates/multi-node-master.yaml: No such file or directory`

影响：

- 只要按当前 `prepare` 文档和输出结构运行，`multi_node` 就无法进入 Phase 8。
- 这是端到端主路径直接中断的问题。

2. Phase 9 的容器内探测结果没有进入 Phase 10，`deploy.sh` 仍然不是按 README 要求“基于探测结果生成”

参考：

- `README.md:226`
- `README.md:253`
- `vllm-deploy-execute/modules/container-env-detector.md:23`
- `vllm-deploy-execute/modules/deploy-generator.md:5`
- `vllm-deploy-execute/scripts/detect-container-npu.sh:42`
- `vllm-deploy-execute/scripts/fill-template.sh:269`
- `vllm-deploy-execute/scripts/fill-template.sh:282`

问题：

- `README.md` 的 Phase 9 要先在 Pod 内探测 `npu_count`、`npu_devices`、`npu_smi_available`。
- `deploy-generator.md` 也明确写了“根据容器内 NPU 探测结果生成 Pod 内执行脚本”。
- 但当前 `deploy.sh` 是在 `fill-template.sh` 中和 YAML 同时生成的，只读取 `config.json`，并未读取任何容器探测结果文件或命令输出。
- 生成的 `--tensor-parallel-size` 仍完全依赖 Phase 6 的 `config.json`，不是 Phase 9 的探测结果。

影响：

- 当前实现虽然重新引入了独立 `deploy.sh`，但并没有真正实现 README 定义的 Phase 9 -> Phase 10 数据闭环。
- 如果容器内实际可见 NPU 数与预期不一致，脚本不会被调整，用户仍可能在 Phase 11 执行错误配置。

### Important

1. 当前生成给用户的 `.vllm-deploy/k8s/README.md` 与真实执行链路冲突，缺少 Phase 9-11 的关键操作

参考：

- `README.md:275`
- `README.md:307`
- `vllm-deploy-execute/modules/deploy-execution-guide.md:18`
- `vllm-deploy-execute/scripts/fill-template.sh:335`
- `vllm-deploy-execute/scripts/fill-template.sh:348`
- `vllm-deploy-execute/scripts/fill-template.sh:359`
- `vllm-deploy-prepare/templates/single-node.yaml:78`

问题：

- 生成的 `.vllm-deploy/k8s/README.md` 只告诉用户：
  - 执行 `bash apply-all.sh`
  - `kubectl get pods`
  - `curl /v1/models`
- 但当前 Pod 模板实际会 `tail -f /dev/null` 等待人工把 `deploy.sh` 复制进 Pod 并手动执行。
- 生成的 README 完全没有写：
  - 如何执行容器内 NPU 探测
  - 如何 `kubectl cp deploy.sh`
  - 如何 `kubectl exec ... bash /tmp/deploy.sh`

本地渲染结果摘要：

- `single_node` 生成的 README 在“部署步骤”后直接让用户访问服务。
- 同一次渲染生成的 Pod YAML 明确显示容器会一直等待用户手动执行 `deploy.sh`。

影响：

- 用户按当前交付 README 操作，最多只会把等待中的 Pod 部署出来，并不会真正启动 vLLM 服务。
- 这是用户交付物与实际运行行为冲突，不是低优先级文档润色问题。

2. `selected-nodes.json` 的“字符串数组格式支持”仍然在入口处失效

参考：

- `vllm-deploy-execute/scripts/fill-template.sh:42`
- `vllm-deploy-execute/scripts/fill-template.sh:48`
- `vllm-deploy-execute/scripts/fill-template.sh:127`
- `vllm-deploy-execute/scripts/fill-template.sh:156`

问题：

- 脚本后半段已经为对象格式和字符串格式加了类型判断。
- 但在进入 `multi_node` 分支之前，入口仍先执行：
  - `SELECTED_MASTER=$(jq -r '.master_node // .nodes[0].name // .nodes[0]' "$NODES_FILE")`
- 当 `.nodes[0]` 本身是字符串时，这里会先触发 `jq: Cannot index string with string "name"`，后面的兼容逻辑根本无法生效。

本地复现摘要：

- 输入：
  - `{"master_node":"node-b","nodes":["node-a","node-b"]}`
- 直接执行上述 `jq` 表达式会报：
  - `jq: error ... Cannot index string with string "name"`

影响：

- 当前代码实际只稳定支持对象数组格式。
- 如果继续宣称支持字符串数组格式，节点确认链路的兼容性声明仍然是不成立的。

### Medium

1. 仓库内关于输出工件的说明仍然存在三套互相冲突的口径

参考：

- `README.md:300`
- `vllm-deploy-execute/SKILL.md:46`
- `vllm-deploy-execute/modules/yaml-generator.md:74`
- `vllm-deploy-execute/modules/deploy-generator.md:63`

问题：

- `README.md` 已经更新为 `all.yaml` / `master.yaml` / `worker-*.yaml` / `deploy.sh`。
- `vllm-deploy-execute/SKILL.md` 仍写着会输出 `scripts-configmap.yaml`。
- `modules/yaml-generator.md` 仍写着 `namespace.yaml`、`configmap.yaml`、`deployment-master.yaml`、`service.yaml`。
- `modules/deploy-generator.md` 仍写着多节点会生成 `deploy-master.sh`、`deploy-worker-1.sh`，而当前实现只生成一个统一的 `deploy.sh`。

影响：

- 后续评审、测试和人工操作都很难基于同一份契约工作。
- 这类漂移已经开始影响真实实现判断，而不只是文档质量问题。

## 已执行验证

- 阅读 `README.md`，按 Phase 1-12 理解原始需求
- 阅读 `vllm-deploy-prepare/SKILL.md`
- 阅读 `vllm-deploy-execute/SKILL.md`
- 阅读 `vllm-deploy-prepare/modules/template-generator.md`
- 阅读 `vllm-deploy-execute/modules/yaml-generator.md`
- 阅读 `vllm-deploy-execute/modules/container-env-detector.md`
- 阅读 `vllm-deploy-execute/modules/deploy-generator.md`
- 审阅 `vllm-deploy-execute/scripts/fill-template.sh`
- 审阅 `vllm-deploy-execute/scripts/detect-container-npu.sh`
- 审阅 `vllm-deploy-prepare/templates/single-node.yaml`
- 在隔离临时目录中做最小本地复现，验证：
  - `multi_node` 只提供 `multi-node.yaml` 时会因缺少 `multi-node-master.yaml` 直接失败
  - `single_node` 生成的 README 未包含 Phase 9-11 所需手动步骤
  - 字符串数组格式 `selected-nodes.json` 在入口 jq 表达式处就会报错

本次未执行：

- 真实 K8s 集群部署
- Pod 内实际 `ray` / `vllm` 启动验证
- `prepare` 阶段真实对模板复制动作的交互式验收

## 建议的下一步

1. 先修复 `prepare`/`execute` 模板契约断链：
   - 要么 `prepare` 阶段输出 `multi-node-master.yaml` 和 `multi-node-worker.yaml`
   - 要么 `execute` 阶段恢复消费 `multi-node.yaml`

2. 明确实现 Phase 9 -> Phase 10 的数据传递：
   - 至少让 `deploy.sh` 的关键参数来自容器内探测结果，而不是只来自 `config.json`
   - 如果不打算这么做，就需要同步修改 `README.md`、模块文档和设计文档，明确废弃该要求

3. 重写生成的 `.vllm-deploy/k8s/README.md`：
   - 加入容器探测命令
   - 加入 `kubectl cp deploy.sh`
   - 加入 `kubectl exec ... bash /tmp/deploy.sh`
   - 对多节点补充执行顺序说明

4. 修正 `selected-nodes.json` 入口解析：
   - 在首次读取 `SELECTED_MASTER` 时就做类型判断
   - 或明确只支持对象数组格式，并删除所有字符串数组兼容声明

5. 清理文档口径：
   - `README.md`
   - `vllm-deploy-execute/SKILL.md`
   - `modules/yaml-generator.md`
   - `modules/deploy-generator.md`

## 评估

Ready to merge：**No**

Reasoning：

当前 `HEAD` 已修复上一轮 review 中的若干实现缺陷，但端到端主路径仍存在断链：`multi_node` 在干净环境中无法生成 YAML，且交付给用户的 README 不能指导完成 Phase 9-11。只要 `README.md` 仍是需求真源，这些问题都属于阻断项。
