# Phase 11: 部署执行指导

## 目标

指导用户在 Pod 内执行 vLLM 启动脚本，完成服务部署。

## 输入

- `.vllm-deploy/k8s/deploy.sh` - 生成的启动脚本
- Pod 名称列表

## 用户交互点

此阶段需要用户手动在 Pod 内执行脚本，AI 等待用户确认。

## AI 执行指南

1. 展示需要执行的 Pod 和对应脚本
2. 提供执行命令模板
3. 等待用户确认 vLLM 服务启动成功

## 指导输出

```
=== 在 Pod 内执行 vLLM 启动脚本 ===

Pod: vllm-glm5-master-xxx
执行命令：
kubectl exec -n vllm-glm5 vllm-glm5-master-xxx -- bash /path/to/deploy.sh

或交互式进入：
kubectl exec -n vllm-glm5 -it vllm-glm5-master-xxx -- bash
cd /path/to/scripts
bash deploy.sh

完成后请回复 "vLLM 服务已启动" 或报告错误日志。
```

## 多节点执行顺序

对于多节点部署，执行顺序：
1. 先启动 Master Pod 的脚本
2. 等待 Master 就绪
3. 再启动各 Worker Pod 的脚本

## PD 分离执行顺序

对于 PD 分离部署：
1. 先启动 Prefill Pod
2. 等待 Prefill 就绪
3. 再启动 Decode Pod

## 验证服务

启动成功后，验证：
```bash
curl http://<pod-ip>:8000/health
curl http://<pod-ip>:8000/v1/models
```

## 下一步

用户确认服务启动后，进入 Phase 12（输出交付）。