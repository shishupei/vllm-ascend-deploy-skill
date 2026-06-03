# Phase 4: K8s 环境探测

## 目标

探测 K8s 集群环境，获取：
- 节点列表
- 每个节点的 NPU 数量和类型
- 推荐的部署节点

## 前置检查

执行 `scripts/detect-k8s-env.sh`，验证：
- kubectl 是否可用
- kubeconfig 是否配置
- 集群是否可连接

## 执行脚本

```bash
bash scripts/detect-k8s-env.sh
```

## 输出

生成 `detection-result.json`：

```json
{
  "cluster_connected": true,
  "nodes": [
    {
      "name": "node-1",
      "ip": "192.168.1.101",
      "npu_type": "huawei.com/Ascend910",
      "npu_count": 8,
      "npu_available": 8,
      "labels": {"npu": "true"}
    }
  ],
  "recommended_nodes": ["node-1", "node-2"],
  "total_npu_available": 16
}
```

## AI 执行指南

1. 执行探测脚本
2. 解析输出 JSON
3. 展示节点列表和 NPU 信息
4. 根据部署方式推荐节点：
   - `single_node`: 选择 NPU 数量最多的节点
   - `multi_node`: 选择多个有足够 NPU 的节点
   - `pd_separate`: 分别推荐 Prefill 和 Decode 节点
5. 使用 AskUserQuestion 确认节点选择
6. 保存探测结果到 `.vllm-deploy/detection-result.json`
7. 将确认后的节点选择写入 `.vllm-deploy/selected-nodes.json`
8. 进入 Phase 7（补）

### 节点选择文件契约

Phase 4 确认节点后，应显式写出 `.vllm-deploy/selected-nodes.json`，供 `fill-template.sh` 消费。

推荐格式：

```json
{
  "master_node": "node-1",
  "nodes": [
    {"name": "node-1", "ip": "192.168.1.101", "npu_count": 8},
    {"name": "node-2", "ip": "192.168.1.102", "npu_count": 8}
  ]
}
```

兼容格式：

- `nodes` 也可以只写节点名数组，例如 `["node-1", "node-2"]`
- `single_node` / `ha_active_standby` 至少需要 1 个节点
- `multi_node` 需要第 1 个节点作为 Master，其余节点作为 Worker

## 用户交互

展示探测结果后，询问：
```
检测到以下节点：
- node-1: 8 个 Ascend910 NPU（可用 8）
- node-2: 8 个 Ascend910 NPU（可用 8）

推荐部署节点：node-1 (Master), node-2 (Worker)

请确认或修改节点选择：
```

## 错误处理

| 错误 | 处理 |
|------|------|
| kubectl not found | 提示安装：`apt install kubectl` |
| kubeconfig missing | 提示配置：`export KUBECONFIG=/path/to/config` |
| cluster unreachable | 提示检查网络和 API Server 地址 |
| no NPU nodes | 提示检查 Ascend Device Plugin 安装 |
