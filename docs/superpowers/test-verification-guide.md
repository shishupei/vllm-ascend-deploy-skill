# Skill 1 真实使用验证指南

**验证目标**: 模拟真实用户场景，完整执行 Skill 1 流程，验证输出结果。

**前置条件**: 有网络连接的环境（可以访问 vLLM-Ascend 文档站点）。

---

## 验证场景

使用虚拟模型和配置进行端到端测试，验证 Skill 能正确生成输出文件。

---

## 步骤 1：触发 Skill

在 Claude Code 或支持 Skill 的环境中：

```
/vllm-deploy-prepare
```

或输入触发词：

```
vllm 部署准备
```

**验证点**: AI 应开始读取 Skill 1 的 skill.md，并按照 Phase 流程执行。

---

## 步骤 2：Phase 1 - 获取模型列表

AI 执行 `modules/model-list-fetcher.md` 模块。

**预期行为**:
1. AI 告知正在获取模型列表
2. AI 调用 `scripts/fetch-model-list.sh`
3. 展示模型列表供用户选择

**测试数据**: 如果网络不可访问，可手动提供测试数据：

```json
{
  "models": [
    {"name": "GLM-5", "url": "GLM5.html"},
    {"name": "Qwen2.5-7B", "url": "Qwen2.5-7B.html"},
    {"name": "DeepSeek-V3", "url": "DeepSeek-V3.html"}
  ]
}
```

**验证点**: 模型列表 JSON 格式正确，包含 name 和 url 字段。

---

## 步骤 3：Phase 2 - 用户选择

AI 读取 `modules/user-selector.md`，逐个询问用户。

**测试回答**:

| 问题 | 测试回答 |
|------|---------|
| Q1: 选择模型 | `GLM-5` |
| Q2: 硬件规格 | `A3`（16卡） |
| Q3: 部署方式 | `多节点` |
| Q4: 目标镜像仓库 | `harbor.test.local/library` |

**验证点**: AI 应记录选择结果，输出 JSON：
```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.test.local/library"
}
```

---

## 步骤 4：Phase 3 - 文档解析

AI 读取 `modules/doc-parser.md`，调用脚本解析模型文档。

**预期行为**:
1. AI 构建完整 URL：`https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/GLM5.html`
2. 调用 `scripts/parse-model-doc.sh --url ... --hw-spec A3 --deploy-mode multi_node`
3. 展示提取的脚本模板供确认

**如果文档不可访问，手动提供测试数据**:

```json
{
  "image_version": "v0.6.0",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "script_template": "vllm serve /data/models/GLM-5 --max-model-len 8192 --tensor-parallel-size 8",
  "extracted_params": {
    "max_model_len": 8192,
    "tensor_parallel_size": 8
  }
}
```

**验证点**: 输出包含 `extracted_params` 字段。

---

## 步骤 5：Phase 5 - 镜像处理

AI 读取 `modules/image-handler.md`。

**测试场景 A - Docker 可用**:

如果环境有 Docker，AI 应：
1. 检查 Docker 可用性
2. 询问是否需要登录镜像仓库
3. 执行拉取、打标签、推送（可选择跳过）

**测试回答**: 选择跳过镜像推送（测试环境可能无权限）

**测试场景 B - Docker 不可用**:

AI 应告知用户：
- "Docker 不可用，将在 image-info.json 中记录镜像信息，请后续在有 Docker 的环境执行镜像处理"

**验证点**: 生成 `.vllm-deploy/image-info.json` 文件，内容包含：
```json
{
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.test.local/library/vllm-ascend:v0.6.0",
  "skipped": true
}
```

---

## 步骤 6：Phase 6 - 交互配置

AI 读取 `modules/config-guide.md`，逐个询问配置参数。

**测试回答**:

| 问题 | 测试回答 |
|------|---------|
| Q1: Namespace | `vllm-glm5`（接受建议值） |
| Q2: 模型路径 | `/data/models/GLM-5` |
| Q3: max_model_len | `8192`（接受默认值） |
| Q3: max_num_seqs | `256`（接受默认值） |
| Q3: tensor_parallel_size | `8`（接受建议值） |

**验证点**: AI 合并所有参数，生成 `.vllm-deploy/config.json`：

```json
{
  "selected_model": "GLM-5",
  "model_url": "GLM5.html",
  "hw_spec": "A3",
  "deploy_mode": "multi_node",
  "image_registry": "harbor.test.local/library",
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.test.local/library/vllm-ascend:v0.6.0",
  "namespace": "vllm-glm5",
  "model_path": "/data/models/GLM-5",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "tensor_parallel_size": 8,
  "master_addr": "待填充",
  "master_port": 29500
}
```

---

## 步骤 7：Phase 7 - 生成模板文件

AI 读取 `modules/template-generator.md`。

**预期行为**:
1. 创建 `.vllm-deploy/templates/` 目录
2. 复制模板文件到输出目录
3. 告知用户准备阶段完成

**验证点**: `.vllm-deploy/templates/` 目录包含 6 个文件：

```
.vllm-deploy/templates/
├── k8s-namespace.yaml
├── k8s-configmap.yaml
├── k8s-deployment.yaml.template
├── k8s-service.yaml
├── deploy.sh.template
└── apply-all.sh.template
```

---

## 步骤 8：最终输出验证

检查 `.vllm-deploy/` 目录：

```bash
ls -la .vllm-deploy/
ls -la .vllm-deploy/templates/
```

**预期输出结构**:

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

---

## 步骤 9：内容验证

### 9.1 验证 config.json

```bash
cat .vllm-deploy/config.json
```

**验证点**:
- JSON 格式正确
- 所有测试回答的参数都已记录
- `master_addr` 字段值为 `"待填充"`

### 9.2 验证 image-info.json

```bash
cat .vllm-deploy/image-info.json
```

**验证点**:
- 包含 `source_image` 和 `target_image`
- `skipped` 字段反映实际操作结果

### 9.3 验证模板文件占位符

```bash
cat .vllm-deploy/templates/k8s-namespace.yaml
```

**验证点**: 包含 `${NAMESPACE}` 和 `${MODEL_NAME}` 占位符

---

## 步骤 10：Skill 完成提示验证

AI 应输出类似提示：

```
准备阶段完成！输出文件已生成到 .vllm-deploy/

下一步：
1. 将 .vllm-deploy/ 目录复制到 K8s 管理节点
2. 运行 /vllm-deploy-execute 继续部署
```

---

## 验证清单

| Phase | 验证项 | 预期结果 |
|-------|--------|----------|
| 1 | 模型列表 JSON | `{models: [{name, url}]}` |
| 2 | 用户选择记录 | `selected_model, hw_spec, deploy_mode, image_registry` |
| 3 | 文档解析输出 | `extracted_params` 字段存在 |
| 5 | image-info.json | 文件存在，内容正确 |
| 6 | config.json | 文件存在，参数完整 |
| 7 | templates/ 目录 | 6 个模板文件存在 |
| 完成 | 提示信息 | 告知下一步操作 |

---

## 异常场景测试

### 网络不可访问

手动提供测试数据替代脚本输出：

```
请使用以下测试数据继续：
{
  "models": [{"name": "GLM-5", "url": "GLM5.html"}]
}
```

**验证点**: AI 能正确处理手动数据，继续后续 Phase。

### Docker 不可用

选择跳过镜像处理。

**验证点**: `image-info.json` 中 `skipped: true`。

### 部署方式为 PD分离

测试回答改为 `PD分离`，后续问答应增加：
- Prefill 节点数量
- Decode 节点数量

---

**验证完成后，请汇报验证结果和发现的问题。**