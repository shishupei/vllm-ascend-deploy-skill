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