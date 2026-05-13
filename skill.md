---
name: vllm-deploy
description: Use when deploying vLLM models on K8s with Ascend NPU. Automates model selection, doc parsing, K8s env detection, image handling, and generates deployment YAML files.
---

# vLLM-Deploy Skill

从 vLLM-Ascend 文档自动提取部署脚本，根据 K8s 环境自动修改参数，生成一键执行的 K8s YAML。

## 执行环境

K8s 管理节点（需有 kubectl 和集群管理权限）

## 流程概述

**自动执行模式**：脚本调用无需确认，直接执行。每个 Phase 完成后等待用户确认继续。

| Phase | 执行方式 | 用户交互 |
|-------|---------|---------|
| 1 | 自动执行脚本 | Phase 结束确认 |
| 2 | 交互选择 | AskUserQuestion 选择模型/规格/部署方式 |
| 3 | 自动执行脚本 | Phase 结束确认 |
| 4 | 自动执行脚本 | Phase 结束确认 |
| 5 | 交互输入 + 自动执行 | AskUserQuestion + Phase 结束确认 |
| 6 | 交互输入 | AskUserQuestion 配置参数 |
| 7 | 自动生成文件 | Phase 结束确认 |
| 8 | 用户手动操作 | 用户执行 kubectl apply 后回复确认 |
| 9 | 自动执行脚本 | Phase 结束确认 |
| 10 | 自动生成文件 | Phase 结束确认 |
| 11 | 用户手动操作 | 用户执行 deploy.sh 后回复确认 |
| 12 | 自动生成文件 | 流程结束 |

## 开始部署

**Phase 1：获取模型列表**

直接执行：
```bash
scripts/fetch-model-list.sh
```
