# Phase 11: 部署执行指导

## 目的
指导用户确认并手动执行生成的 `deploy.sh` 脚本，在 Pod 内启动 vLLM 服务。

## 输入
- Phase 10 生成的 `.vllm-deploy/k8s/deploy.sh` 脚本
- Phase 9 探测的 Pod 名称
- Phase 6 配置的 namespace

## 执行位置
- K8s 管理节点（通过 kubectl exec 在 Pod 内执行）

## 步骤
1. **展示脚本内容**
   - 显示 `.vllm-deploy/k8s/deploy.sh` 完整内容
   - 高亮关键参数：模型路径、tensor-parallel-size、max-model-len 等

2. **等待用户确认**
   - 提示用户审阅脚本内容
   - 强调：请确认脚本内容无误后再执行

3. **提供执行命令**
   - 方式一：直接在 Pod 内执行脚本
     ```bash
     kubectl exec -n <namespace> <pod-name> -- bash -c "$(cat .vllm-deploy/k8s/deploy.sh)"
     ```
   - 方式二：复制脚本到 Pod 后执行
     ```bash
     kubectl cp .vllm-deploy/k8s/deploy.sh <namespace>/<pod-name>:/tmp/deploy.sh
     kubectl exec -n <namespace> <pod-name> -- bash /tmp/deploy.sh
     ```

4. **验证服务启动**
   - 用户执行后，提示验证命令：
     ```bash
     kubectl logs -n <namespace> <pod-name> -f
     ```
   - 检查服务是否正常启动，监听 8000 端口

## 输出
- 用户确认脚本已执行
- vLLM 服务启动状态

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| 脚本执行失败 | 提示查看 Pod 日志：`kubectl logs -n <namespace> <pod-name>` |
| 模型路径不存在 | 提示检查 Pod 内模型挂载路径是否正确 |
| 端口冲突 | 提示检查 8000 端口是否被占用，可修改脚本中的端口配置 |
| NPU 设备不可用 | 提示检查设备挂载配置，确认 Pod 内可以看到 NPU 设备 |
| 内存不足 | 提示调整 max-model-len 或 max-num-seqs 参数降低内存占用 |

## 关联资源
- 脚本：无（用户手动执行）
- 模板：无
- 下一阶段：`modules/output-guide.md`