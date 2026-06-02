# Phase 1: 配置获取/问答

## 目标

获取 plog 日志分析所需的配置参数。如果 `.vllm-deploy/config.json` 中已有 `plog_config`，直接使用；否则通过交互问答创建。

## 前置检查

1. 检查 `.vllm-deploy/` 目录是否存在
   - 不存在 → 创建目录
2. 检查 `.vllm-deploy/config.json` 是否存在
   - 不存在 → 创建最小 config.json（只含 plog_config）
   - 存在 → 读取并检查 `plog_config` 字段
3. 检查 `plog_config` 是否完整（包含所有 4 个字段）
   - 不完整 → 补充缺失字段

## 交互问答流程

使用 AskUserQuestion 工具，逐个询问缺失的配置参数：

### Q1: plog 日志路径

```
昇腾 NPU 的 plog 日志在宿主机上的路径是什么？
常见路径：
- /usr/local/Ascend/driver/log（昇腾驱动默认）
- /var/log/ascend（某些安装方式）
- 自定义路径
```

默认值：`/usr/local/Ascend/driver/log`

### Q2: 日志类型选择

```
要分析哪些类型的 plog 日志？（多选）
- device: NPU 设备操作日志（包含 HCCL、超时、设备异常等）
- host: 宿主机驱动层日志（包含驱动错误、固件问题等）
- app: 应用层日志（包含 vLLM/CANN 相关错误）
```

默认值：全部三种（device、host、app）

### Q3: 时间范围

```
分析最近多久的日志？
- last_1h: 最近 1 小时（适合排查刚刚发生的错误）
- last_6h: 最近 6 小时（适合排查近期问题）
- last_24h: 最近 24 小时（默认，适合常规巡检）
- all: 全部日志（适合首次全面排查，注意日志量可能很大）
```

默认值：`last_24h`

### Q4: 日志级别

```
提取哪些级别的日志条目？（多选）
- ERROR: 错误级别（必选）
- WARNING: 警告级别（可能预示即将出错）
- CRITICAL: 严重错误（系统级故障）
```

默认值：全部三种（ERROR、WARNING、CRITICAL）

## 配置写入

将问答结果合并到 `.vllm-deploy/config.json`：

```bash
# 如果 config.json 不存在，创建新文件
if [ ! -f .vllm-deploy/config.json ]; then
    jq -n --arg path "$PLOG_PATH" \
        --argjson types "$PLOG_TYPES" \
        --arg range "$TIME_RANGE" \
        --argjson levels "$ERROR_LEVELS" \
        '{plog_config: {plog_path: $path, plog_types: $types, time_range: $range, error_levels: $levels}}' \
        > .vllm-deploy/config.json
else
    # 已有 config.json，追加或更新 plog_config
    jq --arg path "$PLOG_PATH" \
       --argjson types "$PLOG_TYPES" \
       --arg range "$TIME_RANGE" \
       --argjson levels "$ERROR_LEVELS" \
       '.plog_config = {plog_path: $path, plog_types: $types, time_range: $range, error_levels: $levels}' \
       .vllm-deploy/config.json > .vllm-deploy/config.json.tmp
    mv .vllm-deploy/config.json.tmp .vllm-deploy/config.json
fi
```

## 输出

`.vllm-deploy/config.json` 中包含完整的 `plog_config` 字段：

```json
{
  "plog_config": {
    "plog_path": "/usr/local/Ascend/driver/log",
    "plog_types": ["device", "host", "app"],
    "time_range": "last_24h",
    "error_levels": ["ERROR", "WARNING", "CRITICAL"]
  }
}
```

## AI 执行指南

1. 检查 `.vllm-deploy/config.json` 状态
2. 读取 `plog_config`（如有）
3. 对缺失参数逐个使用 AskUserQuestion 问答
4. 使用 jq 命令将配置写入 config.json
5. 确认配置完整后进入 Phase 2

## 错误处理

| 场景 | 处理 |
|------|------|
| .vllm-deploy/ 目录不存在 | 创建目录：`mkdir -p .vllm-deploy` |
| config.json 不存在 | 创建最小配置文件 |
| plog_config 字段缺失 | 逐个问答补充 |
| jq 不可用 | 提示安装 jq：`apt install jq` |