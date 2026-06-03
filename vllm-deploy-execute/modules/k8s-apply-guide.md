# Phase 8: K8s Apply 指导

## 目标

指导用户执行 K8s Apply，部署 vLLM 服务。

## 输入

- `.vllm-deploy/k8s/*.yaml` - 生成的 K8s YAML 文件
- `.vllm-deploy/k8s/apply-all.sh` - 一键部署脚本

## 用户交互点

此阶段需要用户手动执行，AI 等待用户确认。

## AI 执行指南

1. 展示 `.vllm-deploy/k8s/` 目录内容
2. 提示用户执行一键部署脚本
3. 提供手动 Apply 的备选方案
4. 等待用户确认 Pod 启动成功

## 指导输出

```
=== 部署文件已生成 ===

目录：.vllm-deploy/k8s/
文件：
- all.yaml
- master.yaml（仅 multi_node）
- worker-*.yaml（仅 multi_node）
- apply-all.sh
- README.md

执行部署：
1. cd .vllm-deploy/k8s/
2. bash apply-all.sh

或手动执行：
kubectl apply -f all.yaml

完成后请回复 "部署完成" 或报告错误信息。
```

## 错误处理建议

| 错误 | 处理建议 |
|------|---------|
| ImagePullBackOff | 检查镜像是否存在于目标仓库 |
| Pending | 检查节点资源是否足够 |
| CrashLoopBackOff | 检查模型路径和容器日志 |
| Insufficient NPU | 检查节点 NPU 是否被占用 |

## 下一步

用户确认 Pod 启动后，进入 Phase 9（容器内 NPU 探测）。