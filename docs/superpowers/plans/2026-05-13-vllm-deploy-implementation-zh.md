# vLLM-Deploy Skill 中文实现计划

> **给执行型 agent 的说明：** 实际落地时，优先使用英文版计划 [2026-05-13-vllm-deploy-implementation.md](/home/shishupei/app/vllm-skill/docs/superpowers/plans/2026-05-13-vllm-deploy-implementation.md) 作为规范执行基准。本文件是面向人工阅读的中文对照版，任务顺序和约束与英文版保持一致。

**目标：** 以 `README.md` 为唯一事实来源，重建 `vllm-deploy` skill 包，使仓库重新具备一套可被 Codex 和 Claude Code 共同使用的完整 skill。

**架构：** 重建工作保持 README 既有文件结构不变，按四层恢复：skill 入口文件、phase 模块文档、可执行 Bash 辅助脚本、部署模板文件。执行顺序遵循 TDD 思路，先做 RED 基线校验，再逐层补齐内容，最后对照 README 做仓库级验证。

**技术栈：** Markdown、YAML、Bash、Git、`rg`、`sed`、`chmod`

---

## 文件范围

### Skill 入口与元数据

- 创建：`SKILL.md`
- 创建：`skill.md`
- 创建：`skill.yaml`

### 模块文档

- 创建：`modules/model-list-fetcher.md`
- 创建：`modules/user-selector.md`
- 创建：`modules/doc-parser.md`
- 创建：`modules/k8s-env-detector.md`
- 创建：`modules/image-handler.md`
- 创建：`modules/config-guide.md`
- 创建：`modules/k8s-yaml-generator.md`
- 创建：`modules/k8s-apply-guide.md`
- 创建：`modules/container-env-detector.md`
- 创建：`modules/deploy-generator.md`
- 创建：`modules/deploy-execution-guide.md`
- 创建：`modules/output-guide.md`

### 辅助脚本

- 创建：`scripts/fetch-model-list.sh`
- 创建：`scripts/parse-model-doc.sh`
- 创建：`scripts/detect-k8s-env.sh`
- 创建：`scripts/detect-container-npu.sh`
- 创建：`scripts/push-image.sh`

### 模板文件

- 创建：`templates/k8s-namespace.yaml`
- 创建：`templates/k8s-configmap.yaml`
- 创建：`templates/k8s-deployment.yaml`
- 创建：`templates/k8s-service.yaml`
- 创建：`templates/deploy.sh`
- 创建：`templates/apply-all.sh`

### 配套文档

- 创建：`docs/superpowers/specs/2026-05-13-vllm-deploy-skill-design.md`
- 创建：`docs/superpowers/plans/2026-05-13-vllm-deploy-implementation.md`
- 创建：`docs/superpowers/plans/2026-05-13-vllm-deploy-implementation-zh.md`

## 总体验证命令

- `test -f SKILL.md`
- `test -f skill.md`
- `test -f skill.yaml`
- `test -f modules/model-list-fetcher.md`
- `test -f scripts/fetch-model-list.sh`
- `test -f templates/k8s-namespace.yaml`
- `bash scripts/fetch-model-list.sh --help`
- `bash scripts/parse-model-doc.sh --help`
- `bash scripts/detect-k8s-env.sh --help`
- `bash scripts/detect-container-npu.sh --help`
- `bash scripts/push-image.sh --help`

## 任务 1：做 RED 基线校验并恢复目录骨架

**涉及文件：**
- 创建目录：`modules/`
- 创建目录：`scripts/`
- 创建目录：`templates/`
- 创建目录：`docs/superpowers/specs/`
- 创建目录：`docs/superpowers/plans/`

### 步骤

1. 先执行失败的存在性校验，确认当前确实缺失目标文件。

运行：

```bash
test -f SKILL.md
test -f skill.md
test -f skill.yaml
test -f modules/model-list-fetcher.md
test -f scripts/fetch-model-list.sh
test -f templates/k8s-namespace.yaml
```

预期：

```text
以上命令均返回非 0，因为这些文件当前不存在。
```

2. 重新创建目录骨架，为后续落文件做准备。

运行：

```bash
mkdir -p modules scripts templates docs/superpowers/specs docs/superpowers/plans
```

预期：

```text
所有目标目录存在，后续可以正常创建文件。
```

3. 再次确认只有目录恢复了，核心文件仍然缺失，RED 仍然成立。

运行：

```bash
test -d modules
test -d scripts
test -d templates
test -f SKILL.md
```

预期：

```text
目录检查通过，最后一个文件检查仍然失败。
```

## 任务 2：重建 Skill 入口文件

**涉及文件：**
- 创建：`SKILL.md`
- 创建：`skill.md`
- 创建：`skill.yaml`

### 步骤

1. 先写入口文件的失败检查，确认入口尚未恢复。

运行：

```bash
rg -n '^---$|^name: vllm-deploy$|^description: Use when' SKILL.md
rg -n 'Phase 1|Phase 12|modules/model-list-fetcher.md|templates/apply-all.sh' skill.md
rg -n '^name: vllm-deploy$|^description:' skill.yaml
```

预期：

```text
命令失败，因为入口文件尚不存在。
```

2. 创建 `SKILL.md`，作为 Codex / Claude Code 兼容的主入口。

内容要求：

- 必须有标准 frontmatter
- `name` 为 `vllm-deploy`
- `description` 以 `Use when...` 开头
- 明确 12 个 phase 的执行顺序
- 标出会用到的 `modules/`、`scripts/`、`templates/`
- 保留 README 中要求的用户确认节点

3. 创建 `skill.md`，作为 README 结构兼容入口。

内容要求：

- 中文说明使用时机
- 列出执行环境
- 逐项列出 12 个 phase 及对应模块
- 列出 6 个模板文件

4. 创建 `skill.yaml`，补元数据。

内容要求：

- `name: vllm-deploy`
- `description:` 描述该 skill 的触发条件与总体用途

5. 运行入口文件检查，确认入口层恢复成功。

运行：

```bash
rg -n '^---$|^name: vllm-deploy$|^description: Use when' SKILL.md
rg -n 'Phase 1|Phase 12|modules/model-list-fetcher.md|templates/apply-all.sh' skill.md
rg -n '^name: vllm-deploy$|^description:' skill.yaml
```

预期：

```text
命令全部成功，并能匹配到关键标记。
```

## 任务 3：重建 12 个 Phase 模块文档

**涉及文件：**
- 创建：`modules/model-list-fetcher.md`
- 创建：`modules/user-selector.md`
- 创建：`modules/doc-parser.md`
- 创建：`modules/k8s-env-detector.md`
- 创建：`modules/image-handler.md`
- 创建：`modules/config-guide.md`
- 创建：`modules/k8s-yaml-generator.md`
- 创建：`modules/k8s-apply-guide.md`
- 创建：`modules/container-env-detector.md`
- 创建：`modules/deploy-generator.md`
- 创建：`modules/deploy-execution-guide.md`
- 创建：`modules/output-guide.md`

### 公共结构

每个模块文件统一采用以下结构：

```markdown
# Phase N: <标题>

## 目的

## 输入

## 执行位置

## 步骤

## 输出

## 失败处理

## 关联资源
```

### 步骤

1. 先执行 phase 覆盖率检查，确认模块文件尚未恢复。

运行：

```bash
for file in \
  modules/model-list-fetcher.md \
  modules/user-selector.md \
  modules/doc-parser.md \
  modules/k8s-env-detector.md \
  modules/image-handler.md \
  modules/config-guide.md \
  modules/k8s-yaml-generator.md \
  modules/k8s-apply-guide.md \
  modules/container-env-detector.md \
  modules/deploy-generator.md \
  modules/deploy-execution-guide.md \
  modules/output-guide.md; do
  test -f "$file" || exit 1
done
```

预期：

```text
命令返回非 0，因为模块文件还未创建。
```

2. 先创建 Phase 1 到 Phase 4 文档。

要求：

- `model-list-fetcher.md` 说明模型列表抓取与快速展示
- `user-selector.md` 说明模型、硬件规格、部署方式、镜像仓库选择
- `doc-parser.md` 说明按模型/规格/部署方式做针对性文档解析
- `k8s-env-detector.md` 说明 `kubectl`、节点、IP、NPU 数量与规格探测

3. 再创建 Phase 5 到 Phase 8 文档。

要求：

- `image-handler.md` 说明 docker login / pull / tag / push 流程
- `config-guide.md` 说明 namespace、模型路径、性能参数、PD 分离配置问答
- `k8s-yaml-generator.md` 说明 `.vllm-deploy/k8s/` 下 YAML 和脚本产物生成
- `k8s-apply-guide.md` 保留 README 中“用户手动 apply”的指导

4. 最后创建 Phase 9 到 Phase 12 文档。

要求：

- `container-env-detector.md` 说明 Pod 状态与 NPU 映射探测
- `deploy-generator.md` 说明如何根据容器内 NPU 数量推导 `--tensor-parallel-size`
- `deploy-execution-guide.md` 保留用户确认后在 Pod 内执行 `deploy.sh`
- `output-guide.md` 列出最终交付目录树与执行说明

5. 统一验证所有模块存在且结构一致。

运行：

```bash
for file in modules/*.md; do
  rg -n '^## 目的$|^## 输入$|^## 执行位置$|^## 步骤$|^## 输出$|^## 失败处理$|^## 关联资源$' "$file" >/dev/null || exit 1
done
rg -n 'Phase 8|手动 apply|apply-all.sh' modules/k8s-apply-guide.md
rg -n 'Pod|NPU|deploy.sh' modules/container-env-detector.md modules/deploy-generator.md modules/deploy-execution-guide.md
```

预期：

```text
所有模块文件存在，结构统一，并且包含 phase 专属关键字。
```

## 任务 4：重建 5 个辅助脚本

**涉及文件：**
- 创建：`scripts/fetch-model-list.sh`
- 创建：`scripts/parse-model-doc.sh`
- 创建：`scripts/detect-k8s-env.sh`
- 创建：`scripts/detect-container-npu.sh`
- 创建：`scripts/push-image.sh`

### 统一约束

每个脚本都必须满足：

- 使用 `#!/usr/bin/env bash`
- 使用 `set -euo pipefail`
- 提供 `usage()` 函数
- 支持 `--help`
- 参数缺失时返回非 0
- 工具缺失时报出清晰错误

### 步骤

1. 先运行失败的脚本接口检查。

运行：

```bash
bash scripts/fetch-model-list.sh --help
bash scripts/parse-model-doc.sh --help
bash scripts/detect-k8s-env.sh --help
bash scripts/detect-container-npu.sh --help
bash scripts/push-image.sh --help
```

预期：

```text
命令失败，因为脚本文件还不存在。
```

2. 创建 `fetch-model-list.sh` 和 `parse-model-doc.sh`。

要求：

- `fetch-model-list.sh` 接收 URL，抓取模型索引页面，提取模型名和链接
- `parse-model-doc.sh` 接收模型 URL、硬件规格、部署方式，提取脚本块、镜像版本、参数提示
- 两者在 `curl` 缺失或参数缺失时必须明确失败

3. 创建 `detect-k8s-env.sh` 和 `detect-container-npu.sh`。

要求：

- `detect-k8s-env.sh` 探测 `kubectl`、集群连通性、节点、IP 与 NPU 相关线索
- `detect-container-npu.sh` 接收 namespace 和 pod，探测 Pod 内设备映射情况
- 两者在 `kubectl` 缺失或输入不足时必须明确失败

4. 创建 `push-image.sh` 并为所有脚本增加执行权限。

要求：

- 接收源镜像与目标镜像
- 如有需要支持登录目标镜像仓库
- 执行 pull / tag / push
- 所有脚本最终都要 `chmod +x`

5. 验证脚本接口、执行权限和缺参失败路径。

运行：

```bash
test -x scripts/fetch-model-list.sh
test -x scripts/parse-model-doc.sh
test -x scripts/detect-k8s-env.sh
test -x scripts/detect-container-npu.sh
test -x scripts/push-image.sh
bash scripts/fetch-model-list.sh --help
bash scripts/parse-model-doc.sh --help
bash scripts/detect-k8s-env.sh --help
bash scripts/detect-container-npu.sh --help
bash scripts/push-image.sh --help
! bash scripts/fetch-model-list.sh
! bash scripts/parse-model-doc.sh
! bash scripts/detect-k8s-env.sh
! bash scripts/detect-container-npu.sh
! bash scripts/push-image.sh
```

预期：

```text
所有脚本具有执行权限，--help 成功，无参调用返回非 0。
```

## 任务 5：重建 6 个模板文件

**涉及文件：**
- 创建：`templates/k8s-namespace.yaml`
- 创建：`templates/k8s-configmap.yaml`
- 创建：`templates/k8s-deployment.yaml`
- 创建：`templates/k8s-service.yaml`
- 创建：`templates/deploy.sh`
- 创建：`templates/apply-all.sh`

### 步骤

1. 先执行失败的模板存在性检查。

运行：

```bash
test -f templates/k8s-namespace.yaml
test -f templates/k8s-configmap.yaml
test -f templates/k8s-deployment.yaml
test -f templates/k8s-service.yaml
test -f templates/deploy.sh
test -f templates/apply-all.sh
```

预期：

```text
命令返回非 0，因为模板尚未创建。
```

2. 创建 K8s 基础 YAML 模板。

要求：

- `k8s-namespace.yaml` 包含 `${NAMESPACE}`、`${MODEL_NAME}`
- `k8s-configmap.yaml` 包含 `${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}`
- `k8s-service.yaml` 包含 `${SERVICE_PORT}`

3. 创建 `k8s-deployment.yaml`。

要求：

- 包含 `${NODE_NAME}`、`${IMAGE}`、`${NPU_RESOURCE_TYPE}`、`${NPU_COUNT}`
- 包含 `${MODEL_MOUNT_PATH}`、`${MODEL_PATH_HOST}`
- 结构上能表达 README 描述的 Pod 配置、节点绑定和模型挂载

4. 创建 `deploy.sh` 与 `apply-all.sh` 模板。

要求：

- `deploy.sh` 保留 `${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}`
- 还要保留 `${MASTER_ADDR}`、`${MASTER_PORT}`、`${RANK}` 以支持分布式与 PD 场景
- `apply-all.sh` 保留 `${NAMESPACE}`，并体现 README 中按顺序 apply 与等待 Pod 就绪的逻辑

5. 统一验证模板占位符完整性。

运行：

```bash
rg -n '\${NAMESPACE}|\${MODEL_NAME}' templates/k8s-namespace.yaml
rg -n '\${MODEL_PATH}|\${MAX_MODEL_LEN}|\${MAX_NUM_SEQS}|\${TENSOR_PARALLEL_SIZE}' templates/k8s-configmap.yaml
rg -n '\${NODE_NAME}|\${IMAGE}|\${NPU_RESOURCE_TYPE}|\${NPU_COUNT}|\${MODEL_MOUNT_PATH}|\${MODEL_PATH_HOST}' templates/k8s-deployment.yaml
rg -n '\${SERVICE_PORT}' templates/k8s-service.yaml
rg -n '\${MODEL_PATH}|\${MASTER_ADDR}|\${MASTER_PORT}|\${RANK}' templates/deploy.sh
rg -n '\${NAMESPACE}' templates/apply-all.sh
```

预期：

```text
所有模板都存在，并且包含 README 对应的关键占位符。
```

## 任务 6：做仓库级总验证并收尾

**涉及文件：**
- 检查：`SKILL.md`
- 检查：`skill.md`
- 检查：`skill.yaml`
- 检查：`modules/*.md`
- 检查：`scripts/*.sh`
- 检查：`templates/*`

### 步骤

1. 验证完整文件集合已经恢复。

运行：

```bash
for file in \
  SKILL.md \
  skill.md \
  skill.yaml \
  modules/model-list-fetcher.md \
  modules/user-selector.md \
  modules/doc-parser.md \
  modules/k8s-env-detector.md \
  modules/image-handler.md \
  modules/config-guide.md \
  modules/k8s-yaml-generator.md \
  modules/k8s-apply-guide.md \
  modules/container-env-detector.md \
  modules/deploy-generator.md \
  modules/deploy-execution-guide.md \
  modules/output-guide.md \
  scripts/fetch-model-list.sh \
  scripts/parse-model-doc.sh \
  scripts/detect-k8s-env.sh \
  scripts/detect-container-npu.sh \
  scripts/push-image.sh \
  templates/k8s-namespace.yaml \
  templates/k8s-configmap.yaml \
  templates/k8s-deployment.yaml \
  templates/k8s-service.yaml \
  templates/deploy.sh \
  templates/apply-all.sh; do
  test -f "$file" || exit 1
done
```

预期：

```text
命令全部成功。
```

2. 验证 README 契约关键字是否到位。

运行：

```bash
rg -n '12-phase|12 个 phase|Phase 12|apply-all.sh|deploy.sh' SKILL.md skill.md
rg -n 'docker|kubectl|NPU|Pod|ConfigMap|Service|Deployment' modules/*.md
rg -n 'Usage:' scripts/*.sh
rg -n '\${[A-Z0-9_]+}' templates/*
```

预期：

```text
仓库中能看到预期的流程、环境、脚本接口和模板占位符标记。
```

3. 重新验证脚本接口。

运行：

```bash
bash scripts/fetch-model-list.sh --help
bash scripts/parse-model-doc.sh --help
bash scripts/detect-k8s-env.sh --help
bash scripts/detect-container-npu.sh --help
bash scripts/push-image.sh --help
! bash scripts/fetch-model-list.sh
! bash scripts/parse-model-doc.sh
! bash scripts/detect-k8s-env.sh
! bash scripts/detect-container-npu.sh
! bash scripts/push-image.sh
```

预期：

```text
帮助路径保持通过，缺参路径保持失败。
```

4. 检查工作树，确认没有无关文件。

运行：

```bash
git status --short
```

预期：

```text
工作树中只出现本次重建的 skill 文件和 docs/superpowers 下的文档。
```

5. 输出剩余风险与交接说明。

需要明确告诉阅读者：

- 这次重建是严格基于 README，不以已删除旧实现为来源
- shell 解析逻辑是最小可运行版本，未来可能需要随上游 HTML 变化调整
- 集群和镜像仓库相关动作虽已文档化和脚本化，但仍要在真实环境中验证
