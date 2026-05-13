# Phase 5: 镜像处理模块

## 概述

远程到有 Docker 环境的节点执行镜像拉取、重新打标签、推送到用户指定的镜像仓库。

## 输入

- Phase 3 提取的源镜像版本（如 `quay.io/vllm-ascend/vllm-ascend:v0.6.0`）
- Phase 2 用户指定的目标镜像仓库地址
- Phase 4 探测的节点列表（用于选择有 Docker 的节点）

## 执行位置

SSH 远程执行（需要在有 Docker 环境的节点）

## 处理步骤

1. 通过 AskUserQuestion 确认/修改目标镜像地址
2. 通过 AskUserQuestion 选择有 Docker 环境的远程节点
3. 通过 AskUserQuestion 输入 SSH 登录用户名
4. 通过 AskUserQuestion 输入镜像仓库用户名和密码
5. 调用 `scripts/push-image.sh` SSH 远程执行：
   - 登录目标镜像仓库
   - 拉取官方镜像
   - 重新打标签为用户仓库地址
   - 推送镜像到用户仓库
6. 等待用户确认推送结果

## 输出

```json
{
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "push_success": true
}
```

## 调用脚本

```bash
scripts/push-image.sh <source_image> <target_registry> <remote_node_ip> <ssh_user> <docker_username> <docker_password>
```

**参数说明：**
- `source_image`: 源镜像地址（如 quay.io/ascend/vllm-ascend:v0.18.0rc1）
- `target_registry`: 目标镜像仓库地址
- `remote_node_ip`: 远程节点 IP
- `ssh_user`: SSH 登录用户名（可选，默认使用当前用户）
- `docker_username`: Docker 仓库用户名
- `docker_password`: Docker 仓库密码

## 交互工具

使用 AskUserQuestion 工具：

### Q1: 确认目标镜像地址

```json
{
  "question": "目标镜像地址将设置为 harbor.example.com/library/vllm-ascend:v0.6.0，是否需要修改？",
  "header": "镜像地址",
  "options": [
    {"label": "确认使用", "description": "使用上述镜像地址"},
    {"label": "修改地址", "description": "手动输入新的镜像地址"}
  ],
  "multiSelect": false
}
```

### Q2: 选择远程节点

```json
{
  "question": "请选择有 Docker 环境的节点用于镜像处理",
  "header": "远程节点",
  "options": [
    {"label": "node-1 (192.168.1.100)", "description": "NPU 节点，可能有 Docker"},
    {"label": "node-2 (192.168.1.101)", "description": "NPU 节点，可能有 Docker"}
  ],
  "multiSelect": false
}
```

### Q3: 输入 SSH 用户

```json
{
  "question": "请输入 SSH 登录用户名（留空使用当前用户）",
  "header": "SSH 用户",
  "options": [],
  "multiSelect": false
}
```

### Q4: 输入账密

```json
{
  "question": "请输入镜像仓库登录信息",
  "header": "登录账密",
  "options": [],
  "multiSelect": false
}
```

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| Docker 不可用（远程节点） | 提示选择其他有 Docker 的节点，允许重新选择 |
| 镜像仓库登录失败 | 提示检查镜像仓库地址和认证信息，允许重新输入账密 |
| 镜像推送失败 | 提示检查镜像仓库权限和网络连通性，允许重新尝试 |

## 用户确认

展示推送结果后，询问用户是否继续进入 Phase 6（配置收集）。