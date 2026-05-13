---
name: vllm-deploy
description: Use when deploying vLLM models on K8s with Ascend NPU. Automates model selection, doc parsing, K8s env detection, image handling, and generates deployment YAML files.
---

# vLLM-Deploy Skill

从 vLLM-Ascend 文档自动提取部署脚本，根据 K8s 环境自动修改参数，生成一键执行的 K8s YAML。

## 执行环境

K8s 管理节点（需有 kubectl 和集群管理权限）

## 流程概述

用户触发此技能后，将进入 Phase 1 开始 12 阶段流程。每个阶段完成后需要用户确认才能继续。

## 开始部署

请确认你当前在 K8s 管理节点，且有 kubectl 和集群管理权限。
