# Phase 10: 部署脚本生成模块

## 概述

根据容器内探测的 NPU 数量和配置参数，生成 Pod 内执行的 `vllm serve` 启动脚本。

## 输入

- Phase 9 容器内探测结果
- Phase 6 配置参数
- Phase 2 部署方式

## 处理步骤

1. 根据容器内 NPU 数量计算 `--tensor-parallel-size`
2. 根据部署方式配置分布式参数：
   - 单节点：无需分布式配置
   - 多节点：设置 `--master-addr`、`--master-port`、`--rank`
   - PD分离：设置 Prefill 和 Decode 的分布式参数
3. 生成 `vllm serve` 启动命令
4. 生成 Pod 内执行的部署脚本 `deploy.sh`
5. 展示脚本内容供用户确认
6. 等待用户确认脚本内容

## 输出文件

```
.vllm-deploy/k8s/
└── deploy.sh            # 在 Pod 内执行 vllm serve
```

## 脚本内容示例

```bash
#!/bin/bash

vllm serve /data/models/GLM-5 \
  --tensor-parallel-size 8 \
  --max-model-len 8192 \
  --max-num-seqs 256 \
  --trust-remote-code
```

## 多节点分布式示例

```bash
#!/bin/bash

vllm serve /data/models/GLM-5 \
  --tensor-parallel-size 16 \
  --max-model-len 8192 \
  --max-num-seqs 256 \
  --master-addr 192.168.1.100 \
  --master-port 29500 \
  --rank 0 \
  --trust-remote-code
```

## 用户确认

展示脚本内容后，询问用户是否手动在 Pod 内执行部署脚本。