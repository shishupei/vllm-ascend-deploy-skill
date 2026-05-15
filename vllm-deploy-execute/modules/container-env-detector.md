# Phase 9: 容器内环境探测

## 目标

进入已启动的 Pod，探测容器内的 NPU 设备映射情况。

## 前置条件

- Phase 8 已完成，Pod 处于 Running 状态
- 用户已确认 Pod 启动成功

## 执行方式

通过 kubectl exec 进入 Pod 执行探测脚本。

## AI 执行指南

1. 获取 Pod 名称：
   ```bash
   kubectl get pods -n ${NAMESPACE} -l app=vllm-deploy
   ```

2. 在 Pod 内执行探测：
   ```bash
   kubectl exec -n ${NAMESPACE} ${POD_NAME} -- bash scripts/detect-container-npu.sh
   ```

3. 解析探测结果，确认 NPU 设备映射正确

4. 如果映射异常，提示检查 Device Plugin 配置

## 探测内容

- `/dev` 目录下的 NPU 设备文件
- `npu-smi` 命令输出（如果可用）
- 环境变量中的 NPU 相关配置

## 输出

容器内 NPU 信息 JSON：

```json
{
  "pod_name": "vllm-glm5-master-xxx",
  "npu_devices": [
    "/dev/davinci0",
    "/dev/davinci1"
  ],
  "npu_count": 2,
  "npu_smi_available": true
}
```

## 异常处理

如果探测结果显示 NPU 设备数量与预期不符：
- 检查 Deployment 的 resources.limits 配置
- 检查 Ascend Device Plugin 是否正常运行
- 检查节点上的 NPU 是否被其他 Pod 占用

## 下一步

探测成功后，进入 Phase 10（生成部署脚本）。