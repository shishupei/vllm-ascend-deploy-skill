# vLLM-Deploy Skill

从 vLLM-Ascend 文档自动提取部署脚本，根据环境修改参数，生成一键执行脚本。

## 使用方式

输入 `/vllm-deploy` 启动 Skill。

## 工作流程

### Phase 1：文档解析

调用 `modules/doc-parser.md`，输入用户提供模型教程 URL，输出脚本模板集合。

### Phase 2：环境探测

调用 `modules/env-detector.md`，自动探测：
- 本机 IP 地址
- 网卡名称
- NPU 设备数量
- 硬件规格（A3/A2）
- 可用容器环境（Docker/kubectl）

### Phase 3：交互配置

调用 `modules/config-guide.md`，通过问答获取：
- 部署模式（单节点/多节点/PD分离）
- 容器启动方式（Docker/K8s）
- 模型路径
- 性能参数
- 多节点/PD分离配置（如适用）

### Phase 4：脚本生成

根据容器方式调用：
- Docker：`modules/docker-generator.md`
- K8s：`modules/k8s-generator.md`

### Phase 5：输出交付

调用 `modules/output-guide.md`，生成：
- 脚本文件（.vllm-deploy/ 目录）
- 执行指南（README.md）