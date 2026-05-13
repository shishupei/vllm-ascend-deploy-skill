# Phase 9: 容器内环境探测模块

## 概述

用户确认 Pod 已成功启动后，进入 Pod 探测 NPU 设备映射情况，验证硬件资源是否正确挂载。

## 触发时机

用户确认已执行 `kubectl apply` 且 Pod 状态为 Running

## 输入

- Phase 6 配置的 Namespace
- 用户确认的 Pod 名称

## 处理步骤

1. 获取 Pod 状态（`kubectl get pods -n <namespace>`）
2. 确认 Pod 状态为 Running
3. **自动执行** `scripts/detect-container-npu.sh` 进入 Pod 探测 NPU 设备映射情况
4. 验证 NPU 设备是否正确挂载
5. 确定容器内实际可用的硬件规格
6. **Phase 9 完成**，等待用户确认进入 Phase 10

## 输出

```json
{
  "pod_name": "vllm-deploy-node1-xxx",
  "pod_status": "Running",
  "container_npu_count": 8,
  "devices_mapped": ["davinci0", "davinci1", "davinci2", "davinci3", "davinci4", "davinci5", "davinci6", "davinci7"]
}
```

## 调用脚本

```bash
scripts/detect-container-npu.sh <pod_name> <namespace>
```

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| Pod 启动失败 | 提示检查镜像、资源和节点状态，建议用户排查后重新触发 |
| 容器内 NPU 映射异常 | 提示检查 Device Plugin 配置，建议用户排查 |

## 用户确认

展示探测结果后，询问用户是否继续进入 Phase 10（部署脚本生成）。