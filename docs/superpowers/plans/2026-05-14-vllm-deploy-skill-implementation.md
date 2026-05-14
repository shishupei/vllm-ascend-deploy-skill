# vLLM-Deploy Skill 实现计划

> **面向 AI 代理的工作者：** 此计划设计为手动执行模式。每个任务完成后等待用户确认，再继续下一个任务。使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 创建两个 Skill（vllm-deploy-prepare 和 vllm-deploy-execute），实现从 vLLM-Ascend 文档自动提取部署脚本并生成 K8s YAML。

**架构：** 分拆为两个独立 Skill，准备阶段（任意环境）和执行阶段（K8s 管理节点），通过 config.json 衔接。

**技术栈：** Bash 脚本、K8s YAML 模板、Markdown 模块指南

**设计规格：** `docs/superpowers/specs/2026-05-14-vllm-deploy-skill-design.md`

---

## 文件结构总览

共 28 个文件，按以下顺序创建：

| 任务 | 文件 | 说明 |
|------|------|------|
| T1 | skill-prepare/skill.md, skill.yaml | Skill 1 入口和元数据 |
| T2 | skill-prepare/modules/*.md (6 个) | Skill 1 模块指南 |
| T3 | skill-prepare/scripts/*.sh (2 个) | Skill 1 辅助脚本 |
| T4 | skill-prepare/templates/* (6 个) | Skill 1 K8s 模板 |
| T5 | skill-execute/skill.md, skill.yaml | Skill 2 入口和元数据 |
| T6 | skill-execute/modules/*.md (7 个) | Skill 2 模块指南 |
| T7 | skill-execute/scripts/*.sh (3 个) | Skill 2 辅助脚本 |

---

## 任务 1：Skill 1 基础结构

**文件：**
- 创建：`skill-prepare/skill.md`
- 创建：`skill-prepare/skill.yaml`

**说明：** Skill 1 入口文件和元数据定义。

- [ ] **步骤 1：创建目录结构**

```bash
mkdir -p skill-prepare/modules skill-prepare/scripts skill-prepare/templates
```

- [ ] **步骤 2：创建 skill.yaml**

```yaml
name: vllm-deploy-prepare
description: vLLM-Ascend 部署准备 - 获取模型列表、解析文档、处理镜像、生成配置
version: 1.0.0
author: buchuibuhei
triggers:
  - /vllm-deploy-prepare
  - vllm 部署准备
dependencies:
  - curl/wget
  - docker (可选)
output_dir: .vllm-deploy/
```

- [ ] **步骤 3：创建 skill.md**

```markdown
# vLLM-Deploy Prepare Skill

vLLM-Ascend 部署准备阶段，在任意有网络的环境执行。

## 触发方式

- `/vllm-deploy-prepare`
- `vllm 部署准备`

## 执行流程

按顺序读取以下模块并执行：

1. **Phase 1**: `modules/model-list-fetcher.md` - 获取模型列表
2. **Phase 2**: `modules/user-selector.md` - 用户选择
3. **Phase 3**: `modules/doc-parser.md` - 文档解析
4. **Phase 5**: `modules/image-handler.md` - 镜像处理
5. **Phase 6**: `modules/config-guide.md` - 交互配置
6. **Phase 7**: `modules/template-generator.md` - 生成模板

## 输出

生成 `.vllm-deploy/` 目录，包含：
- `config.json` - 用户配置汇总
- `image-info.json` - 镜像信息
- `templates/` - K8s 模板文件

## 下一步

完成后运行 `/vllm-deploy-execute` 在 K8s 管理节点执行部署。
```

- [ ] **步骤 4：Commit**

```bash
git add skill-prepare/
git commit -m "feat(skill-prepare): add skill entry and metadata"
```

---

## 任务 2：Skill 1 模块文件

**文件：**
- 创建：`skill-prepare/modules/model-list-fetcher.md`
- 创建：`skill-prepare/modules/user-selector.md`
- 创建：`skill-prepare/modules/doc-parser.md`
- 创建：`skill-prepare/modules/image-handler.md`
- 创建：`skill-prepare/modules/config-guide.md`
- 创建：`skill-prepare/modules/template-generator.md`

- [ ] **步骤 1：创建 model-list-fetcher.md**

```markdown
# Phase 1: 快速获取模型列表

## 目标

从 vLLM-Ascend 文档抓取支持的模型列表。

## 默认 URL

```
https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html
```

## 执行方式

调用辅助脚本 `scripts/fetch-model-list.sh`。

## 输入

无（使用默认 URL）。

## 输出

JSON 格式的模型列表：

```json
{
  "models": [
    {"name": "GLM-5", "url": "GLM5.html"},
    {"name": "Qwen2.5-7B", "url": "Qwen2.5-7B.html"}
  ]
}
```

## 错误处理

| 场景 | 处理 |
|------|------|
| URL 无法访问 | 提示检查网络或文档站点状态 |
| 提取失败 | 建议用户手动指定模型教程 URL |

## AI 执行指南

1. 告知用户正在获取模型列表
2. 执行 `bash scripts/fetch-model-list.sh`
3. 解析脚本输出，展示模型列表
4. 进入 Phase 2
```

- [ ] **步骤 2：创建 user-selector.md**

```markdown
# Phase 2: 用户选择

## 目标

通过问答收集用户选择：模型、硬件规格、部署方式、镜像仓库。

## 输入

Phase 1 的模型列表。

## 问答流程

使用 AskUserQuestion 工具，逐个询问：

### Q1: 选择模型

展示模型列表，让用户选择一个模型。

### Q2: 硬件规格

选项：
- A3（16 卡）
- A2（8 卡）

### Q3: 部署方式

选项：
- 单节点：使用 1 个节点部署
- 多节点：使用多个节点分布式部署
- PD分离：Prefill 和 Decode 节点分离

### Q4: 目标镜像仓库

让用户输入镜像仓库地址（如 `harbor.example.com/library`）。

## 输出

```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library"
}
```

## AI 执行指南

1. 使用 AskUserQuestion 逐个询问
2. 记录用户选择到临时变量
3. 进入 Phase 3
```

- [ ] **步骤 3：创建 doc-parser.md**

```markdown
# Phase 3: 针对性文档解析

## 目标

只解析用户选择的模型文档，提取启动脚本和镜像版本。

## 输入

- Phase 2 用户选择结果
- 模型文档 URL（基于 model_url）

## 完整 URL 构建

```
https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/{model_url}
```

## 执行方式

调用辅助脚本 `scripts/parse-model-doc.sh`。

## 参数

传递给脚本：
- `--url`: 完整文档 URL
- `--hw-spec`: A3 或 A2
- `--deploy-mode`: single_node / multi_node / pd_separate

## 输出

```json
{
  "image_version": "v0.6.0",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "script_template": "vllm serve ...",
  "extracted_params": {
    "max_model_len": 8192,
    "tensor_parallel_size": 8
  }
}
```

## 错误处理

| 场景 | 处理 |
|------|------|
| 脚本块未找到 | 建议用户手动提供启动脚本 |
| 镜像版本未找到 | 提示用户手动指定镜像版本 |

## AI 执行指南

1. 构建完整文档 URL
2. 执行 `bash scripts/parse-model-doc.sh --url <URL> --hw-spec <SPEC> --deploy-mode <MODE>`
3. 解析脚本输出
4. 展示提取的脚本模板供用户确认
5. 进入 Phase 5
```

- [ ] **步骤 4：创建 image-handler.md**

```markdown
# Phase 5: 镜像处理

## 目标

拉取官方镜像，打标签，推送到用户指定的镜像仓库。

## 输入

- Phase 3 提取的源镜像（如 `quay.io/vllm-ascend/vllm-ascend:v0.6.0`）
- Phase 2 用户指定的目标镜像仓库

## 前置检查

检查 Docker 是否可用：

```bash
docker --version
```

## 处理流程

如果 Docker 可用：

1. 登录目标镜像仓库（如需）
2. 拉取源镜像
3. 打标签为目标镜像
4. 推送目标镜像

如果 Docker 不可用：
- 告知用户需要在有 Docker 的节点执行此步骤
- 或跳过此步骤，仅记录镜像信息到 image-info.json

## 输出

```json
{
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "push_success": true,
  "skipped": false
}
```

保存到 `.vllm-deploy/image-info.json`。

## 错误处理

| 场景 | 处理 |
|------|------|
| Docker 不可用 | 提示跳过或切换环境 |
| 登录失败 | 提示检查认证信息 |
| 推送失败 | 提示检查权限和网络 |

## AI 执行指南

1. 检查 Docker 可用性
2. 若可用，询问用户是否需要登录镜像仓库
3. 执行拉取、打标签、推送
4. 记录结果到 image-info.json
5. 进入 Phase 6
```

- [ ] **步骤 5：创建 config-guide.md**

```markdown
# Phase 6: 交互配置

## 目标

通过问答确认部署参数：Namespace、模型路径、性能参数。

## 输入

- Phase 2-5 的结果
- Phase 3 提取的默认参数

## 问答流程

使用 AskUserQuestion 工具：

### Q1: Namespace 名称

建议值：`vllm-{model-name}`（如 `vllm-glm5`）

让用户确认或修改。

### Q2: 模型路径

让用户输入模型在宿主机的路径（如 `/data/models/GLM-5`）。

### Q3: 性能参数确认

展示 Phase 3 提取的默认参数，让用户确认或修改：
- `max_model_len`
- `max_num_seqs`
- `tensor_parallel_size`（基于 NPU 数量建议）

### Q4: PD 分离配置（如适用）

如果 deploy_mode 为 `pd_separate`：
- Prefill 节点数量
- Decode 节点数量

## 输出

完整配置 JSON，合并 Phase 2-6 所有参数：

```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.example.com/library",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 8,
  "master_addr": "待填充",
  "master_port": 29500
}
```

## AI 执行指南

1. 使用 AskUserQuestion 逐个询问
2. 合并所有参数生成完整配置
3. 保存到 `.vllm-deploy/config.json`
4. 进入 Phase 7
```

- [ ] **步骤 6：创建 template-generator.md**

```markdown
# Phase 7: 生成模板文件

## 目标

复制模板文件到输出目录，保持占位符不变（Skill 2 将填充）。

## 输入

- config.json
- templates/ 目录下的模板文件

## 输出目录

```
.vllm-deploy/
├── config.json
├── image-info.json
└── templates/
    ├── k8s-namespace.yaml
    ├── k8s-configmap.yaml
    ├── k8s-deployment.yaml.template
    ├── k8s-service.yaml
    ├── deploy.sh.template
    └── apply-all.sh.template
```

## AI 执行指南

1. 创建 `.vllm-deploy/templates/` 目录
2. 复制 skill-prepare/templates/ 下所有文件到输出目录
3. 告知用户模板已生成
4. 提示用户运行 `/vllm-deploy-execute` 在 K8s 管理节点继续

## 完成提示

```
准备阶段完成！输出文件已生成到 .vllm-deploy/

下一步：
1. 将 .vllm-deploy/ 目录复制到 K8s 管理节点
2. 运行 /vllm-deploy-execute 继续部署
```
```

- [ ] **步骤 7：Commit**

```bash
git add skill-prepare/modules/
git commit -m "feat(skill-prepare): add 6 module guides for Phase 1-7"
```

---

## 任务 3：Skill 1 辅助脚本

**文件：**
- 创建：`skill-prepare/scripts/fetch-model-list.sh`
- 创建：`skill-prepare/scripts/parse-model-doc.sh`

- [ ] **步骤 1：创建 fetch-model-list.sh**

```bash
#!/bin/bash
# Phase 1: 获取 vLLM-Ascend 支持的模型列表

set -e

DEFAULT_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html"
URL="${1:-$DEFAULT_URL}"

echo "Fetching model list from: $URL"

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}'
    exit 1
fi

# 提取模型链接（假设链接格式为 tutorials/models/*.html）
# 使用 grep 和 sed 提取
MODELS=$(echo "$HTML" | grep -oP 'tutorials/models/[A-Za-z0-9_-]+\.html' | sort -u)

# 构建 JSON 输出
echo '{"models": ['

FIRST=true
while IFS= read -r url; do
    # 提取模型名称（去掉 .html 后缀）
    NAME=$(basename "$url" .html)
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ','
    fi
    
    echo "{\"name\": \"$NAME\", \"url\": \"$url\"}"
done <<< "$MODELS"

echo ']}'
```

- [ ] **步骤 2：创建 parse-model-doc.sh**

```bash
#!/bin/bash
# Phase 3: 解析模型文档，提取启动脚本和镜像版本

set -e

usage() {
    echo "Usage: $0 --url <URL> --hw-spec <A3|A2> --deploy-mode <single_node|multi_node|pd_separate>"
    exit 1
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --url) URL="$2"; shift 2 ;;
        --hw-spec) HW_SPEC="$2"; shift 2 ;;
        --deploy-mode) DEPLOY_MODE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$URL" ] || [ -z "$HW_SPEC" ] || [ -z "$DEPLOY_MODE" ]; then
    usage
fi

echo "Parsing: $URL"
echo "HW Spec: $HW_SPEC"
echo "Deploy Mode: $DEPLOY_MODE"

# 抓取页面 HTML
HTML=$(curl -sL "$URL" 2>/dev/null || wget -qO- "$URL" 2>/dev/null)

if [ -z "$HTML" ]; then
    echo '{"error": "Failed to fetch page"}'
    exit 1
fi

# 提取镜像版本（查找 vllm-ascend:v* 格式）
IMAGE_VERSION=$(echo "$HTML" | grep -oP 'vllm-ascend:v[0-9.]+' | head -1 | sed 's/vllm-ascend://')

if [ -z "$IMAGE_VERSION" ]; then
    IMAGE_VERSION="unknown"
fi

SOURCE_IMAGE="quay.io/vllm-ascend/vllm-ascend:$IMAGE_VERSION"

# 提取启动脚本块（查找 bash 代码块）
# 根据硬件规格和部署模式定位对应脚本
SCRIPT_BLOCK=$(echo "$HTML" | sed -n "/$HW_SPEC/,/```/p" | grep -A 50 "vllm serve" | head -20)

# 输出 JSON
cat <<EOF
{
  "image_version": "$IMAGE_VERSION",
  "source_image": "$SOURCE_IMAGE",
  "hw_spec": "$HW_SPEC",
  "deploy_mode": "$DEPLOY_MODE",
  "script_template": "$SCRIPT_BLOCK"
}
EOF
```

- [ ] **步骤 3：Commit**

```bash
git add skill-prepare/scripts/
git commit -m "feat(skill-prepare): add helper scripts for Phase 1 and 3"
```

---

## 任务 4：Skill 1 K8s 模板文件

**文件：**
- 创建：`skill-prepare/templates/k8s-namespace.yaml`
- 创建：`skill-prepare/templates/k8s-configmap.yaml`
- 创建：`skill-prepare/templates/k8s-deployment.yaml.template`
- 创建：`skill-prepare/templates/k8s-service.yaml`
- 创建：`skill-prepare/templates/deploy.sh.template`
- 创建：`skill-prepare/templates/apply-all.sh.template`

- [ ] **步骤 1：创建 k8s-namespace.yaml**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app: vllm-deploy
    model: ${MODEL_NAME}
```

- [ ] **步骤 2：创建 k8s-configmap.yaml**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vllm-config
  namespace: ${NAMESPACE}
data:
  MODEL_PATH: "${MODEL_PATH}"
  MAX_MODEL_LEN: "${MAX_MODEL_LEN}"
  MAX_NUM_SEQS: "${MAX_NUM_SEQS}"
  TENSOR_PARALLEL_SIZE: "${TENSOR_PARALLEL_SIZE}"
```

- [ ] **步骤 3：创建 k8s-deployment.yaml.template**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-deploy-${NODE_NAME}
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-deploy
      node: ${NODE_NAME}
  template:
    metadata:
      labels:
        app: vllm-deploy
        node: ${NODE_NAME}
    spec:
      nodeName: ${NODE_NAME}
      containers:
      - name: vllm
        image: ${IMAGE}
        command: ["sleep", "infinity"]
        resources:
          limits:
            ${NPU_RESOURCE_TYPE}: ${NPU_COUNT}
          requests:
            ${NPU_RESOURCE_TYPE}: ${NPU_COUNT}
        volumeMounts:
        - name: model-storage
          mountPath: ${MODEL_MOUNT_PATH}
        - name: dev-mount
          mountPath: /dev
        - name: sys-mount
          mountPath: /sys
      volumes:
      - name: model-storage
        hostPath:
          path: ${MODEL_PATH_HOST}
          type: Directory
      - name: dev-mount
        hostPath:
          path: /dev
      - name: sys-mount
        hostPath:
          path: /sys
```

- [ ] **步骤 4：创建 k8s-service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vllm-service
  namespace: ${NAMESPACE}
spec:
  type: NodePort
  selector:
    app: vllm-deploy
  ports:
  - port: 8000
    targetPort: 8000
    nodePort: ${SERVICE_PORT}
```

- [ ] **步骤 5：创建 deploy.sh.template**

```bash
#!/bin/bash
# Pod 内 vllm serve 启动脚本

set -e

MODEL_PATH="${MODEL_PATH}"
MAX_MODEL_LEN="${MAX_MODEL_LEN}"
MAX_NUM_SEQS="${MAX_NUM_SEQS}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE}"
MASTER_ADDR="${MASTER_ADDR}"
MASTER_PORT="${MASTER_PORT}"
RANK="${RANK}"
WORLD_SIZE="${WORLD_SIZE}"

echo "Starting vLLM serve..."
echo "Model: $MODEL_PATH"
echo "Tensor Parallel Size: $TENSOR_PARALLEL_SIZE"
echo "Rank: $RANK / World Size: $WORLD_SIZE"

vllm serve "$MODEL_PATH" \
    --max-model-len "$MAX_MODEL_LEN" \
    --max-num-seqs "$MAX_NUM_SEQS" \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --distributed-executor-backend ray \
    --master-addr "$MASTER_ADDR" \
    --master-port "$MASTER_PORT"
```

- [ ] **步骤 6：创建 apply-all.sh.template**

```bash
#!/bin/bash
# 一键 apply 所有 K8s YAML 文件

set -e

NAMESPACE="${NAMESPACE}"

echo "Applying K8s resources to namespace: $NAMESPACE"

kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml

# Apply all deployment files
for deploy in deployment-*.yaml; do
    kubectl apply -f "$deploy"
done

kubectl apply -f service.yaml

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods -l app=vllm-deploy -n "$NAMESPACE" --timeout=300s

echo "All pods are ready!"
echo "Service NodePort:"
kubectl get svc vllm-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}'
```

- [ ] **步骤 7：Commit**

```bash
git add skill-prepare/templates/
git commit -m "feat(skill-prepare): add 6 K8s templates with placeholders"
```

---

## 任务 5：Skill 2 基础结构

**文件：**
- 创建：`skill-execute/skill.md`
- 创建：`skill-execute/skill.yaml`

- [ ] **步骤 1：创建目录结构**

```bash
mkdir -p skill-execute/modules skill-execute/scripts
```

- [ ] **步骤 2：创建 skill.yaml**

```yaml
name: vllm-deploy-execute
description: vLLM-Ascend 部署执行 - K8s 环境探测、生成 YAML、执行部署
version: 1.0.0
author: buchuibuhei
triggers:
  - /vllm-deploy-execute
  - vllm 部署执行
dependencies:
  - kubectl
  - .vllm-deploy/ 目录存在
prerequisite_skill: vllm-deploy-prepare
output_dir: .vllm-deploy/k8s/
```

- [ ] **步骤 3：创建 skill.md**

```markdown
# vLLM-Deploy Execute Skill

vLLM-Ascend 部署执行阶段，在 K8s 管理节点执行。

## 前置条件

- 已运行 `/vllm-deploy-prepare`
- `.vllm-deploy/config.json` 存在
- kubectl 可用且有集群管理权限

## 触发方式

- `/vllm-deploy-execute`
- `vllm 部署执行`

## 执行流程

按顺序读取以下模块并执行：

1. **Phase 4**: `modules/k8s-env-detector.md` - K8s 环境探测
2. **Phase 7补**: `modules/yaml-generator.md` - 填充模板生成 YAML
3. **Phase 8**: `modules/k8s-apply-guide.md` - 用户执行 apply
4. **Phase 9**: `modules/container-env-detector.md` - 容器内探测
5. **Phase 10**: `modules/deploy-generator.md` - 生成部署脚本
6. **Phase 11**: `modules/deploy-execution-guide.md` - 用户执行部署
7. **Phase 12**: `modules/output-guide.md` - 输出交付

## 用户确认点

| 阶段 | 用户操作 |
|------|---------|
| Phase 4 后 | 确认节点选择 |
| Phase 8 | 手动执行 `bash apply-all.sh` |
| Phase 11 | 手动执行 `kubectl exec ... deploy.sh` |

## 输出

最终交付文件在 `.vllm-deploy/k8s/`。
```

- [ ] **步骤 4：Commit**

```bash
git add skill-execute/
git commit -m "feat(skill-execute): add skill entry and metadata"
```

---

## 任务 6：Skill 2 模块文件

**文件：**
- 创建：`skill-execute/modules/k8s-env-detector.md`
- 创建：`skill-execute/modules/yaml-generator.md`
- 创建：`skill-execute/modules/k8s-apply-guide.md`
- 创建：`skill-execute/modules/container-env-detector.md`
- 创建：`skill-execute/modules/deploy-generator.md`
- 创建：`skill-execute/modules/deploy-execution-guide.md`
- 创建：`skill-execute/modules/output-guide.md`

- [ ] **步骤 1：创建 k8s-env-detector.md**

```markdown
# Phase 4: K8s 环境探测

## 目标

探测 K8s 集群节点、NPU 数量、硬件规格。

## 前置检查

1. 检查 kubectl 可用：`kubectl version`
2. 检查集群连接：`kubectl cluster-info`

## 执行方式

调用辅助脚本 `scripts/detect-k8s-env.sh`。

## 输出

```json
{
  "kubectl_available": true,
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-1",
      "ip": "192.168.1.100",
      "npu_count": 16,
      "hw_spec": "A3"
    }
  ],
  "recommended_nodes": ["node-1"]
}
```

保存到 `.vllm-deploy/detection-result.json`。

## 用户确认

展示探测结果，让用户确认：
- 节点选择是否正确
- 是否使用推荐节点

## 错误处理

| 场景 | 处理 |
|------|------|
| kubectl 不可用 | 提示安装并配置 kubeconfig |
| 集群连接失败 | 提示检查 kubeconfig |
| NPU 资源未注册 | 提示检查 Ascend Device Plugin |

## AI 执行指南

1. 执行 `bash scripts/detect-k8s-env.sh`
2. 解析输出，展示节点列表
3. 使用 AskUserQuestion 让用户确认节点选择
4. 进入 Phase 7补
```

- [ ] **步骤 2：创建 yaml-generator.md**

```markdown
# Phase 7补: 填充模板生成 YAML

## 目标

读取模板 + 探测结果，填充占位符生成最终 YAML。

## 输入

- `.vllm-deploy/config.json`
- `.vllm-deploy/detection-result.json`
- `.vllm-deploy/templates/` 下的模板文件

## 执行方式

调用辅助脚本 `scripts/fill-template.sh`。

## 参数传递

- `--config`: config.json 路径
- `--detection`: detection-result.json 路径
- `--templates`: templates 目录路径
- `--output`: k8s 输出目录路径

## 输出

生成 `.vllm-deploy/k8s/` 目录：

```
k8s/
├── namespace.yaml
├── configmap.yaml
├── deployment-node1.yaml
├── deployment-node2.yaml (多节点时)
├── service.yaml
└── apply-all.sh
```

## AI 执行指南

1. 创建 `.vllm-deploy/k8s/` 目录
2. 执行 `bash scripts/fill-template.sh --config ... --detection ... --templates ... --output ...`
3. 展示生成的 YAML 文件列表
4. 进入 Phase 8
```

- [ ] **步骤 3：创建 k8s-apply-guide.md**

```markdown
# Phase 8: 用户执行 K8s Apply

## 目标

指导用户手动执行 apply-all.sh。

## 用户操作

```bash
cd .vllm-deploy/k8s
bash apply-all.sh
```

## AI 行为

**不自动执行**，只提供指引。

告知用户：
1. YAML 文件已生成
2. 执行命令
3. 等待 Pod 启动

## 等待确认

AI 等待用户回复：
- "Pod 已启动成功" → 进入 Phase 9
- "启动失败" → 进入错误处理流程

## 错误处理

| 场景 | 处理 |
|------|------|
| Pod 启动失败 | 检查 kubectl describe pod 输出 |
| 镜像拉取失败 | 检查镜像仓库配置 |
| NPU 资源不足 | 检查节点 NPU 资源 |

## AI 执行指南

1. 告知用户执行 `bash apply-all.sh`
2. 等待用户确认 Pod 状态
3. 用户确认成功后进入 Phase 9
```

- [ ] **步骤 4：创建 container-env-detector.md**

```markdown
# Phase 9: 容器内环境探测

## 目标

进入 Pod 探测 NPU 设备映射情况。

## 前置条件

Pod 已启动成功。

## 获取 Pod 名称

```bash
kubectl get pods -n ${NAMESPACE} -l app=vllm-deploy
```

## 执行方式

调用辅助脚本 `scripts/detect-container-npu.sh`。

## 输出

```json
{
  "pod_name": "vllm-deploy-node1-xxx",
  "container_npu_count": 8,
  "devices_mapped": ["davinci0", "davinci1", ...]
}
```

## 确认 NPU 数量

展示容器内 NPU 数量，让用户确认是否正确。

## 错误处理

| 场景 | 处理 |
|------|------|
| NPU 设备未映射 | 检查 Device Plugin 配置 |
| 数量不匹配 | 检查 Deployment 资源配置 |

## AI 执行指南

1. 获取 Pod 名称
2. 执行 `bash scripts/detect-container-npu.sh --pod <POD_NAME> --namespace <NAMESPACE>`
3. 展示 NPU 数量
4. 进入 Phase 10
```

- [ ] **步骤 5：创建 deploy-generator.md**

```markdown
# Phase 10: 生成部署脚本

## 目标

根据容器内 NPU 数量生成 deploy.sh。

## 输入

- Phase 9 容器内 NPU 数量
- config.json 参数

## 参数计算

根据 deploy_mode 计算分布式参数：

### 单节点

```bash
RANK=0
WORLD_SIZE=1
MASTER_ADDR=localhost
```

### 多节点

第一个节点（Master）：
```bash
RANK=0
MASTER_ADDR=<本节点 IP>
```

其他节点：
```bash
RANK=<节点序号>
MASTER_ADDR=<第一个节点 IP>
```

## 输出

生成 `.vllm-deploy/k8s/deploy.sh`。

## AI 执行指南

1. 读取 config.json 和 Phase 9 结果
2. 计算分布式参数
3. 填充 deploy.sh.template
4. 展示 deploy.sh 内容供用户确认
5. 进入 Phase 11
```

- [ ] **步骤 6：创建 deploy-execution-guide.md**

```markdown
# Phase 11: 用户执行部署脚本

## 目标

指导用户在 Pod 内执行 deploy.sh。

## 用户操作

```bash
# 将 deploy.sh 复制到 Pod
kubectl cp .vllm-deploy/k8s/deploy.sh -n ${NAMESPACE} <POD_NAME>:/

# 在 Pod 内执行
kubectl exec -n ${NAMESPACE} <POD_NAME> -- bash deploy.sh
```

## AI 行为

**不自动执行**，只提供指引。

告知用户：
1. 复制脚本到 Pod 的命令
2. 执行脚本的命令
3. 等待 vLLM 启动完成

## 等待确认

AI 等待用户回复：
- "部署成功" → 进入 Phase 12
- "启动失败" → 进入错误处理

## 错误处理

| 场景 | 处理 |
|------|------|
| vLLM 启动失败 | 检查 vLLM 日志 |
| 模型加载失败 | 检查模型路径 |
| 分布式通信失败 | 检查网络和 MASTER_ADDR |

## AI 执行指南

1. 告知用户执行命令
2. 等待用户确认部署状态
3. 用户确认成功后进入 Phase 12
```

- [ ] **步骤 7：创建 output-guide.md**

```markdown
# Phase 12: 输出交付

## 目标

汇总最终输出，生成 README.md 执行指南。

## 输入

所有生成的文件和部署结果。

## 输出目录

```
.vllm-deploy/
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment-node*.yaml
│   ├── service.yaml
│   ├── apply-all.sh
│   ├── deploy.sh
│   └── README.md
├── config.json
├── detection-result.json
├── image-info.json
└── final-output.json
```

## README.md 内容

```markdown
# vLLM 部署执行指南

## 访问信息

- Service NodePort: ${SERVICE_PORT}
- Namespace: ${NAMESPACE}

## 已执行步骤

1. K8s YAML 已 apply
2. Pod 已启动
3. vLLM serve 已运行

## 测试服务

curl http://<NODE_IP>:${SERVICE_PORT}/v1/models
```

## final-output.json

```json
{
  "namespace": "vllm-glm5",
  "service_port": 30080,
  "nodes": ["node-1", "node-2"],
  "model": "GLM-5",
  "deploy_time": "2026-05-14T10:00:00Z"
}
```

## AI 执行指南

1. 生成 k8s/README.md
2. 生成 final-output.json
3. 展示最终访问信息
4. 告知用户部署完成
```

- [ ] **步骤 8：Commit**

```bash
git add skill-execute/modules/
git commit -m "feat(skill-execute): add 7 module guides for Phase 4-12"
```

---

## 任务 7：Skill 2 辅助脚本

**文件：**
- 创建：`skill-execute/scripts/detect-k8s-env.sh`
- 创建：`skill-execute/scripts/detect-container-npu.sh`
- 创建：`skill-execute/scripts/fill-template.sh`

- [ ] **步骤 1：创建 detect-k8s-env.sh**

```bash
#!/bin/bash
# Phase 4: 探测 K8s 环境和节点 NPU 信息

set -e

echo "Checking kubectl availability..."
if ! command -v kubectl &> /dev/null; then
    echo '{"kubectl_available": false, "cluster_connected": false}'
    exit 1
fi

echo '{"kubectl_available": true'

# 检查集群连接
if ! kubectl cluster-info &> /dev/null; then
    echo ', "cluster_connected": false}'
    exit 1
fi

echo ', "cluster_connected": true'

# 获取节点列表
echo ', "nodes": ['

NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
FIRST=true

for NODE in $NODES; do
    # 获取节点 IP
    IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    
    # 获取 NPU 数量（通过 davinci 资源）
    NPU_COUNT=$(kubectl describe node "$NODE" | grep -A 5 "Capacity:" | grep "davinci" | awk '{print $2}' || echo "0")
    
    # 判断硬件规格
    if [ "$NPU_COUNT" -ge 16 ]; then
        HW_SPEC="A3"
    elif [ "$NPU_COUNT" -ge 8 ]; then
        HW_SPEC="A2"
    else
        HW_SPEC="Unknown"
    fi
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ','
    fi
    
    echo "{\"name\": \"$NODE\", \"ip\": \"$IP\", \"npu_count\": $NPU_COUNT, \"hw_spec\": \"$HW_SPEC\"}"
done

echo ']'

# 推荐节点（NPU 数量最多的）
RECOMMENDED=$(kubectl get nodes -o json | jq -r '[.items[] | select(.status.capacity.davinci != null) | {name: .metadata.name, count: (.status.capacity.davinci | tonumber)}] | sort_by(-.count) | .[0:2] | .[].name' 2>/dev/null || echo "")

echo ', "recommended_nodes": ['

FIRST=true
for NODE in $RECOMMENDED; do
    if [ -n "$NODE" ]; then
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ','
        fi
        echo "\"$NODE\""
    fi
done

echo ']}'
```

- [ ] **步骤 2：创建 detect-container-npu.sh**

```bash
#!/bin/bash
# Phase 9: 在 Pod 内探测 NPU 设备

set -e

usage() {
    echo "Usage: $0 --pod <POD_NAME> --namespace <NAMESPACE>"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --pod) POD="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$POD" ] || [ -z "$NAMESPACE" ]; then
    usage
fi

echo "Detecting NPU in pod: $POD (namespace: $NAMESPACE)"

# 在 Pod 内执行 npu-smi
NPU_INFO=$(kubectl exec -n "$NAMESPACE" "$POD" -- npu-smi info 2>/dev/null || echo "npu-smi not available")

# 统计 NPU 设备数量
NPU_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD" -- ls /dev | grep -c "davinci" 2>/dev/null || echo "0")

# 列出设备
DEVICES=$(kubectl exec -n "$NAMESPACE" "$POD" -- ls /dev | grep "davinci" | tr '\n' ',' | sed 's/,$//')

cat <<EOF
{
  "pod_name": "$POD",
  "namespace": "$NAMESPACE",
  "container_npu_count": $NPU_COUNT,
  "devices_mapped": [$DEVICES]
}
EOF
```

- [ ] **步骤 3：创建 fill-template.sh**

```bash
#!/bin/bash
# Phase 7补: 填充模板生成最终 YAML

set -e

usage() {
    echo "Usage: $0 --config <config.json> --detection <detection.json> --templates <dir> --output <dir>"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --config) CONFIG="$2"; shift 2 ;;
        --detection) DETECTION="$2"; shift 2 ;;
        --templates) TEMPLATES="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$CONFIG" ] || [ -z "$DETECTION" ] || [ -z "$TEMPLATES" ] || [ -z "$OUTPUT" ]; then
    usage
fi

mkdir -p "$OUTPUT"

# 读取配置参数（假设使用 jq）
NAMESPACE=$(jq -r '.namespace' "$CONFIG")
MODEL_PATH=$(jq -r '.model_path' "$CONFIG")
MAX_MODEL_LEN=$(jq -r '.max_model_len' "$CONFIG")
MAX_NUM_SEQS=$(jq -r '.max_num_seqs' "$CONFIG")
TENSOR_PARALLEL_SIZE=$(jq -r '.tensor_parallel_size' "$CONFIG")
IMAGE=$(jq -r '.target_image' "$CONFIG")
MODEL_NAME=$(jq -r '.selected_model' "$CONFIG")

# 读取探测结果
NODES=$(jq -r '.nodes[].name' "$DETECTION")
NPU_RESOURCE_TYPE="davinci"  # 或 huawei.com/Ascend910

# 填充 namespace.yaml
sed -e "s/\${NAMESPACE}/$NAMESPACE/g" \
    -e "s/\${MODEL_NAME}/$MODEL_NAME/g" \
    "$TEMPLATES/k8s-namespace.yaml" > "$OUTPUT/namespace.yaml"

# 填充 configmap.yaml
sed -e "s/\${NAMESPACE}/$NAMESPACE/g" \
    -e "s/\${MODEL_PATH}/$MODEL_PATH/g" \
    -e "s/\${MAX_MODEL_LEN}/$MAX_MODEL_LEN/g" \
    -e "s/\${MAX_NUM_SEQS}/$MAX_NUM_SEQS/g" \
    -e "s/\${TENSOR_PARALLEL_SIZE}/$TENSOR_PARALLEL_SIZE/g" \
    "$TEMPLATES/k8s-configmap.yaml" > "$OUTPUT/configmap.yaml"

# 为每个节点填充 deployment
NODE_INDEX=0
for NODE in $NODES; do
    NPU_COUNT=$(jq -r ".nodes[] | select(.name == \"$NODE\") | .npu_count" "$DETECTION")
    
    sed -e "s/\${NODE_NAME}/$NODE/g" \
        -e "s/\${NAMESPACE}/$NAMESPACE/g" \
        -e "s/\${IMAGE}/$IMAGE/g" \
        -e "s/\${NPU_RESOURCE_TYPE}/$NPU_RESOURCE_TYPE/g" \
        -e "s/\${NPU_COUNT}/$NPU_COUNT/g" \
        -e "s/\${MODEL_MOUNT_PATH}/\/data/g" \
        -e "s/\${MODEL_PATH_HOST}/$MODEL_PATH/g" \
        "$TEMPLATES/k8s-deployment.yaml.template" > "$OUTPUT/deployment-$NODE.yaml"
    
    NODE_INDEX=$((NODE_INDEX + 1))
done

# 填充 service.yaml
SERVICE_PORT=$((30000 + RANDOM % 1000))
sed -e "s/\${NAMESPACE}/$NAMESPACE/g" \
    -e "s/\${SERVICE_PORT}/$SERVICE_PORT/g" \
    "$TEMPLATES/k8s-service.yaml" > "$OUTPUT/service.yaml"

# 填充 apply-all.sh
sed -e "s/\${NAMESPACE}/$NAMESPACE/g" \
    "$TEMPLATES/apply-all.sh.template" > "$OUTPUT/apply-all.sh"

chmod +x "$OUTPUT/apply-all.sh"

echo "Generated files in $OUTPUT:"
ls -la "$OUTPUT"
```

- [ ] **步骤 4：Commit**

```bash
git add skill-execute/scripts/
git commit -m "feat(skill-execute): add helper scripts for Phase 4, 7, 9"
```

---

## 任务 8：最终验证和总结

- [ ] **步骤 1：验证文件完整性**

```bash
find skill-prepare skill-execute -type f | wc -l
# 预期：28 个文件
```

- [ ] **步骤 2：检查脚本可执行性**

```bash
chmod +x skill-prepare/scripts/*.sh skill-execute/scripts/*.sh
ls -la skill-prepare/scripts/ skill-execute/scripts/
```

- [ ] **步骤 3：更新 README.md**

添加 Skill 使用说明到项目 README.md。

- [ ] **步骤 4：最终 Commit**

```bash
git add -A
git commit -m "feat: complete vLLM-Deploy Skill with prepare and execute phases"
```

---

## 执行说明

此计划设计为 **手动执行模式**：

1. 每完成一个任务（T1-T7），等待用户确认后再继续
2. 用户可以检查生成的文件，提出修改建议
3. 任务 8 为最终验证，确保所有文件完整

**开始执行时，请告知我执行任务 1。**