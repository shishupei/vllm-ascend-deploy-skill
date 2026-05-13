# vLLM-Deploy Skill 设计规格

## 概述

vLLM-Deploy Skill 是一个自动化部署工具，帮助 DevOps 工程师在 K8s 环境部署 vLLM 模型到 Ascend NPU。技能从 vLLM-Ascend 文档自动提取部署脚本，根据 K8s 环境自动修改参数，生成一键执行的 K8s YAML。

**执行环境：** K8s 管理节点（需有 kubectl 和集群管理权限）

**目标用户：** DevOps 工程师

**交互方式：** 混合式 - 对话收集配置，生成文件后用户手动执行脚本

---

## 文件结构

```
vllm-skill/
├── skill.md                    # Skill 入口
├── skill.yaml                  # Skill 元数据
├── modules/
│   ├── model-list-fetcher.md        # Phase 1: 抓取模型列表
│   ├── user-selector.md             # Phase 2: 用户选择
│   ├── doc-parser.md                # Phase 3: 针对性文档解析
│   ├── k8s-env-detector.md          # Phase 4: K8s 环境探测
│   ├── image-handler.md             # Phase 5: 镜像处理
│   ├── config-guide.md              # Phase 6: 交互配置
│   ├── k8s-yaml-generator.md        # Phase 7: 生成 K8s YAML
│   ├── container-env-detector.md    # Phase 9: 容器内环境探测
│   ├── deploy-generator.md          # Phase 10: 生成部署脚本
│   └── output-guide.md              # Phase 12: 输出交付
├── scripts/
│   ├── fetch-model-list.sh          # 抓取模型列表脚本
│   ├── parse-model-doc.sh           # 解析模型文档脚本
│   ├── detect-k8s-env.sh            # K8s 环境探测脚本
│   ├── detect-container-npu.sh      # 容器内 NPU 探测脚本
│   └── push-image.sh                # 镜像处理脚本
└── templates/
    ├── k8s-namespace.yaml            # Namespace 模板
    ├── k8s-configmap.yaml            # ConfigMap 模板
    ├── k8s-deployment.yaml           # Deployment 模板
    ├── k8s-service.yaml              # Service 模板
    ├── deploy.sh                     # vllm serve 部署脚本模板
    └── apply-all.sh                  # K8s 一键 apply 脚本模板
```

---

## Skill 入口设计

### skill.yaml

```yaml
name: vllm-deploy
description: Use when deploying vLLM models on K8s with Ascend NPU. Automates model selection, doc parsing, K8s env detection, image handling, and generates deployment YAML files.
```

### skill.md

- 触发流程启动，进入 Phase 1
- 调用 `modules/model-list-fetcher.md` 获取模型列表
- 只做流程引导，不包含具体实现细节

---

## 模块设计

每个模块包含：概述、输入参数、处理步骤、输出结果、调用的脚本（如有）、错误处理

### 模块职责划分

| 模块 | 职责 | 是否调用脚本 |
|------|------|-------------|
| model-list-fetcher.md | Phase 1: 抓取文档站点，提取模型列表 | ✅ fetch-model-list.sh |
| user-selector.md | Phase 2: AskUserQuestion 让用户选择模型/规格/部署方式/镜像仓库 | ❌ 纯对话 |
| doc-parser.md | Phase 3: 抓取选定模型页面，解析脚本和镜像版本 | ✅ parse-model-doc.sh |
| k8s-env-detector.md | Phase 4: kubectl 探测节点、IP、NPU 数量 | ✅ detect-k8s-env.sh |
| image-handler.md | Phase 5: SSH 远程执行 docker 操作，用户交互输入账密 | ✅ push-image.sh |
| config-guide.md | Phase 6: AskUserQuestion 收集配置参数 | ❌ 纯对话 |
| k8s-yaml-generator.md | Phase 7: 根据模板生成 YAML 文件 | ❌ 纯文本生成 |
| container-env-detector.md | Phase 9: kubectl exec 探测 Pod 内 NPU | ✅ detect-container-npu.sh |
| deploy-generator.md | Phase 10: 根据探测结果生成 vllm serve 脚本 | ❌ 纯文本生成 |
| output-guide.md | Phase 12: 整理输出目录，生成 README | ❌ 纯文件操作 |

---

## 脚本设计

每个脚本包含：脚本头部、参数说明、输出格式（JSON）、错误处理（非零退出码）

### 脚本职责

| 脚本 | 输入 | 输出 | 执行位置 |
|------|------|------|---------|
| fetch-model-list.sh | 默认 URL（可覆盖） | JSON：模型名和链接数组 | 本地 curl |
| parse-model-doc.sh | 模型 URL + 规格 + 部署方式 | 提取的脚本内容 + 镜像版本 | 本地 curl + 解析 |
| detect-k8s-env.sh | 无 | JSON：节点信息、NPU 数量、推荐节点 | K8s 管理节点 kubectl |
| detect-container-npu.sh | Pod 名称 + Namespace | JSON：容器内 NPU 设备列表 | Pod 内 kubectl exec |
| push-image.sh | 源镜像 + 目标仓库 + 远程节点 IP + 账密 | JSON：推送成功/失败状态 | SSH 远程执行 docker |

---

## 模板设计

使用 `${VAR_NAME}` 作为替换占位符

### 模板内容

| 模板 | 主要占位符 | 用途 |
|------|-----------|------|
| k8s-namespace.yaml | `${NAMESPACE}`、`${MODEL_NAME}` | 创建隔离空间 |
| k8s-configmap.yaml | `${NAMESPACE}`、`${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}` | 存储配置参数 |
| k8s-deployment.yaml | `${NODE_NAME}`、`${NAMESPACE}`、`${IMAGE}`、`${NPU_RESOURCE_TYPE}`、`${NPU_COUNT}`、`${MODEL_MOUNT_PATH}`、`${MODEL_PATH_HOST}` | Pod 运行配置 |
| k8s-service.yaml | `${NAMESPACE}`、`${SERVICE_PORT}` | NodePort 暴露服务 |
| deploy.sh | `${MODEL_PATH}`、`${MAX_MODEL_LEN}`、`${MAX_NUM_SEQS}`、`${TENSOR_PARALLEL_SIZE}`、`${MASTER_ADDR}`、`${MASTER_PORT}`、`${RANK}` | Pod 内 vllm serve 命令 |
| apply-all.sh | `${NAMESPACE}` | 按顺序 apply 所有 YAML |

---

## 流程设计

### 12 阶段流程

每个 phase 都需要用户手动确认才能继续下一步。

| 阶段 | 输出传递给 | 用户交互 |
|------|-----------|---------|
| Phase 1 | 模型列表 JSON | **展示结果，等待用户确认继续** |
| Phase 1 → 2 | 模型列表 JSON | AskUserQuestion 选择模型/规格/部署方式 |
| Phase 2 → 3 | 选择结果 | **展示选择，等待用户确认继续** |
| Phase 3 → 4 | 脙本模板 + 镜像版本 | **展示解析结果，等待用户确认继续** |
| Phase 4 → 5 | 节点信息 + 推荐节点 | **展示探测结果，等待用户确认继续** |
| Phase 5 | 镜像推送结果 | AskUserQuestion：确认镜像地址、输入账密、选择远程节点 |
| Phase 5 → 6 | 镜像推送结果 | **展示推送结果，等待用户确认继续** |
| Phase 6 → 7 | 完整配置参数集 | AskUserQuestion 收集配置 |
| Phase 7 → 8 | YAML 文件 + apply-all.sh | **展示生成文件，等待用户手动 kubectl apply** |
| Phase 8 → 9 | 用户确认 Pod 启动 | **等待用户确认 Pod 已启动后继续** |
| Phase 9 → 10 | 容器内 NPU 信息 | **展示探测结果，等待用户确认继续** |
| Phase 10 → 11 | deploy.sh | **展示脚本内容，等待用户手动执行** |
| Phase 11 → 12 | 用户确认部署完成 | **等待用户确认部署完成后继续** |
| Phase 12 | 输出交付 | **展示最终交付文件，流程结束** |

---

## 错误处理设计

| 场景 | 处理方式 | 处理模块 |
|------|---------|---------|
| 默认 URL 无法访问 | 提示检查网络，允许用户自定义 URL | model-list-fetcher.md |
| 模型列表提取失败 | 建议用户手动指定模型教程 URL | model-list-fetcher.md |
| 脙本块未找到 | 建议用户手动提供脚本内容 | doc-parser.md |
| kubectl 不可用 | 提示安装 kubectl，中止流程 | k8s-env-detector.md |
| 非管理节点执行 | 提示切换到管理节点，中止流程 | k8s-env-detector.md |
| K8s 集群连接失败 | 提示检查 kubeconfig，中止流程 | k8s-env-detector.md |
| Docker 不可用（远程节点） | 提示选择其他有 Docker 的节点 | image-handler.md |
| 镜像仓库登录失败 | 提示检查账密，允许重新输入 | image-handler.md |
| 镜像推送失败 | 提示检查权限和网络，允许重新尝试 | image-handler.md |
| NPU 资源未注册 | 提示检查 Device Plugin，中止流程 | k8s-env-detector.md |
| Pod 启动失败 | 提示检查镜像和资源，建议排查 | container-env-detector.md |
| 容器内 NPU 映射异常 | 提示检查 Device Plugin 配置 | container-env-detector.md |

---

## 设计决策记录

1. **执行环境：** 严格在 K8s 管理节点执行
2. **镜像处理：** 需要远程执行（SSH 到有 Docker 的节点）
3. **文档站点：** 默认 URL `https://docs.vllm.com.cn/projects/ascend/` 稳定可用
4. **用户交互：** 每个 phase 都需要用户手动确认才能继续