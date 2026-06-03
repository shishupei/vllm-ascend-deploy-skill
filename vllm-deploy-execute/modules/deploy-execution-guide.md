# Phase 11: 部署执行指导

## 目标

根据部署模式，指导用户完成 vLLM 服务的最终启动或验证。

## 模式区分

不同部署模式在此阶段的行为不同：

| deploy_mode | 是否有独立 deploy.sh | Pod 启动方式 | Phase 11 操作 |
|-------------|----------------------|--------------|---------------|
| `single_node` | 有 | `tail -f /dev/null` 等待手动执行 | 用户需 kubectl cp + kubectl exec deploy.sh |
| `multi_node` | 有 | `tail -f /dev/null` 等待手动执行 | 仅在 Master Pod 内执行 deploy.sh，Worker 已通过 ray start 加入集群 |
| `pd_separate` | 无 | 模板内嵌 `vllm serve` 启动命令 | 仅需验证 Pod 就绪和服务可达 |
| `ha_active_standby` | 无 | 模板内嵌 `vllm serve` 启动命令 | 仅需验证 Pod 就绪和服务可达 |

## single_node / multi_node：手动执行 deploy.sh

对于这两种模式，Pod 使用 `tail -f /dev/null` 等待用户手动执行 deploy.sh。
在执行 deploy.sh 之前，Pod 一般只能到 `Running`，不会通过 `Ready`。

### 单节点

```bash
POD_NAME=$(kubectl get pods -n <namespace> -l app=vllm-deploy,model=<model-name> -o jsonpath='{.items[0].metadata.name}')
kubectl cp deploy.sh -n <namespace> "$POD_NAME":/tmp/deploy.sh
kubectl exec -n <namespace> "$POD_NAME" -- bash /tmp/deploy.sh
```

### 多节点

仅在 Master Pod 内执行 deploy.sh。Worker Pod 必须已处于 Running 状态并通过 `ray start --address=...` 加入 Ray 集群，之后才能在 Master Pod 执行 deploy.sh。

```bash
# Master Pod
MASTER_POD=$(kubectl get pods -n <namespace> -l app=vllm-deploy,model=<model-name>,role=master -o jsonpath='{.items[0].metadata.name}')
kubectl cp deploy.sh -n <namespace> "$MASTER_POD":/tmp/deploy.sh
kubectl exec -n <namespace> "$MASTER_POD" -- bash /tmp/deploy.sh
```

## pd_separate / ha_active_standby：验证服务就绪

这两种模式的模板已内嵌 `vllm serve` 启动命令，Pod apply 后会直接启动服务。Phase 11 仅需验证：

### PD 分离

1. 检查 Prefill Pod readinessProbe 通过
2. 检查 Decode Pod readinessProbe 通过
3. 确认 Prefill 和 Decode 服务均可达

```bash
kubectl get pods -n <namespace> -w
# 等所有 Pod 进入 Running 且 Ready
```

### 主备高可用

1. 检查所有 Pod readinessProbe 通过
2. 确认至少一个 Pod 的 vLLM 服务可达

```bash
kubectl get pods -n <namespace> -w
# 等至少一个 Pod Ready
```

## 验证服务

启动成功后（无论哪种模式），验证：

```bash
curl http://<node-ip>:<node-port>/health
curl http://<node-ip>:<node-port>/v1/models
```

## 下一步

用户确认服务启动后，进入 Phase 12（输出交付）。
