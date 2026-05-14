# vLLM-Deploy Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the `vllm-deploy` skill package from `README.md` so the repository again contains a complete, cross-compatible skill for Codex and Claude Code.

**Architecture:** The rebuild keeps the README file structure intact and recreates four layers: skill entry files, phase module guides, executable Bash helpers, and deployment templates. Work starts with RED-style existence and interface checks, then fills each layer with minimal but runnable content, and ends with repository-wide verification against the README contract.

**Tech Stack:** Markdown, YAML, Bash, Git, `rg`, `sed`, `chmod`

---

## File Map

### Skill entry and metadata

- Create: `SKILL.md`
- Create: `skill.md`
- Create: `skill.yaml`

### Module guides

- Create: `modules/model-list-fetcher.md`
- Create: `modules/user-selector.md`
- Create: `modules/doc-parser.md`
- Create: `modules/k8s-env-detector.md`
- Create: `modules/image-handler.md`
- Create: `modules/config-guide.md`
- Create: `modules/k8s-yaml-generator.md`
- Create: `modules/k8s-apply-guide.md`
- Create: `modules/container-env-detector.md`
- Create: `modules/deploy-generator.md`
- Create: `modules/deploy-execution-guide.md`
- Create: `modules/output-guide.md`

### Helper scripts

- Create: `scripts/fetch-model-list.sh`
- Create: `scripts/parse-model-doc.sh`
- Create: `scripts/detect-k8s-env.sh`
- Create: `scripts/detect-container-npu.sh`
- Create: `scripts/push-image.sh`

### Templates

- Create: `templates/k8s-namespace.yaml`
- Create: `templates/k8s-configmap.yaml`
- Create: `templates/k8s-deployment.yaml`
- Create: `templates/k8s-service.yaml`
- Create: `templates/deploy.sh`
- Create: `templates/apply-all.sh`

### Supporting docs

- Create: `docs/superpowers/specs/2026-05-13-vllm-deploy-skill-design.md`
- Create: `docs/superpowers/plans/2026-05-13-vllm-deploy-implementation.md`

### Verification commands

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

### Task 1: RED Baseline And Directory Restoration

**Files:**
- Create: `modules/`
- Create: `scripts/`
- Create: `templates/`
- Create: `docs/superpowers/specs/`
- Create: `docs/superpowers/plans/`

- [ ] **Step 1: Run failing existence checks before recreating files**

Run:

```bash
test -f SKILL.md
test -f skill.md
test -f skill.yaml
test -f modules/model-list-fetcher.md
test -f scripts/fetch-model-list.sh
test -f templates/k8s-namespace.yaml
```

Expected:

```text
Each command exits non-zero because the files are currently missing.
```

- [ ] **Step 2: Recreate the directory skeleton**

Run:

```bash
mkdir -p modules scripts templates docs/superpowers/specs docs/superpowers/plans
```

Expected:

```text
All required directories exist and are ready for file creation.
```

- [ ] **Step 3: Verify only the directories exist and the RED baseline is still valid for missing files**

Run:

```bash
test -d modules
test -d scripts
test -d templates
test -f SKILL.md
```

Expected:

```text
Directory checks pass. The final file check still fails because the skill entry has not been recreated yet.
```

### Task 2: Rebuild Skill Entry Files

**Files:**
- Create: `SKILL.md`
- Create: `skill.md`
- Create: `skill.yaml`
- Test: `SKILL.md`

- [ ] **Step 1: Write the failing content checks for the skill entry**

Run:

```bash
rg -n '^---$|^name: vllm-deploy$|^description: Use when' SKILL.md
rg -n 'Phase 1|Phase 12|modules/model-list-fetcher.md|templates/apply-all.sh' skill.md
rg -n '^name: vllm-deploy$|^description:' skill.yaml
```

Expected:

```text
All three commands fail because the entry files do not exist yet.
```

- [ ] **Step 2: Create `SKILL.md` as the canonical cross-agent entry**

Create:

```markdown
---
name: vllm-deploy
description: Use when deploying vLLM-Ascend models on Kubernetes and you need to fetch model docs, inspect the cluster, prepare images, generate K8s manifests, and produce an in-pod deployment script
---

# vLLM-Deploy

## Overview

Use this skill on a Kubernetes management node when the goal is to turn a vLLM-Ascend model tutorial into a runnable K8s deployment package. The skill follows the README-defined 12-phase flow and keeps explicit user confirmation points for manifest apply and final in-pod execution.

## Environment

- Requires `kubectl` access to the target cluster
- Requires Docker access for image pull, retag, and push
- Assumes the operator can run commands on a K8s management node

## Workflow

1. Phase 1: Read [modules/model-list-fetcher.md](/home/shishupei/app/vllm-skill/modules/model-list-fetcher.md) and use `scripts/fetch-model-list.sh`
2. Phase 2: Read [modules/user-selector.md](/home/shishupei/app/vllm-skill/modules/user-selector.md)
3. Phase 3: Read [modules/doc-parser.md](/home/shishupei/app/vllm-skill/modules/doc-parser.md) and use `scripts/parse-model-doc.sh`
4. Phase 4: Read [modules/k8s-env-detector.md](/home/shishupei/app/vllm-skill/modules/k8s-env-detector.md) and use `scripts/detect-k8s-env.sh`
5. Phase 5: Read [modules/image-handler.md](/home/shishupei/app/vllm-skill/modules/image-handler.md) and use `scripts/push-image.sh`
6. Phase 6: Read [modules/config-guide.md](/home/shishupei/app/vllm-skill/modules/config-guide.md)
7. Phase 7: Read [modules/k8s-yaml-generator.md](/home/shishupei/app/vllm-skill/modules/k8s-yaml-generator.md) and fill `templates/k8s-namespace.yaml`, `templates/k8s-configmap.yaml`, `templates/k8s-deployment.yaml`, `templates/k8s-service.yaml`, and `templates/apply-all.sh`
8. Phase 8: Read [modules/k8s-apply-guide.md](/home/shishupei/app/vllm-skill/modules/k8s-apply-guide.md)
9. Phase 9: Read [modules/container-env-detector.md](/home/shishupei/app/vllm-skill/modules/container-env-detector.md) and use `scripts/detect-container-npu.sh`
10. Phase 10: Read [modules/deploy-generator.md](/home/shishupei/app/vllm-skill/modules/deploy-generator.md) and fill `templates/deploy.sh`
11. Phase 11: Read [modules/deploy-execution-guide.md](/home/shishupei/app/vllm-skill/modules/deploy-execution-guide.md)
12. Phase 12: Read [modules/output-guide.md](/home/shishupei/app/vllm-skill/modules/output-guide.md)

## Output

The final delivery should be a `.vllm-deploy/k8s/` directory containing:

- `README.md`
- `namespace.yaml`
- `configmap.yaml`
- `deployment-node1.yaml`
- `deployment-node2.yaml`
- `service.yaml`
- `apply-all.sh`
- `deploy.sh`
```

- [ ] **Step 3: Create `skill.md` as the README-compatible entry**

Create:

```markdown
# vLLM-Deploy Skill

该文档是 `SKILL.md` 的兼容入口，供依赖 README 目录约定的环境使用。

## 使用时机

当用户需要基于 vLLM-Ascend 教程页面，在 Kubernetes 集群上完成模型部署准备、镜像处理、YAML 生成和 Pod 内部署脚本生成时，使用该 skill。

## 执行环境

- Kubernetes 管理节点
- 已安装并配置 `kubectl`
- 能够访问 Docker 或兼容镜像工具

## Phase 流程

1. Phase 1 使用 `modules/model-list-fetcher.md`
2. Phase 2 使用 `modules/user-selector.md`
3. Phase 3 使用 `modules/doc-parser.md`
4. Phase 4 使用 `modules/k8s-env-detector.md`
5. Phase 5 使用 `modules/image-handler.md`
6. Phase 6 使用 `modules/config-guide.md`
7. Phase 7 使用 `modules/k8s-yaml-generator.md`
8. Phase 8 使用 `modules/k8s-apply-guide.md`
9. Phase 9 使用 `modules/container-env-detector.md`
10. Phase 10 使用 `modules/deploy-generator.md`
11. Phase 11 使用 `modules/deploy-execution-guide.md`
12. Phase 12 使用 `modules/output-guide.md`

## 关联模板

- `templates/k8s-namespace.yaml`
- `templates/k8s-configmap.yaml`
- `templates/k8s-deployment.yaml`
- `templates/k8s-service.yaml`
- `templates/deploy.sh`
- `templates/apply-all.sh`
```

- [ ] **Step 4: Create `skill.yaml` metadata**

Create:

```yaml
name: vllm-deploy
description: Use when deploying vLLM-Ascend models on Kubernetes and you need a phase-based skill that fetches docs, inspects the cluster, prepares images, generates manifests, and produces a final deploy script
```

- [ ] **Step 5: Run the entry checks and verify they pass**

Run:

```bash
rg -n '^---$|^name: vllm-deploy$|^description: Use when' SKILL.md
rg -n 'Phase 1|Phase 12|modules/model-list-fetcher.md|templates/apply-all.sh' skill.md
rg -n '^name: vllm-deploy$|^description:' skill.yaml
```

Expected:

```text
All commands succeed and show the required markers.
```

### Task 3: Rebuild The 12 Module Guides

**Files:**
- Create: `modules/model-list-fetcher.md`
- Create: `modules/user-selector.md`
- Create: `modules/doc-parser.md`
- Create: `modules/k8s-env-detector.md`
- Create: `modules/image-handler.md`
- Create: `modules/config-guide.md`
- Create: `modules/k8s-yaml-generator.md`
- Create: `modules/k8s-apply-guide.md`
- Create: `modules/container-env-detector.md`
- Create: `modules/deploy-generator.md`
- Create: `modules/deploy-execution-guide.md`
- Create: `modules/output-guide.md`
- Test: `modules/*.md`

- [ ] **Step 1: Write the failing phase coverage check**

Run:

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

Expected:

```text
The command exits non-zero because the module files are still missing.
```

- [ ] **Step 2: Create Phase 1 to Phase 4 module documents**

Create:

```markdown
Each of the following files uses this structure:

# Phase N: <标题>

## 目的
一句话说明该 phase 负责什么。

## 输入
- 列出上一个 phase 产物或用户输入

## 执行位置
- 说明是在管理节点、本地终端还是 Pod 内执行

## 步骤
1. 按 README 列出处理步骤
2. 标明何时调用脚本
3. 标明需要向用户展示什么结果

## 输出
- 给出 JSON 或文件级输出示例

## 失败处理
- 覆盖 README 对应的失败场景

## 关联资源
- 指向对应脚本或模板
```

Apply the structure with README-specific content to:

```text
modules/model-list-fetcher.md
modules/user-selector.md
modules/doc-parser.md
modules/k8s-env-detector.md
```

- [ ] **Step 3: Create Phase 5 to Phase 8 module documents**

Apply the same structure with README-specific content to:

```text
modules/image-handler.md
modules/config-guide.md
modules/k8s-yaml-generator.md
modules/k8s-apply-guide.md
```

Key requirements:

```text
- Phase 5 must document source image, target image registry, and docker login / pull / tag / push flow.
- Phase 6 must document namespace, model path, performance parameters, and PD separation prompts.
- Phase 7 must document YAML generation outputs under .vllm-deploy/k8s/.
- Phase 8 must preserve the manual apply guidance from the README.
```

- [ ] **Step 4: Create Phase 9 to Phase 12 module documents**

Apply the same structure with README-specific content to:

```text
modules/container-env-detector.md
modules/deploy-generator.md
modules/deploy-execution-guide.md
modules/output-guide.md
```

Key requirements:

```text
- Phase 9 must document pod status checks and NPU mapping verification.
- Phase 10 must document how tensor parallel size is derived from the detected NPU count.
- Phase 11 must preserve manual user confirmation before running deploy.sh in the pod.
- Phase 12 must document the final delivery tree including README.md, YAML files, apply-all.sh, and deploy.sh.
```

- [ ] **Step 5: Verify module coverage and content markers**

Run:

```bash
for file in modules/*.md; do
  rg -n '^## 目的$|^## 输入$|^## 执行位置$|^## 步骤$|^## 输出$|^## 失败处理$|^## 关联资源$' "$file" >/dev/null || exit 1
done
rg -n 'Phase 8|手动 apply|apply-all.sh' modules/k8s-apply-guide.md
rg -n 'Pod|NPU|deploy.sh' modules/container-env-detector.md modules/deploy-generator.md modules/deploy-execution-guide.md
```

Expected:

```text
All module files exist, expose the common section structure, and include the phase-specific markers.
```

### Task 4: Rebuild The 5 Helper Scripts

**Files:**
- Create: `scripts/fetch-model-list.sh`
- Create: `scripts/parse-model-doc.sh`
- Create: `scripts/detect-k8s-env.sh`
- Create: `scripts/detect-container-npu.sh`
- Create: `scripts/push-image.sh`
- Test: `scripts/*.sh`

- [ ] **Step 1: Write the failing script interface checks**

Run:

```bash
bash scripts/fetch-model-list.sh --help
bash scripts/parse-model-doc.sh --help
bash scripts/detect-k8s-env.sh --help
bash scripts/detect-container-npu.sh --help
bash scripts/push-image.sh --help
```

Expected:

```text
The commands fail because the scripts do not exist yet.
```

- [ ] **Step 2: Create `scripts/fetch-model-list.sh` and `scripts/parse-model-doc.sh`**

Create these scripts with:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: <script> [options]
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  # Parse args, validate required URL input, call curl, and emit structured JSON-like output.
}

main "$@"
```

Implementation rules:

```text
- fetch-model-list.sh must accept a URL and extract anchor text plus href values for model entries.
- parse-model-doc.sh must accept model URL, hardware spec, and deployment mode.
- both scripts must fail clearly when curl is unavailable or required args are missing.
```

- [ ] **Step 3: Create `scripts/detect-k8s-env.sh` and `scripts/detect-container-npu.sh`**

Use this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: <script> [options]
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  # Parse args, validate kubectl access, run inspection commands, and print structured output.
}

main "$@"
```

Implementation rules:

```text
- detect-k8s-env.sh must inspect kubectl availability, cluster reachability, nodes, IPs, and NPU hints.
- detect-container-npu.sh must inspect a namespace and pod, execute into the container if needed, and summarize mapped devices.
- both scripts must stop with a clear error when kubectl is missing or the namespace/pod inputs are absent.
```

- [ ] **Step 4: Create `scripts/push-image.sh` and mark all scripts executable**

Create:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: push-image.sh --source-image IMAGE --target-image IMAGE [--docker-username USERNAME]
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  # Parse args, require docker, optionally login, then pull, tag, and push.
}

main "$@"
```

Run:

```bash
chmod +x scripts/fetch-model-list.sh scripts/parse-model-doc.sh scripts/detect-k8s-env.sh scripts/detect-container-npu.sh scripts/push-image.sh
```

- [ ] **Step 5: Verify script help, executability, and missing-arg failures**

Run:

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

Expected:

```text
Every script is executable, every --help call succeeds, and every missing-argument invocation exits non-zero.
```

### Task 5: Rebuild The 6 Templates

**Files:**
- Create: `templates/k8s-namespace.yaml`
- Create: `templates/k8s-configmap.yaml`
- Create: `templates/k8s-deployment.yaml`
- Create: `templates/k8s-service.yaml`
- Create: `templates/deploy.sh`
- Create: `templates/apply-all.sh`
- Test: `templates/*`

- [ ] **Step 1: Write the failing template presence checks**

Run:

```bash
test -f templates/k8s-namespace.yaml
test -f templates/k8s-configmap.yaml
test -f templates/k8s-deployment.yaml
test -f templates/k8s-service.yaml
test -f templates/deploy.sh
test -f templates/apply-all.sh
```

Expected:

```text
The commands fail because the templates are not present yet.
```

- [ ] **Step 2: Create the Kubernetes YAML templates**

Create:

```yaml
# templates/k8s-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${MODEL_NAME}
```

```yaml
# templates/k8s-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${MODEL_NAME}-config
  namespace: ${NAMESPACE}
data:
  MODEL_PATH: "${MODEL_PATH}"
  MAX_MODEL_LEN: "${MAX_MODEL_LEN}"
  MAX_NUM_SEQS: "${MAX_NUM_SEQS}"
  TENSOR_PARALLEL_SIZE: "${TENSOR_PARALLEL_SIZE}"
```

```yaml
# templates/k8s-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ${MODEL_NAME}-service
  namespace: ${NAMESPACE}
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: ${MODEL_NAME}
  ports:
    - port: ${SERVICE_PORT}
      targetPort: ${SERVICE_PORT}
```

- [ ] **Step 3: Create the deployment template with README placeholders**

Create:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${MODEL_NAME}-${NODE_NAME}
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ${MODEL_NAME}
      app.kubernetes.io/node: ${NODE_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${MODEL_NAME}
        app.kubernetes.io/node: ${NODE_NAME}
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${NODE_NAME}
      containers:
        - name: ${MODEL_NAME}
          image: ${IMAGE}
          resources:
            limits:
              ${NPU_RESOURCE_TYPE}: ${NPU_COUNT}
          volumeMounts:
            - name: model-volume
              mountPath: ${MODEL_MOUNT_PATH}
      volumes:
        - name: model-volume
          hostPath:
            path: ${MODEL_PATH_HOST}
```

- [ ] **Step 4: Create `templates/deploy.sh` and `templates/apply-all.sh`**

Create:

```bash
#!/usr/bin/env bash
set -euo pipefail

vllm serve "${MODEL_PATH}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}"
```

```bash
#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment-node1.yaml
```

Extend the scripts so they also:

```text
- include README-aligned placeholders for PD separation and distributed deployment fields
- preserve ${MASTER_ADDR}, ${MASTER_PORT}, and ${RANK} in deploy.sh
- preserve ${NAMESPACE} in apply-all.sh and wait for pods to become ready
```

- [ ] **Step 5: Verify template completeness**

Run:

```bash
rg -n '\${NAMESPACE}|\${MODEL_NAME}' templates/k8s-namespace.yaml
rg -n '\${MODEL_PATH}|\${MAX_MODEL_LEN}|\${MAX_NUM_SEQS}|\${TENSOR_PARALLEL_SIZE}' templates/k8s-configmap.yaml
rg -n '\${NODE_NAME}|\${IMAGE}|\${NPU_RESOURCE_TYPE}|\${NPU_COUNT}|\${MODEL_MOUNT_PATH}|\${MODEL_PATH_HOST}' templates/k8s-deployment.yaml
rg -n '\${SERVICE_PORT}' templates/k8s-service.yaml
rg -n '\${MODEL_PATH}|\${MASTER_ADDR}|\${MASTER_PORT}|\${RANK}' templates/deploy.sh
rg -n '\${NAMESPACE}' templates/apply-all.sh
```

Expected:

```text
Every template exists and exposes the placeholders required by the README.
```

### Task 6: Repository-Wide Verification And Finish

**Files:**
- Modify: `SKILL.md`
- Modify: `skill.md`
- Modify: `skill.yaml`
- Modify: `modules/*.md`
- Modify: `scripts/*.sh`
- Modify: `templates/*`

- [ ] **Step 1: Verify the full file set exists**

Run:

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

Expected:

```text
The command completes successfully.
```

- [ ] **Step 2: Verify README contract markers**

Run:

```bash
rg -n '12-phase|12 个 phase|Phase 12|apply-all.sh|deploy.sh' SKILL.md skill.md
rg -n 'docker|kubectl|NPU|Pod|ConfigMap|Service|Deployment' modules/*.md
rg -n 'Usage:' scripts/*.sh
rg -n '\${[A-Z0-9_]+}' templates/*
```

Expected:

```text
The repository shows the expected skill-flow, environment, and placeholder markers.
```

- [ ] **Step 3: Verify script interfaces again after final edits**

Run:

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

Expected:

```text
Help paths remain green and missing-argument paths remain red.
```

- [ ] **Step 4: Inspect the worktree for unintended files**

Run:

```bash
git status --short
```

Expected:

```text
Only the rebuilt skill files and the two docs under docs/superpowers/ appear as additions or modifications.
```

- [ ] **Step 5: Hand off with residual risks**

Report:

```text
- The package is rebuilt from README rather than the deleted prior implementation.
- The shell parsers are intentionally minimal and may need refinement for future upstream HTML changes.
- Cluster- and registry-mutating actions are documented and scripted, but still depend on real environment validation.
```
