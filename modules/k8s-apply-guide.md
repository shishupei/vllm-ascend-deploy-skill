# Phase 8: K8s Apply 指导

## 目的
指导用户手动执行生成的 K8s YAML 文件，创建部署所需的命名空间、ConfigMap、Deployment 和 Service。

## 输入
- Phase 7 生成的 `.vllm-deploy/k8s/` 目录及所有文件

## 执行位置
- K8s 管理节点（需有 kubectl 和集群管理权限）

## 步骤
1. **展示生成的文件列表**
   - 列出 `.vllm-deploy/k8s/` 目录下所有 YAML 文件
   - 展示 `apply-all.sh` 脚本内容供用户审阅

2. **提供执行指导**
   - 方式一：一键执行脚本
     ```bash
     cd .vllm-deploy/k8s
     bash apply-all.sh
     ```
   - 方式二：手动逐个 apply
     ```bash
     kubectl apply -f namespace.yaml
     kubectl apply -f configmap.yaml
     kubectl apply -f deployment-node1.yaml
     kubectl apply -f deployment-node2.yaml
     kubectl apply -f service.yaml
     ```

3. **等待用户确认执行**
   - 用户需要手动执行上述命令
   - 本阶段为用户操作阶段，不自动执行

4. **验证执行结果**
   - 用户执行后，提示验证命令：
     ```bash
     kubectl get pods -n <namespace>
     kubectl get svc -n <namespace>
     ```

## 输出
- 用户确认 YAML 已 apply 到集群
- Pod 状态检查结果

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| kubectl apply 失败 | 提示检查错误信息，常见问题：命名空间已存在、资源配额不足、镜像拉取失败 |
| Pod 启动失败 | 提示查看 Pod 日志：`kubectl logs -n <namespace> <pod-name>` |
| 节点资源不足 | 提示检查节点 NPU 资源：`kubectl describe node <node-name>` |
| Service 无法访问 | 提示检查 NodePort 分配和防火墙配置 |

## 关联资源
- 脚本：无（用户手动执行）
- 模板：无
- 下一阶段：`modules/container-env-detector.md`