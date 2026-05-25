# Phase 7.5: 生成 vLLM 启动脚本

## 目标

根据部署方式生成对应的 vLLM 服务启动脚本，环境信息来源支持：
- 手动输入：用户在 Phase 6 提供已知参数
- Skill 2 探测：未知参数保留占位符，由 Skill 2 填充

## 输入

- config.json（Phase 6 生成的配置）
- deploy_mode（部署方式）

## 可用脚本模板

| 脚本文件 | 适用部署方式 | 说明 |
|----------|--------------|------|
| `start-single-node.sh` | 单节点 | 单机启动命令 |
| `start-multi-node-master.sh` | 多节点 Master | Rank 0 启动命令 |
| `start-multi-node-worker.sh` | 多节点 Worker | Rank 1-N 启动命令 |
| `start-prefill.sh` | PD 分离 Prefill | KV Producer 启动命令 |
| `start-decode.sh` | PD 分离 Decode | KV Consumer 启动命令 |

## 占位符说明

脚本使用 `${VAR_PLACEHOLDER}` 格式的占位符，表示需要 Skill 2 探测填充：

### 通用占位符
| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${MODEL_PATH_PLACEHOLDER}` | 模型路径 | 可手动输入 |
| `${TP_SIZE_PLACEHOLDER}` | 张量并行大小 | 可手动输入 |
| `${NODE_IP_PLACEHOLDER}` | 节点 IP | Skill 2 探测 |

### 多节点专属占位符
| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${WORLD_SIZE_PLACEHOLDER}` | 分布式世界大小 | Skill 2 探测 |
| `${MASTER_ADDR_PLACEHOLDER}` | Master 节点 IP | Skill 2 探测 |
| `${WORKER_RANK_PLACEHOLDER}` | Worker Rank | Skill 2 生成 |

### PD 分离专属占位符
| 占位符 | 含义 | 填充时机 |
|--------|------|----------|
| `${PREFILL_TP_SIZE_PLACEHOLDER}` | Prefill TP Size | 可手动输入 |
| `${DECODE_TP_SIZE_PLACEHOLDER}` | Decode TP Size | 可手动输入 |
| `${DECODE_MAX_TOKENS_PLACEHOLDER}` | Decode Max Tokens | 可手动输入 |
| `${PREFILL_ADDR_PLACEHOLDER}` | Prefill 服务地址 | Skill 2 探测 |

## 脚本选择逻辑

根据 `deploy_mode` 选择：

| deploy_mode | 生成的脚本 |
|-------------|------------|
| `single_node` | `start-single-node.sh` |
| `multi_node` | `start-multi-node-master.sh` + 多个 `start-multi-node-worker.sh` |
| `pd_separate` | `start-prefill.sh` + `start-decode.sh` |
| `ha_active_standby` | `start-single-node.sh`（每个副本相同） |

## 输出目录

```
.vllm-deploy/
└── scripts/
    └── start-*.sh    # 根据部署方式生成的启动脚本
```

## AI 执行指南

1. 读取 `config.json` 获取部署方式
2. 根据部署方式选择对应脚本模板
3. 填充已知参数（从 config.json）
4. 保留未知参数为占位符
5. 生成脚本文件到 `.vllm-deploy/scripts/`
6. 展示脚本内容供用户确认
7. 提示：未知参数将在 Skill 2 执行时探测填充