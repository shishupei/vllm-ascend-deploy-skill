# Phase 12: 输出交付模块

## 概述

整理所有生成的文件，创建输出目录结构，生成执行指南 README，完成交付。

## 触发时机

用户确认部署脚本已执行且服务已启动

## 输入

- Phase 6-11 生成的所有文件

## 处理步骤

1. 确认 `.vllm-deploy/k8s/` 输出目录已创建
2. 确认所有 YAML 和脚本文件已写入
3. 生成 `README.md` 执行指南（包含分步执行说明）
4. 展示最终交付文件列表
5. 流程结束

## 最终交付

```
.vllm-deploy/k8s/
├── README.md            # 执行指南
├── namespace.yaml
├── configmap.yaml
├── deployment-node1.yaml
├── deployment-node2.yaml
├── service.yaml
├── apply-all.sh         # 一键 apply 所有 YAML
└── deploy.sh            # Pod 内部署脚本
```

## README.md 内容模板

```markdown
# vLLM 部署执行指南

## 文件说明

| 文件 | 说明 |
|------|------|
| namespace.yaml | K8s Namespace 定义 |
| configmap.yaml | 配置参数存储 |
| deployment-node1.yaml | node-1 Deployment |
| deployment-node2.yaml | node-2 Deployment |
| service.yaml | 服务端口暴露 |
| apply-all.sh | 一键执行脚本 |
| deploy.sh | Pod 内 vllm serve 启动脚本 |

## 执行步骤

1. 执行 apply-all.sh 创建 K8s 资源
2. 等待 Pod 状态变为 Running
3. 进入 Pod 执行 deploy.sh 启动服务
4. 通过 Service 端口访问服务

## 访问服务

服务端口：8000（NodePort）
访问地址：http://<node-ip>:8000
```

## 错误处理

此模块为纯文件操作模块，不涉及技术性操作，无特殊错误场景。

输出目录创建失败时，提示用户检查权限并手动创建。

## 用户确认

展示最终交付文件列表后，询问用户确认部署流程是否完成，流程结束。