# Phase 12: 输出整理

## 目的
整理所有生成的文件，创建最终的交付目录结构，并生成执行指南 README.md。

## 输入
- Phase 6-11 生成的所有文件

## 执行位置
- 管理节点或本地终端

## 步骤
1. 创建 `.vllm-deploy/k8s/` 输出目录（如不存在）
2. 确认所有文件已写入：
   - `namespace.yaml`
   - `configmap.yaml`
   - `deployment-node1.yaml`（及多节点的其他 deployment 文件）
   - `service.yaml`
   - `apply-all.sh`
   - `deploy.sh`
3. 生成 `README.md` 执行指南：
   - 包含项目概述
   - 包含分步执行说明
   - 包含验证命令
   - 包含故障排查指南
4. 展示最终交付目录结构

## 输出
```
.vllm-deploy/k8s/
├── README.md            # 执行指南
├── namespace.yaml       # 命名空间定义
├── configmap.yaml       # 配置参数
├── deployment-node1.yaml # 节点1 Deployment
├── deployment-node2.yaml # 节点2 Deployment（多节点部署时）
├── service.yaml         # Service 暴露
├── apply-all.sh         # 一键 apply 所有 YAML
└── deploy.sh            # Pod 内部署脚本
```

README.md 内容结构：
```markdown
# vLLM 部署文件

## 概述
- 模型：GLM-5
- 部署模式：多节点
- 硬件规格：A3 (16卡)
- 镜像：harbor.example.com/library/vllm-ascend:v0.6.0

## 执行步骤

### 1. 应用 K8s YAML
\`\`\`bash
cd .vllm-deploy/k8s
bash apply-all.sh
\`\`\`

### 2. 验证 Pod 状态
\`\`\`bash
kubectl get pods -n vllm-deploy
\`\`\`

### 3. 执行部署脚本
\`\`\`bash
kubectl exec -n vllm-deploy <pod-name> -- bash /tmp/deploy.sh
\`\`\`

### 4. 验证服务
\`\`\`bash
kubectl logs -n vllm-deploy <pod-name> -f
\`\`\`

## 故障排查
- Pod 启动失败：检查镜像和资源配额
- NPU 不可用：检查 Device Plugin 配置
- 服务无法访问：检查 Service 和 NodePort 配置
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| 文件写入失败 | 提示检查目录权限和磁盘空间 |
| 文件缺失 | 列出缺失文件，提示重新生成 |
| README 生成失败 | 使用默认模板，仅替换关键参数 |

## 关联资源
- 脚本：无
- 模板：无
- 下一阶段：无（流程结束）