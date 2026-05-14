# Phase 9: 探测容器环境

## 目的
在 Pod 启动后探测容器内的 NPU 设备映射情况，验证硬件资源是否正确挂载，并确定容器内实际可用的 NPU 数量。

## 输入
- Phase 8 用户确认 Pod 已启动
- Phase 6 配置的 namespace

## 执行位置
- K8s 管理节点（通过 kubectl exec 进入 Pod）

## 步骤
1. 获取 Pod 状态：
   ```bash
   kubectl get pods -n <namespace>
   ```
2. 选择目标 Pod（根据部署模式可能有多个 Pod）
3. 进入 Pod 探测 NPU 设备映射情况：
   ```bash
   kubectl exec -n <namespace> <pod-name> -- ls -la /dev/ | grep davinci
   ```
4. 验证 NPU 设备是否正确挂载：
   ```bash
   kubectl exec -n <namespace> <pod-name> -- npu-smi info
   ```
5. 确定容器内实际可用的硬件规格（NPU 数量和类型）
6. 记录 NPU 设备编号（如 davinci0, davinci1, ...）

## 输出
```json
{
  "pod_name": "vllm-deploy-node1-xxx",
  "pod_status": "Running",
  "container_npu_count": 8,
  "devices_mapped": ["davinci0", "davinci1", "davinci2", "davinci3", "davinci4", "davinci5", "davinci6", "davinci7"],
  "hw_spec_detected": "A2",
  "npu_info": {
    "chip_type": "Ascend910",
    "chip_count": 8
  }
}
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| Pod 未运行 | 提示查看 Pod 状态和日志，等待 Pod 启动完成 |
| 容器内 NPU 映射异常 | 提示检查 Device Plugin 配置，确认资源请求是否正确 |
| npu-smi 命令不可用 | 提示镜像可能缺少 NPU 驱动或工具，建议检查镜像版本 |
| NPU 数量与预期不符 | 警告用户，建议检查 Deployment 中的资源请求配置 |

## 关联资源
- 脚本：`scripts/detect-container-npu.sh`
- 模板：无
- 下一阶段：`modules/deploy-generator.md`