# Phase 4: 探测 K8s 环境

## 目的
自动探测 Kubernetes 集群环境，获取节点信息、NPU 设备数量和硬件规格，为部署配置提供基础数据。

## 输入
- Phase 2 用户选择的硬件规格和部署方式

## 执行位置
- K8s 管理节点（需有 kubectl 和集群管理权限）

## 步骤
1. 检查 `kubectl` 是否可用
2. 检查 K8s 集群连接状态（`kubectl cluster-info`）
3. 获取集群节点列表（`kubectl get nodes`）
4. 获取各节点 IP 地址（`kubectl get nodes -o wide`）
5. 探测各节点 NPU 设备数量：
   - 方式1：通过节点标签（`kubectl get nodes --show-labels`，查找 `ascend-npu` 相关标签）
   - 方式2：通过资源容量（`kubectl describe node <name>`，查看 `davinci` 资源）
   - 方式3：远程 SSH 到工作节点执行 `npu-smi`
6. 判断硬件规格：A3（16卡）或 A2（8卡）
7. 根据用户选择的部署模式推荐使用的节点
8. 展示探测结果供用户确认

## 输出
```json
{
  "kubectl_available": true,
  "cluster_connected": true,
  "cluster_info": {
    "server": "https://192.168.1.1:6443",
    "version": "v1.28.0"
  },
  "nodes": [
    {
      "name": "node-1",
      "ip": "192.168.1.100",
      "npu_count": 16,
      "hw_spec": "A3",
      "labels": {
        "ascend-npu": "true",
        "node-type": "worker"
      }
    },
    {
      "name": "node-2",
      "ip": "192.168.1.101",
      "npu_count": 16,
      "hw_spec": "A3",
      "labels": {
        "ascend-npu": "true",
        "node-type": "worker"
      }
    }
  ],
  "recommended_nodes": ["node-1", "node-2"],
  "deploy_mode": "multi_node"
}
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| kubectl 不可用 | 提示安装 kubectl 并配置 kubeconfig |
| 非管理节点执行 | 提示切换到管理节点或确保有集群管理权限 |
| K8s 集群连接失败 | 提示检查 kubeconfig 配置和网络连通性 |
| NPU 资源未注册 | 提示检查 Ascend Device Plugin 是否正确安装 |
| 节点 NPU 数量不匹配用户选择的规格 | 警告用户，建议重新选择硬件规格或检查节点配置 |

## 关联资源
- 脚本：`scripts/detect-k8s-env.sh`
- 模板：无
- 下一阶段：`modules/image-handler.md`