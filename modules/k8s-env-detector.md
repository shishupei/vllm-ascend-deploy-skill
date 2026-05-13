# Phase 4: K8s 环境探测模块

## 概述

探测 K8s 集群状态、节点信息、NPU 资源数量，为后续部署提供环境数据。

## 输入

- 无（自动执行探测）

## 执行位置

K8s 管理节点（需要 kubectl 和集群管理权限）

## 处理步骤

1. **自动执行** `scripts/detect-k8s-env.sh` 探测：
   - 检查 `kubectl` 是否可用
   - 检查 K8s 集群连接状态
   - 获取集群节点列表
   - 获取各节点 IP 地址和 NPU 数量
   - 判断硬件规格（A3/A2）
2. 根据用户选择的部署模式推荐使用的节点
3. **Phase 4 完成**，等待用户确认进入 Phase 5

## 输出

```json
{
  "kubectl_available": true,
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-1",
      "ip": "192.168.1.100",
      "npu_count": 16,
      "hw_spec": "A3"
    },
    {
      "name": "node-2",
      "ip": "192.168.1.101",
      "npu_count": 16,
      "hw_spec": "A3"
    }
  ],
  "recommended_nodes": ["node-1", "node-2"]
}
```

## 调用脚本

```bash
scripts/detect-k8s-env.sh
```

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| kubectl 不可用 | 提示安装 kubectl 并配置 kubeconfig，中止流程 |
| 非管理节点执行 | 提示切换到管理节点或确保有集群管理权限，中止流程 |
| K8s 集群连接失败 | 提示检查 kubeconfig 配置和网络连通性，中止流程 |
| NPU 资源未注册 | 提示检查 Ascend Device Plugin 是否正确安装，中止流程 |

## 用户确认

展示探测结果（节点信息、推荐节点）后，询问用户是否继续进入 Phase 5（镜像处理）。