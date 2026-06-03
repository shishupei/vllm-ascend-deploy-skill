# vLLM Deploy Skill Evolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the vLLM deploy skills contract-stable and locally verifiable for the single-node and multi-node deployment flows without requiring a real Kubernetes cluster.

**Architecture:** First add local fixture-driven verification so regressions are visible without a real Kubernetes cluster. Then fix the blocking runtime contracts: Kubernetes-safe resource names, Phase 9 to Phase 10 deploy script generation, multi-node Ray startup semantics, dependency checks, and stale module documentation. Keep shell scripts deterministic and keep Skill/module markdown as orchestration guidance.

**Tech Stack:** Bash, jq, envsubst, Kubernetes YAML templates, markdown Skill modules, fixture-based shell verification.

---

## Scope

This plan covers the first evolution batch:

- Phase 0: freeze the deployment artifact contract
- Phase 1: fix merge-blocking behavior found in `docs/superpowers/2026-05-21-vllm-deploy-code-review.md`
- Phase 2: add repeatable local verification

This plan does not require a real K8s or Ascend NPU environment. Real cluster validation is explicitly out of scope for this batch and must not block completion of this plan.

## Acceptance Strategy

Current environment constraint:

- No available Kubernetes cluster
- No available Ascend NPU worker node
- No real Pod for container-side detection

This batch therefore uses local acceptance only:

- Shell syntax checks for all changed scripts
- Fixture-based rendering for `single_node` and `multi_node`
- Static validation of generated YAML and shell artifacts
- Documentation consistency scans for stale output names and stale multi-node instructions

Deferred acceptance belongs to a later environment-validation plan:

- `kubectl apply` against a real API server
- Pod scheduling and NPU device allocation
- `/scripts/detect-npu.sh` inside a real Pod
- `ray status` and vLLM-Ray multi-node startup
- `/health` and `/v1/models` calls against a live service

Completion criteria for this plan:

```bash
bash -n vllm-deploy-prepare/scripts/*.sh vllm-deploy-execute/scripts/*.sh
bash tests/run-local-verification.sh
rg -n '\$\{[A-Z0-9_]+\}' /tmp/vllm-deploy-skill-tests
rg -n 'namespace.yaml|configmap.yaml|deployment.yaml|service.yaml|scripts-configmap.yaml|WORKER_PODS|container-detection.json' README.md vllm-deploy-execute/SKILL.md vllm-deploy-execute/modules
```

Expected result:

- `bash -n` exits 0
- `tests/run-local-verification.sh` prints `local verification passed`
- both `rg` scans produce no output

Do not claim real Kubernetes deployment success from this plan.

## File Structure

| Path | Responsibility |
|------|----------------|
| `vllm-deploy-execute/scripts/fill-template.sh` | Generate K8s YAML and `apply-all.sh`; no longer generate `deploy.sh` for single/multi modes. |
| `vllm-deploy-execute/scripts/generate-deploy.sh` | Generate `deploy.sh` after Phase 9 from container NPU detection. |
| `vllm-deploy-execute/scripts/detect-container-npu.sh` | Emit container NPU JSON used by `generate-deploy.sh`. |
| `vllm-deploy-execute/scripts/validate-generated.sh` | New static validator for generated artifacts. |
| `vllm-deploy-prepare/templates/*.yaml` | Consume normalized resource names and keep original model name only where user-facing. |
| `vllm-deploy-execute/modules/*.md` | Describe the actual phase contract and generated artifacts. |
| `vllm-deploy-execute/SKILL.md` | State runtime dependencies and phase flow. |
| `README.md` | User-facing overview and prerequisites. |
| `tests/fixtures/*` | Minimal config, detection, node selection, and expected output samples. |
| `tests/run-local-verification.sh` | Local test runner for fixture rendering, generation, and validation. |

## Contract Decisions

- `MODEL_NAME` remains the original model name from `config.json.selected_model`, for `vllm serve --served-model-name`.
- `MODEL_RESOURCE_NAME` is a lowercase DNS-1123-safe resource slug derived from `MODEL_NAME`, for K8s resource names, labels, selectors, and README `kubectl -l` selectors.
- `fill-template.sh` generates YAML, `apply-all.sh`, and deployment README. It must not generate `deploy.sh` for `single_node` or `multi_node`.
- `generate-deploy.sh` runs after Phase 9 and consumes `.vllm-deploy/container-detection-result.json`.
- Multi-node Worker Pods join the Ray cluster through their container command. Only the Master Pod receives and executes `deploy.sh`.
- `pd_separate` and `ha_active_standby` keep embedded startup commands and do not require `deploy.sh`.

---

### Task 1: Add Local Fixture Verification Harness

**Files:**
- Create: `tests/fixtures/single-node/config.json`
- Create: `tests/fixtures/single-node/detection-result.json`
- Create: `tests/fixtures/single-node/selected-nodes.json`
- Create: `tests/fixtures/single-node/container-detection-result.json`
- Create: `tests/fixtures/multi-node/config.json`
- Create: `tests/fixtures/multi-node/detection-result.json`
- Create: `tests/fixtures/multi-node/selected-nodes.json`
- Create: `tests/fixtures/multi-node/container-detection-result.json`
- Create: `tests/run-local-verification.sh`

- [ ] **Step 1: Create single-node fixture config**

Create `tests/fixtures/single-node/config.json`:

```json
{
  "selected_model": "GLM-5",
  "hw_spec": "A3",
  "deploy_mode": "single_node",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 16,
  "master_port": 29500
}
```

- [ ] **Step 2: Create single-node fixture detection files**

Create `tests/fixtures/single-node/detection-result.json`:

```json
{
  "kubectl_available": true,
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-a",
      "ip": "192.168.1.10",
      "npu_count": 16,
      "npu_type": "huawei.com/Ascend910"
    }
  ],
  "recommended_nodes": ["node-a"]
}
```

Create `tests/fixtures/single-node/selected-nodes.json`:

```json
{
  "master_node": "node-a",
  "nodes": [
    {
      "name": "node-a",
      "ip": "192.168.1.10",
      "npu_count": 16
    }
  ]
}
```

Create `tests/fixtures/single-node/container-detection-result.json`:

```json
{
  "pod_name": "vllm-glm-5",
  "npu_devices": ["/dev/davinci0", "/dev/davinci1"],
  "npu_count": 2,
  "npu_smi_available": true
}
```

- [ ] **Step 3: Create multi-node fixture config**

Create `tests/fixtures/multi-node/config.json`:

```json
{
  "selected_model": "Qwen2.5-7B",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "namespace": "vllm-qwen",
  "model_path": "/data/models/Qwen2.5-7B",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 32,
  "master_port": 29500
}
```

- [ ] **Step 4: Create multi-node fixture detection files**

Create `tests/fixtures/multi-node/detection-result.json`:

```json
{
  "kubectl_available": true,
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-a",
      "ip": "192.168.1.10",
      "npu_count": 16,
      "npu_type": "huawei.com/Ascend910"
    },
    {
      "name": "node-b",
      "ip": "192.168.1.11",
      "npu_count": 16,
      "npu_type": "huawei.com/Ascend910"
    }
  ],
  "recommended_nodes": ["node-a", "node-b"]
}
```

Create `tests/fixtures/multi-node/selected-nodes.json`:

```json
{
  "master_node": "node-a",
  "nodes": [
    {
      "name": "node-a",
      "ip": "192.168.1.10",
      "npu_count": 16
    },
    {
      "name": "node-b",
      "ip": "192.168.1.11",
      "npu_count": 16
    }
  ]
}
```

Create `tests/fixtures/multi-node/container-detection-result.json`:

```json
{
  "pod_name": "vllm-qwen2-5-7b-master",
  "npu_devices": ["/dev/davinci0", "/dev/davinci1", "/dev/davinci2", "/dev/davinci3"],
  "npu_count": 4,
  "npu_smi_available": true
}
```

- [ ] **Step 5: Create initial local verification runner**

Create `tests/run-local-verification.sh`:

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/vllm-deploy-skill-tests"

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing command: $cmd" >&2
        exit 1
    fi
}

prepare_case() {
    local case_name="$1"
    local case_dir="$TMP_ROOT/$case_name"

    rm -rf "$case_dir"
    mkdir -p "$case_dir/.vllm-deploy/templates" "$case_dir/.vllm-deploy/k8s"
    cp "$ROOT_DIR/tests/fixtures/$case_name/config.json" "$case_dir/.vllm-deploy/config.json"
    cp "$ROOT_DIR/tests/fixtures/$case_name/detection-result.json" "$case_dir/.vllm-deploy/detection-result.json"
    cp "$ROOT_DIR/tests/fixtures/$case_name/selected-nodes.json" "$case_dir/.vllm-deploy/selected-nodes.json"
    cp "$ROOT_DIR/tests/fixtures/$case_name/container-detection-result.json" "$case_dir/.vllm-deploy/container-detection-result.json"
    cp "$ROOT_DIR"/vllm-deploy-prepare/templates/*.yaml "$case_dir/.vllm-deploy/templates/"

    echo "$case_dir"
}

run_case() {
    local case_name="$1"
    local case_dir
    case_dir="$(prepare_case "$case_name")"

    echo "== $case_name =="
    (
        cd "$case_dir"
        bash "$ROOT_DIR/vllm-deploy-execute/scripts/fill-template.sh" \
            .vllm-deploy/config.json \
            .vllm-deploy/detection-result.json \
            .vllm-deploy/selected-nodes.json \
            .vllm-deploy/k8s
        bash "$ROOT_DIR/vllm-deploy-execute/scripts/generate-deploy.sh" \
            .vllm-deploy/config.json \
            .vllm-deploy/container-detection-result.json \
            .vllm-deploy/k8s
        bash "$ROOT_DIR/vllm-deploy-execute/scripts/validate-generated.sh" \
            .vllm-deploy/config.json \
            .vllm-deploy/k8s
    )
}

require_cmd jq
require_cmd envsubst

run_case single-node
run_case multi-node

echo "local verification passed"
```

- [ ] **Step 6: Make test runner executable and run it to capture current failures**

Run:

```bash
chmod +x tests/run-local-verification.sh
bash tests/run-local-verification.sh
```

Expected before later tasks:

```text
bash: .../vllm-deploy-execute/scripts/validate-generated.sh: No such file or directory
```

- [ ] **Step 7: Commit fixtures and runner**

```bash
git add tests/fixtures tests/run-local-verification.sh
git commit -m "test: add local fixture verification harness for deploy skill"
```

---

### Task 2: Add Generated Artifact Validator

**Files:**
- Create: `vllm-deploy-execute/scripts/validate-generated.sh`
- Modify: `tests/run-local-verification.sh`

- [ ] **Step 1: Write validator script**

Create `vllm-deploy-execute/scripts/validate-generated.sh`:

```bash
#!/bin/bash
set -euo pipefail

CONFIG_FILE="${1:-.vllm-deploy/config.json}"
K8S_DIR="${2:-.vllm-deploy/k8s}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found at $CONFIG_FILE" >&2
    exit 1
fi

if [ ! -d "$K8S_DIR" ]; then
    echo "Error: k8s output directory not found at $K8S_DIR" >&2
    exit 1
fi

DEPLOY_MODE=$(jq -r '.deploy_mode' "$CONFIG_FILE")
MODEL_NAME=$(jq -r '.selected_model' "$CONFIG_FILE")

slugify_model_name() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
        | cut -c1-63 \
        | sed -E 's/-+$//'
}

RESOURCE_NAME=$(slugify_model_name "$MODEL_NAME")

if [ -z "$RESOURCE_NAME" ]; then
    echo "Error: selected_model '$MODEL_NAME' cannot be converted to a Kubernetes resource name" >&2
    exit 1
fi

if [ ! -f "$K8S_DIR/all.yaml" ]; then
    echo "Error: missing $K8S_DIR/all.yaml" >&2
    exit 1
fi

if rg -n '\$\{[A-Z0-9_]+\}' "$K8S_DIR" >/tmp/vllm-unresolved-vars.txt; then
    echo "Error: generated artifacts contain unresolved template variables:" >&2
    cat /tmp/vllm-unresolved-vars.txt >&2
    exit 1
fi

if rg -n 'name: .*[^a-z0-9.-]' "$K8S_DIR/all.yaml" >/tmp/vllm-name-lines.txt; then
    while IFS= read -r line; do
        name_value=$(printf '%s' "$line" | sed -E 's/^.*name:[[:space:]]*"?([^"#]+)"?.*$/\1/')
        if ! printf '%s' "$name_value" | grep -Eq '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$'; then
            echo "Error: generated Kubernetes name is not DNS-safe: $name_value" >&2
            exit 1
        fi
    done </tmp/vllm-name-lines.txt
fi

if ! rg -n "model: ${RESOURCE_NAME}" "$K8S_DIR/all.yaml" >/dev/null; then
    echo "Error: all.yaml does not contain normalized model label: $RESOURCE_NAME" >&2
    exit 1
fi

case "$DEPLOY_MODE" in
    single_node|multi_node)
        if [ ! -f "$K8S_DIR/deploy.sh" ]; then
            echo "Error: $DEPLOY_MODE requires generated deploy.sh after Phase 9" >&2
            exit 1
        fi
        ;;
    pd_separate|ha_active_standby)
        if [ -f "$K8S_DIR/deploy.sh" ]; then
            echo "Error: $DEPLOY_MODE should not generate deploy.sh" >&2
            exit 1
        fi
        ;;
    *)
        echo "Error: unknown deploy_mode '$DEPLOY_MODE'" >&2
        exit 1
        ;;
esac

echo "validated generated artifacts for $DEPLOY_MODE ($RESOURCE_NAME)"
```

- [ ] **Step 2: Make validator executable**

Run:

```bash
chmod +x vllm-deploy-execute/scripts/validate-generated.sh
```

- [ ] **Step 3: Run local verification and confirm current resource-name failure**

Run:

```bash
bash tests/run-local-verification.sh
```

Expected before Task 3:

```text
Error: all.yaml does not contain normalized model label: glm-5
```

- [ ] **Step 4: Commit validator**

```bash
git add vllm-deploy-execute/scripts/validate-generated.sh tests/run-local-verification.sh
git commit -m "test: validate generated deployment artifacts"
```

---

### Task 3: Add Kubernetes-Safe Model Resource Names

**Files:**
- Modify: `vllm-deploy-execute/scripts/fill-template.sh`
- Modify: `vllm-deploy-execute/scripts/generate-deploy.sh`
- Modify: `vllm-deploy-prepare/templates/single-node.yaml`
- Modify: `vllm-deploy-prepare/templates/multi-node-master.yaml`
- Modify: `vllm-deploy-prepare/templates/multi-node-worker.yaml`
- Modify: `vllm-deploy-prepare/templates/multi-node.yaml`
- Modify: `vllm-deploy-prepare/templates/pd-separate.yaml`
- Modify: `vllm-deploy-prepare/templates/pd-separate-kthena.yaml`
- Modify: `vllm-deploy-prepare/templates/ha-active-standby.yaml`

- [ ] **Step 1: Add slug helper to `fill-template.sh`**

In `vllm-deploy-execute/scripts/fill-template.sh`, after config reads near `MODEL_NAME`, add:

```bash
slugify_k8s_name() {
    local input="$1"
    printf '%s' "$input" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
        | cut -c1-63 \
        | sed -E 's/-+$//'
}

export MODEL_RESOURCE_NAME=$(slugify_k8s_name "$MODEL_NAME")
if [ -z "$MODEL_RESOURCE_NAME" ]; then
    echo "Error: selected_model '$MODEL_NAME' cannot be converted to a Kubernetes resource name" >&2
    exit 1
fi
```

Add `$MODEL_RESOURCE_NAME` to `ALL_VARS`.

- [ ] **Step 2: Replace K8s identity fields in templates**

For every template in this task:

- Replace resource names like `vllm-${MODEL_NAME}` with `vllm-${MODEL_RESOURCE_NAME}`.
- Replace labels/selectors `model: ${MODEL_NAME}` with `model: ${MODEL_RESOURCE_NAME}`.
- Keep command arguments `--served-model-name ${MODEL_NAME}` or `"${MODEL_NAME}"` unchanged.
- In Kthena template, keep user-facing model values only if the CRD explicitly expects model display names; otherwise use `MODEL_RESOURCE_NAME` for `metadata.name`, `modelserving.volcano.sh/name`, and `modelServerName` references.

Concrete replacements:

```text
vllm-${MODEL_NAME} -> vllm-${MODEL_RESOURCE_NAME}
${MODEL_NAME}-server -> ${MODEL_RESOURCE_NAME}-server
${MODEL_NAME}-route -> ${MODEL_RESOURCE_NAME}-route
model: ${MODEL_NAME} -> model: ${MODEL_RESOURCE_NAME}
modelserving.volcano.sh/name: ${MODEL_NAME} -> modelserving.volcano.sh/name: ${MODEL_RESOURCE_NAME}
modelServerName: "${MODEL_NAME}-server" -> modelServerName: "${MODEL_RESOURCE_NAME}-server"
```

- [ ] **Step 3: Update generated README selectors**

In `fill-template.sh`, replace generated README selectors:

```bash
-l app=vllm-deploy,model=${MODEL_NAME}
```

with:

```bash
-l app=vllm-deploy,model=${MODEL_RESOURCE_NAME}
```

Keep the displayed model line as `${MODEL_NAME}`.

- [ ] **Step 4: Add same slug helper to `generate-deploy.sh` only for comments/output**

In `vllm-deploy-execute/scripts/generate-deploy.sh`, keep `MODEL_NAME` for `--served-model-name`. If the script emits instructions with selectors later, use the same `MODEL_RESOURCE_NAME` helper.

- [ ] **Step 5: Run local verification**

Run:

```bash
bash tests/run-local-verification.sh
```

Expected after this task:

```text
validated generated artifacts for single_node (glm-5)
validated generated artifacts for multi_node (qwen2-5-7b)
local verification passed
```

- [ ] **Step 6: Commit normalized resource names**

```bash
git add vllm-deploy-execute/scripts/fill-template.sh vllm-deploy-execute/scripts/generate-deploy.sh vllm-deploy-prepare/templates tests
git commit -m "fix: normalize model names for Kubernetes resources"
```

---

### Task 4: Move Deploy Script Generation Out of Template Fill

**Files:**
- Modify: `vllm-deploy-execute/scripts/fill-template.sh`
- Modify: `vllm-deploy-execute/scripts/generate-deploy.sh`
- Modify: `tests/run-local-verification.sh`

- [ ] **Step 1: Write failing check for no early deploy.sh**

In `tests/run-local-verification.sh`, after `fill-template.sh` and before `generate-deploy.sh`, add:

```bash
        if [ -f .vllm-deploy/k8s/deploy.sh ]; then
            echo "deploy.sh must not be generated before Phase 9 container detection" >&2
            exit 1
        fi
```

Run:

```bash
bash tests/run-local-verification.sh
```

Expected before implementation:

```text
deploy.sh must not be generated before Phase 9 container detection
```

- [ ] **Step 2: Remove deploy.sh generation block from `fill-template.sh`**

Delete the block that starts with:

```bash
# 根据部署模式生成 deploy.sh（仅 single_node 和 multi_node 需要手动执行）
```

and ends after:

```bash
echo "Generated: $OUTPUT_DIR/deploy.sh"
```

Do not delete `apply-all.sh` or README generation.

- [ ] **Step 3: Standardize Phase 9 detection file name in `generate-deploy.sh`**

Change:

```bash
CONTAINER_DETECTION_FILE="${2:-.vllm-deploy/container-detection.json}"
```

to:

```bash
CONTAINER_DETECTION_FILE="${2:-.vllm-deploy/container-detection-result.json}"
```

Also update the missing-file error message to say `container-detection-result.json`.

- [ ] **Step 4: Make `generate-deploy.sh` validate dependencies and JSON**

At the top of `generate-deploy.sh`, after `set -e`, change to:

```bash
set -euo pipefail

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' not found" >&2
        exit 1
    fi
}

require_cmd jq
```

- [ ] **Step 5: Run local verification**

Run:

```bash
bash tests/run-local-verification.sh
```

Expected:

```text
validated generated artifacts for single_node (glm-5)
validated generated artifacts for multi_node (qwen2-5-7b)
local verification passed
```

- [ ] **Step 6: Commit Phase 10 split**

```bash
git add vllm-deploy-execute/scripts/fill-template.sh vllm-deploy-execute/scripts/generate-deploy.sh tests/run-local-verification.sh
git commit -m "fix: generate deploy script after container detection"
```

---

### Task 5: Correct Multi-Node Deployment Instructions

**Files:**
- Modify: `vllm-deploy-execute/scripts/fill-template.sh`
- Modify: `vllm-deploy-execute/scripts/generate-deploy.sh`
- Modify: `vllm-deploy-execute/modules/deploy-execution-guide.md`
- Modify: `vllm-deploy-execute/modules/deploy-generator.md`
- Modify: `README.md`

- [ ] **Step 1: Update `generate-deploy.sh` multi-node script comment**

Ensure the multi-node generated `deploy.sh` header says:

```bash
# vLLM 分布式部署脚本（多节点 Master 专用）
# Worker Pod 只通过容器启动命令加入 Ray 集群，不执行此脚本。
```

- [ ] **Step 2: Update generated multi-node README in `fill-template.sh`**

Replace the multi-node step that loops over Worker Pods and executes `deploy.sh`.

Use this command block instead:

```bash
# 确认 Worker Pod 已加入 Ray 集群后，只在 Master Pod 执行 deploy.sh
MASTER_POD=$(kubectl get pods -n ${NAMESPACE} -l app=vllm-deploy,model=${MODEL_RESOURCE_NAME},role=master -o jsonpath='{.items[0].metadata.name}')
kubectl cp deploy.sh -n ${NAMESPACE} "$MASTER_POD":/tmp/deploy.sh
kubectl exec -n ${NAMESPACE} "$MASTER_POD" -- bash /tmp/deploy.sh
```

Add a note:

```text
Worker Pod 不执行 deploy.sh；它们在容器启动命令中执行 ray start --address 并作为 Ray worker 提供资源。
```

- [ ] **Step 3: Update module docs**

In `deploy-execution-guide.md` and `deploy-generator.md`, make these statements consistent:

- `single_node`: copy and execute `deploy.sh` in the only Pod.
- `multi_node`: copy and execute `deploy.sh` only in the Master Pod.
- Worker Pods must be Running and joined to Ray before Master `deploy.sh` starts.
- `pd_separate` and `ha_active_standby`: no separate `deploy.sh`.

- [ ] **Step 4: Update README multi-node section**

In `README.md`, replace the current instruction that says “先在 master Pod 内执行 deploy.sh ... 再在 worker Pod 内执行同一个 deploy.sh” with:

```text
多节点模式下，Worker Pod 通过模板中的 ray start --address 加入 Ray 集群；deploy.sh 只复制并执行到 Master Pod。
```

- [ ] **Step 5: Add verification grep to test runner**

In `tests/run-local-verification.sh`, after multi-node validation, add:

```bash
        if [ "$case_name" = "multi-node" ]; then
            if rg -n 'WORKER_PODS|role=worker.*deploy.sh|Worker.*deploy.sh' .vllm-deploy/k8s/README.md; then
                echo "multi-node README must not instruct Worker Pods to execute deploy.sh" >&2
                exit 1
            fi
        fi
```

- [ ] **Step 6: Run local verification**

```bash
bash tests/run-local-verification.sh
```

Expected:

```text
local verification passed
```

- [ ] **Step 7: Commit multi-node instruction fix**

```bash
git add README.md vllm-deploy-execute/scripts/fill-template.sh vllm-deploy-execute/scripts/generate-deploy.sh vllm-deploy-execute/modules/deploy-execution-guide.md vllm-deploy-execute/modules/deploy-generator.md tests/run-local-verification.sh
git commit -m "fix: run multi-node deploy script only on master pod"
```

---

### Task 6: Add Dependency Checks and Update Prerequisites

**Files:**
- Modify: `vllm-deploy-execute/scripts/fill-template.sh`
- Modify: `vllm-deploy-execute/scripts/detect-container-npu.sh`
- Modify: `vllm-deploy-execute/scripts/detect-k8s-env.sh`
- Modify: `vllm-deploy-execute/SKILL.md`
- Modify: `README.md`

- [ ] **Step 1: Add dependency checks to `fill-template.sh`**

After `set -e`, change to:

```bash
set -euo pipefail

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' not found" >&2
        exit 1
    fi
}

require_cmd jq
require_cmd envsubst
```

- [ ] **Step 2: Add dependency checks to `detect-container-npu.sh`**

After `set -e`, change to:

```bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: required command 'jq' not found" >&2
    exit 1
fi
```

- [ ] **Step 3: Add dependency checks to `detect-k8s-env.sh`**

Ensure the script checks:

```bash
command -v kubectl >/dev/null 2>&1
command -v jq >/dev/null 2>&1
```

If either is missing, print a clear error to stderr and exit non-zero.

- [ ] **Step 4: Update `vllm-deploy-execute/SKILL.md` prerequisites**

Add:

```markdown
- `jq` 已安装
- `envsubst` 已安装（通常来自 gettext 包）
```

- [ ] **Step 5: Update README prerequisites**

Change the execution-stage prerequisite from:

```markdown
- 执行阶段机器安装了 `kubectl` 和 `jq`
```

to:

```markdown
- 执行阶段机器安装了 `kubectl`、`jq` 和 `envsubst`（通常来自 gettext 包）
```

- [ ] **Step 6: Run syntax and local verification**

```bash
bash -n vllm-deploy-execute/scripts/fill-template.sh vllm-deploy-execute/scripts/detect-container-npu.sh vllm-deploy-execute/scripts/detect-k8s-env.sh vllm-deploy-execute/scripts/generate-deploy.sh vllm-deploy-execute/scripts/validate-generated.sh
bash tests/run-local-verification.sh
```

Expected:

```text
local verification passed
```

- [ ] **Step 7: Commit dependency checks**

```bash
git add README.md vllm-deploy-execute/SKILL.md vllm-deploy-execute/scripts
git commit -m "fix: declare and validate deploy execution dependencies"
```

---

### Task 7: Update Phase 8-10 Documentation Contracts

**Files:**
- Modify: `vllm-deploy-execute/modules/k8s-apply-guide.md`
- Modify: `vllm-deploy-execute/modules/yaml-generator.md`
- Modify: `vllm-deploy-execute/modules/container-env-detector.md`
- Modify: `vllm-deploy-execute/modules/deploy-generator.md`
- Modify: `vllm-deploy-execute/modules/deploy-execution-guide.md`
- Modify: `vllm-deploy-execute/SKILL.md`
- Modify: `README.md`

- [ ] **Step 1: Update Phase 8 apply guide**

In `k8s-apply-guide.md`, replace the old file list with:

```markdown
文件：
- all.yaml
- master.yaml（仅 multi_node）
- worker-*.yaml（仅 multi_node）
- apply-all.sh
- README.md
```

Replace manual apply commands with:

```bash
kubectl apply -f all.yaml
```

- [ ] **Step 2: Update YAML generator docs**

Ensure `yaml-generator.md` states:

- `fill-template.sh` creates `all.yaml`, optional `master.yaml`, optional `worker-*.yaml`, `apply-all.sh`, and `README.md`.
- `fill-template.sh` does not create `deploy.sh` for `single_node` or `multi_node`.
- `deploy.sh` is Phase 10 output from `generate-deploy.sh`.

- [ ] **Step 3: Update container detector docs**

In `container-env-detector.md`, state that Phase 9 output must be saved as:

```text
.vllm-deploy/container-detection-result.json
```

Add the command pattern:

```bash
kubectl exec -n ${NAMESPACE} ${POD_NAME} -- bash /scripts/detect-npu.sh > .vllm-deploy/container-detection-result.json
```

- [ ] **Step 4: Update deploy generator docs**

In `deploy-generator.md`, state:

- Input: `config.json` and `container-detection-result.json`
- Command: `bash vllm-deploy-execute/scripts/generate-deploy.sh .vllm-deploy/config.json .vllm-deploy/container-detection-result.json .vllm-deploy/k8s`
- Output: `deploy.sh` only for `single_node` and `multi_node`
- Multi-node deploy script is Master-only

- [ ] **Step 5: Update execute Skill flow**

In `vllm-deploy-execute/SKILL.md`, make Phase 10 explicitly call `scripts/generate-deploy.sh`.

- [ ] **Step 6: Run documentation consistency checks**

Run:

```bash
rg -n 'namespace.yaml|configmap.yaml|deployment.yaml|service.yaml|scripts-configmap.yaml|WORKER_PODS|container-detection.json' README.md vllm-deploy-execute/SKILL.md vllm-deploy-execute/modules
```

Expected:

```text
no output
```

- [ ] **Step 7: Commit doc contract updates**

```bash
git add README.md vllm-deploy-execute/SKILL.md vllm-deploy-execute/modules
git commit -m "docs: align execute skill phases with generated artifacts"
```

---

### Task 8: Final Verification and Review Update

**Files:**
- Modify: `docs/superpowers/2026-05-21-vllm-deploy-code-review.md`

- [ ] **Step 1: Run full local verification**

```bash
bash -n vllm-deploy-prepare/scripts/*.sh vllm-deploy-execute/scripts/*.sh
bash tests/run-local-verification.sh
rg -n '\$\{[A-Z0-9_]+\}' /tmp/vllm-deploy-skill-tests
rg -n 'namespace.yaml|configmap.yaml|deployment.yaml|service.yaml|scripts-configmap.yaml|WORKER_PODS|container-detection.json' README.md vllm-deploy-execute/SKILL.md vllm-deploy-execute/modules
```

Expected:

```text
local verification passed
```

The unresolved-variable `rg` command should produce no output.
The stale-doc `rg` command should produce no output.

- [ ] **Step 2: Update code review document status**

In `docs/superpowers/2026-05-21-vllm-deploy-code-review.md`, add a dated section:

```markdown
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
```

Do not mark real cluster deployment as verified.

- [ ] **Step 3: Check git status**

```bash
git status --short --branch
```

Expected:

```text
only intended files are modified
```

- [ ] **Step 4: Commit review update**

```bash
git add docs/superpowers/2026-05-21-vllm-deploy-code-review.md
git commit -m "docs: record local verification for deploy skill evolution"
```

---

## Self-Review

Spec coverage:

- K8s resource-name issue: covered by Task 3 and Task 2 validator.
- Phase 9 to Phase 10 closure: covered by Task 4 and Task 7.
- Multi-node Worker deploy confusion: covered by Task 5 and Task 7.
- `envsubst` dependency: covered by Task 6.
- Phase 8 stale file names: covered by Task 7.
- Local verification: covered by Tasks 1, 2, and 8.

No placeholders are intentional in this plan. Each implementation task identifies exact files, commands, and expected outcomes.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-03-vllm-deploy-skill-evolution.md`. Two execution options:

1. **Subagent-Driven (recommended)** - Dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
