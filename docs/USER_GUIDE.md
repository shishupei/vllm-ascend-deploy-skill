# vLLM-Ascend 部署技能包 — 使用手册

> 把 vLLM-Ascend 在 Kubernetes + 昇腾 NPU 环境中的部署拆成两段：准备 → 执行。
> 代理负责读文档、抓模型、填模板、跑脚本；人负责确认和点按钮。
>
> 项目概览、技能介绍、环境要求、安装方式见 [README.md](../README.md)。

---

## 一、完整工作流（Phase 级）

### 1.1 准备阶段（vllm-deploy-prepare）

```
Phase 1: 获取模型列表
         ↓
Phase 2: 用户选择（模型类型 → 具体模型 → 硬件规格 → 部署方式 → 镜像仓库）
         ↓
Phase 3: 文档解析（只解析用户选的模型文档 + K8s 部署指南）
         ↓
Phase 5: 镜像处理（拉取 → 打标签 → 推送，可跳过）
         ↓
Phase 6: 交互配置（Namespace / 模型路径 / 性能参数）
         ↓
Phase 7: 生成模板（复制对应 K8s YAML 模板到 .vllm-deploy/templates/）
         ↓
Phase 7.5: 生成启动脚本（根据部署方式生成 start-*.sh）
```

**产出目录：**

```
.vllm-deploy/
├── config.json          ← 全部配置汇总（Phase 2-6 的所有选择和参数）
├── image-info.json      ← 镜像来源和推送结果
├── templates/           ← 选中的 K8s YAML 模板（含 ${VAR} 占位符）
│   ├── single-node.yaml
│   └── multi-node-master.yaml + multi-node-worker.yaml  （多节点）
│   └── pd-separate.yaml 或 pd-separate-kthena.yaml      （PD分离）
│   └── ha-active-standby.yaml                           （主备）
└── scripts/             ← vLLM 启动脚本模板（含 ${PLACEHOLDER} 占位符）
    └── start-single-node.sh          （单节点）
    └── start-multi-node-master.sh    （多节点 Master）
    └── start-multi-node-worker.sh    （多节点 Worker）
    └── start-prefill.sh              （PD分离 Prefill）
    └── start-decode.sh               （PD分离 Decode）
```

### 1.2 执行阶段（vllm-deploy-execute）

```
Phase 4:  K8s 环境探测（kubectl → 集群 → 节点 → NPU → 用户确认节点选择）
          ↓
Phase 7补: 填充模板生成 YAML（envsubst 替换所有 ${VAR} 占位符）
          ↓
Phase 8:  指导用户 kubectl apply
          ↓          ← 用户手动执行 bash apply-all.sh
Phase 9:  容器内 NPU 探测（kubectl exec 进 Pod 检查设备映射）
          ↓
Phase 10: 生成 deploy.sh（仅 single_node / multi_node 模式）
          ↓
Phase 11: 指导用户在 Pod 内执行 deploy.sh 或验证服务
          ↓          ← 用户手动操作
Phase 12: 输出交付（final-output.json + 更新 README.md）
```

**最终交付目录：**

```
.vllm-deploy/
├── config.json                   ← Phase 6 生成
├── image-info.json               ← Phase 5 生成
├── detection-result.json         ← Phase 4 生成（集群探测）
├── container-detection-result.json ← Phase 9 生成（容器内 NPU）
├── selected-nodes.json           ← Phase 4 用户确认的节点选择
├── final-output.json             ← Phase 12 生成（部署汇总）
└── k8s/                          ← 最终交付
    ├── all.yaml                  ← 合并的资源清单（所有模式都有）
    ├── master.yaml               ← 仅 multi_node
    ├── worker-1.yaml, worker-2.yaml... ← 仅 multi_node
    ├── apply-all.sh              ← 一键 apply 脚本
    ├── deploy.sh                 ← 仅 single_node / multi_node（Phase 10 生成）
    └── README.md                 ← 部署操作指南
```

### 1.3 日志分析阶段（vllm-log-analyze）

```
Phase 1: 配置获取（plog_path / 日志类型 / 时间范围 / 日志级别）
         ↓
Phase 2: 日志提取 + 预筛（fetch-plog.sh → filter-errors.sh）
         ↓
Phase 3: AI 三层诊断（已知模式直接诊断 → 未知模式深度分析 → 关联性分析）
         ↓
Phase 4: 报告输出（diagnosis-report.md）
```

**产出目录：**

```
.vllm-deploy/log-analysis/
├── fetch-output.json        ← 原始提取结果
├── error-summary.json       ← 预筛后的分类摘要
├── diagnosis-report.md      ← AI 生成的完整诊断报告
└── raw-logs/                ← 原始日志片段
```

---

## 二、部署模式详解

| 模式 | 说明 | Pod 启动方式 | 是否需要 deploy.sh | 对应模板 |
|------|------|-------------|-------------------|----------|
| `single_node` | 单节点推理 | `tail -f /dev/null` 等待手动 | ✅ 需要 | `single-node.yaml` |
| `multi_node` | 多节点 Ray 分布式 | `tail -f /dev/null` 等待手动 | ✅ 需要（仅 Master Pod） | `multi-node-master.yaml` + `multi-node-worker.yaml` |
| `pd_separate` | Prefill/Decode 分离 | 模板内嵌 `vllm serve` 自动启动 | ❌ 不需要 | `pd-separate.yaml` 或 `pd-separate-kthena.yaml` |
| `ha_active_standby` | 主备高可用 | 模板内嵌 `vllm serve` 自动启动 | ❌ 不需要 | `ha-active-standby.yaml` |

**关键区别：**
- `single_node` 和 `multi_node` 的 Pod 先用 `tail -f /dev/null` 拉起来，等你手动把 `deploy.sh` 复制进去执行后，vLLM 服务才启动，Pod 才会变 Ready。
- `pd_separate` 和 `ha_active_standby` 的模板里已经写了启动命令，Pod apply 后会直接跑 `vllm serve`，你只需要等 Ready 然后验证。
- `pd_separate` 有两种子模式：标准 K8s Deployment 和 Volcano Kthena CRD，准备阶段会让你选。

---

## 三、最短使用路径

### 3.1 从准备到部署

```
1  在有网络的机器上：/vllm-deploy-prepare
   → 代理会依次问你：选模型 → 选硬件 → 选部署方式 → 选镜像仓库 → 确认参数

2  完成后拿到 .vllm-deploy/ 目录
   → 如果执行环境是另一台机器，把 .vllm-deploy/ 整个目录拷过去

3  在 K8s 管理节点上：/vllm-deploy-execute
   → 代理探测集群 → 让你确认节点 → 填模板 → 生成 YAML 和脚本

4  你手动执行：
   cd .vllm-deploy/k8s && bash apply-all.sh

5  等 Pod Running 后，代理引导你做容器内探测和最终启动

6  验证服务：
   curl http://<node-ip>:<node-port>/v1/models
```

### 3.2 单独做日志分析

```
1  /vllm-log-analyze
   → 代理会问你 plog 路径、时间范围等
   → 也可以在已部署的环境中直接用（此时 config.json 里已有 namespace 等信息）

2  查看生成的诊断报告：
   cat .vllm-deploy/log-analysis/diagnosis-report.md
```

---

## 四、人工确认点

这个项目**刻意不自动执行高风险操作**。以下环节必须你手动确认或执行：

| 确认点 | 你的操作 | 原因 |
|--------|---------|------|
| Phase 4 结束 | 确认节点选择 | 部署到错误的节点可能导致资源浪费或服务不稳定 |
| Phase 8 | `bash apply-all.sh` | 直接修改集群状态，不应自动执行 |
| Phase 11（single_node / multi_node） | kubectl cp + exec deploy.sh | Pod 内启动 vLLM 直接影响服务 |
| 镜像推送 | docker push | 需要你自己的仓库认证，代理无法自动登录 |

`pd_separate` 和 `ha_active_standby` 模式在 Phase 11 只需验证 Pod Ready，不需要手动进 Pod 操作。

---

## 五、脚本说明

### 准备阶段脚本

| 脚本 | 调用方式 | 做什么 |
|------|---------|--------|
| `fetch-model-list.sh` | `bash scripts/fetch-model-list.sh [URL]` | 抓取 vLLM-Ascend 模型列表页，提取所有模型名称和链接，输出 JSON |
| `parse-model-doc.sh` | `bash scripts/parse-model-doc.sh --url <URL> --hw-spec <A3\|A2> --deploy-mode <mode>` | 解析指定模型文档页，提取镜像版本、启动脚本和默认参数，输出 JSON |
| `fetch-k8s-config.sh` | `bash scripts/fetch-k8s-config.sh [URL]` | 抓取 K8s 部署指南，提取 NPU 资源类型、卷挂载和环境变量，输出 JSON |
| `start-single-node.sh` | 代理根据 config.json 填充后生成 | 单节点 vLLM 启动脚本模板 |
| `start-multi-node-master.sh` | 代理填充后生成 | 多节点 Master 启动脚本（含 Ray head 引导） |
| `start-multi-node-worker.sh` | 代理填充后生成 | 多节点 Worker 启动脚本（ray start --address 加入集群） |
| `start-prefill.sh` | 代理填充后生成 | PD 分离 Prefill（KV Producer）启动脚本 |
| `start-decode.sh` | 代理填充后生成 | PD 分离 Decode（KV Consumer）启动脚本 |

### 执行阶段脚本

| 脚本 | 调用方式 | 做什么 |
|------|---------|--------|
| `detect-k8s-env.sh` | `bash scripts/detect-k8s-env.sh` | 检查 kubectl/kubeconfig/集群连接，列出节点和 NPU 资源，输出 JSON |
| `fill-template.sh` | `bash scripts/fill-template.sh [CONFIG] [DETECTION] [NODES] [OUTPUT_DIR]` | 用 envsubst 填充模板占位符，生成最终 K8s YAML、apply-all.sh 和 README.md |
| `detect-container-npu.sh` | `kubectl exec ... -- bash /scripts/detect-npu.sh` | 在 Pod 内探测 /dev/davinci* 设备映射和 npu-smi 信息，输出 JSON |
| `generate-deploy.sh` | `bash scripts/generate-deploy.sh [CONFIG] [CONTAINER_DETECTION] [OUTPUT_DIR]` | 根据容器内 NPU 数量生成 vllm serve 启动脚本（仅 single_node / multi_node） |
| `validate-generated.sh` | 内部使用 | 验证生成的 YAML 和脚本文件 |

### 日志分析脚本

| 脚本 | 调用方式 | 做什么 |
|------|---------|--------|
| `fetch-plog.sh` | `bash scripts/fetch-plog.sh [CONFIG] [OUTPUT_DIR]` | 按 plog_config 提取昇腾 plog 日志，按时间窗口和级别过滤，输出 JSON |
| `filter-errors.sh` | `bash scripts/filter-errors.sh [FETCH_OUTPUT]` | 对提取的日志做正则预筛，分类为 7 种昇腾常见错误模式，输出 JSON |

---

## 六、模板占位符

### K8s YAML 模板中的占位符

模板使用 `${VAR}` 格式（envsubst 填充）。填充来源：

| 占位符 | 来源 | 说明 |
|--------|------|------|
| `${NAMESPACE}` | config.json → namespace | K8s Namespace |
| `${MODEL_NAME}` | config.json → selected_model | 模型名称 |
| `${MODEL_RESOURCE_NAME}` | 自动从 MODEL_NAME 派生 | K8s 资源名（小写+连字符） |
| `${IMAGE}` | config.json → target_image | 容器镜像地址 |
| `${NPU_RESOURCE_TYPE}` | detection-result.json | 如 `huawei.com/Ascend910` |
| `${NPU_COUNT}` | 根据部署方式计算 | 单节点取 master 节点 NPU 数 |
| `${MODEL_PATH}` | config.json → model_path | 模型在容器内的路径 |
| `${SERVICE_PORT}` | 默认 30000 | NodePort 端口 |
| `${MASTER_NODE_NAME}` | selected-nodes.json | 多节点 Master 节点名 |
| `${MASTER_NODE_IP}` | detection-result.json | 多节点 Master 节点 IP |
| `${WORLD_SIZE}` | selected-nodes.json → nodes.length | 分布式世界大小 |
| `${WORKER_RANK}` | 循环生成 | Worker Rank 编号 |
| `${PREFILL_REPLICAS}` / `${DECODE_REPLICAS}` | config.json | PD 分离副本数 |
| `${KV_CONNECTOR}` | config.json | KV 连接器类型（默认 MooncakeConnectorV1） |
| `${HA_REPLICAS}` / `${HA_MIN_REPLICAS}` / `${HA_MAX_REPLICAS}` | config.json | 主备高可用副本数 |

### 启动脚本模板中的占位符

脚本使用 `${VAR_PLACEHOLDER}` 格式（手动输入或 Skill 2 探测填充）：

| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${MODEL_PATH_PLACEHOLDER}` | 模型路径 | 可手动输入（Phase 6 已收集） |
| `${TP_SIZE_PLACEHOLDER}` | 张量并行大小 | 可手动输入 |
| `${NODE_IP_PLACEHOLDER}` | 节点 IP | 执行阶段探测 |
| `${WORLD_SIZE_PLACEHOLDER}` | 分布式世界大小 | 执行阶段探测 |
| `${MASTER_ADDR_PLACEHOLDER}` | Master 节点 IP | 执行阶段探测 |
| `${WORKER_RANK_PLACEHOLDER}` | Worker Rank | 执行阶段生成 |
| `${PREFILL_ADDR_PLACEHOLDER}` | Prefill 服务地址 | 执行阶段探测 |

---

## 七、日志分析 — 错误模式对照

`vllm-log-analyze` 预筛 7 种昇腾常见错误：

| 类别 | 严重等级 | 正则关键词 |
|------|---------|-----------|
| HCCL 通信错误 | high（>10 条升级 critical） | HCCL/HCCS timeout/error/abort |
| 设备超时错误 | high（<3 条降级 medium） | TS/task/execute timeout davinci/npu |
| 内存溢出 | critical | OOM / out of memory / memory exceed |
| 设备异常 | critical | device/NPU error/fault/abnormal/offline |
| 驱动错误 | high | driver/firmware error/CANN init failed |
| 资源不足 | medium | resource exhausted / device busy |
| 数据对齐 | medium | alignment/shape/dtype mismatch |

AI 诊断分三层：
1. **已知模式直接诊断**：从 `knowledge/ascend-error-patterns.md` 知识库匹配根因和修复建议
2. **未知模式深度分析**：AI 基于日志内容推断可能根因和排查方向（最多分析 20 条）
3. **关联性分析**：检查时间关联和因果链（如 HCCL 超时 → 设备超时 → 内存溢出）

---

## 八、常见问题

### 准备阶段在另一台机器上完成，怎么把产物带到执行阶段？

把 `.vllm-deploy/` 目录整体拷贝到 K8s 管理节点即可。执行阶段的所有脚本都从这个目录读取输入。

```bash
scp -r .vllm-deploy/ user@k8s-master:/home/user/project/.vllm-deploy/
```

### 镜像处理需要 Docker，但准备机器上没有 Docker 怎么办？

可以跳过镜像处理步骤。代理会把镜像信息记录到 `image-info.json`，标记 `skipped: true`。你需要自己在有 Docker 的机器上手动拉取、打标签、推送。

### `fill-template.sh` 报错找不到 selected-nodes.json？

如果 Phase 4 的节点确认环节没有生成 `selected-nodes.json`，脚本会自动从 `detection-result.json` 的 `recommended_nodes` 字段回填一个默认节点选择文件。

### PD 分离选 Kthena 还是标准 K8s？

- **标准 K8s**：适用于通用 Kubernetes 环境，用普通 Deployment + Service
- **Kthena CRD**：适用于华为昇腾 + Volcano 环境，使用 Volcano Kthena 自定义资源，KV 连接器固定为 MooncakeConnectorV1

如果你的集群里装了 Volcano 和 Kthena，选 Kthena 模板通常更省事。

### 多节点部署时 deploy.sh 只在 Master Pod 执行吗？

是的。Worker Pod 通过模板里的 `ray start --address` 命令自动加入 Ray 集群，不需要单独操作。你只需要把 `deploy.sh` 复制到 Master Pod 并执行。

### 日志分析报告说"未检测到异常"怎么办？

可能是时间范围太小或日志级别太窄。建议：
- 扩大时间范围（从 `last_1h` 改为 `last_24h` 或 `all`）
- 检查 plog 路径是否正确
- 加入 WARNING 级别（有些问题先出现 WARNING 再升级为 ERROR）

---

## 九、验证服务

部署成功后，用 NodePort 做基本检查：

```bash
# 健康检查
curl http://<node-ip>:<node-port>/health

# 模型列表
curl http://<node-ip>:<node-port>/v1/models

# 推理测试
curl http://<node-ip>:<node-port>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "<model-name>", "messages": [{"role": "user", "content": "Hello"}]}'
```

---

## 十、清理部署

```bash
# 删除 K8s 资源
kubectl delete -f .vllm-deploy/k8s/all.yaml
# 或删除整个 namespace
kubectl delete namespace <namespace>

# 清理本地产物
rm -rf .vllm-deploy/
```
