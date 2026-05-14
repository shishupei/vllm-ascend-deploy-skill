# Phase 5: 镜像处理

## 目的
将官方 vLLM-Ascend 镜像拉取并推送到用户指定的目标镜像仓库，确保集群内可访问。

## 输入
- Phase 3 提取的源镜像版本（如 `quay.io/vllm-ascend/vllm-ascend:v0.6.0`）
- Phase 2 用户指定的目标镜像仓库地址（如 `harbor.example.com/library`）

## 执行位置
- 有 Docker 环境的节点（管理节点或工作节点）

## 步骤
1. 确认 Docker 环境可用（`docker --version`）
2. 登录目标镜像仓库：
   ```bash
   docker login harbor.example.com
   ```
3. 拉取官方镜像：
   ```bash
   docker pull quay.io/vllm-ascend/vllm-ascend:v0.6.0
   ```
4. 重新打标签为用户仓库地址：
   ```bash
   docker tag quay.io/vllm-ascend/vllm-ascend:v0.6.0 \
     harbor.example.com/library/vllm-ascend:v0.6.0
   ```
5. 推送镜像到用户仓库：
   ```bash
   docker push harbor.example.com/library/vllm-ascend:v0.6.0
   ```
6. 验证推送成功

## 输出
```json
{
  "source_image": "quay.io/vllm-ascend/vllm-ascend:v0.6.0",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0",
  "image_tag": "v0.6.0",
  "push_success": true,
  "push_time": "2024-01-15T11:00:00Z"
}
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| Docker 不可用 | 提示在有 Docker 的节点执行镜像处理步骤，或安装 Docker |
| 镜像仓库登录失败 | 提示检查镜像仓库地址和认证信息（用户名/密码或 token） |
| 官方镜像拉取失败 | 提示检查网络连接，可能需要配置代理或镜像加速器 |
| 镜像推送失败 | 提示检查镜像仓库权限和网络连通性 |
| 镜像仓库空间不足 | 提示清理旧镜像或扩展仓库容量 |

## 关联资源
- 脚本：`scripts/push-image.sh`
- 模板：无
- 下一阶段：`modules/config-guide.md`