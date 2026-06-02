# 昇腾 NPU 错误模式对照表

供 `filter-errors.sh`（正则预筛）和 AI 代理（深度诊断）共同参考。

## 1. HCCL 通信错误

### 正则模式
```
HCCL.*(?:timeout|error|fail|abort)
HCCS.*(?:timeout|error|fail)
rank.*(?:timeout|disconnect|fail)
```

### 关键词
HCCL, HCCS, rank_id, collective, allreduce, broadcast

### 常见根因
1. 网络拓扑配置错误（rank 映射不一致或 hccn.conf 配置不当）
2. NPU 间 RDMA/RoCE 链路异常（光模块故障、网线松动）
3. 集合通信算子参数不匹配（tensor_parallel_size 与实际 NPU 数不符）
4. 防火墙或网络策略阻断 NPU 间通信端口

### 诊断步骤
1. `npu-smi info -t board` — 检查 NPU 卡状态
2. `cat /etc/hccn.conf` — 检查网络拓扑配置是否一致
3. `hccl_test -p 8` — 运行 HCCL 通信测试
4. `ip addr show` — 检查 RDMA 网卡状态
5. 检查集群所有节点的 hccn.conf 是否一致

### 修复建议
1. 核对所有节点的 `/etc/hccn.conf`，确保 rank_id 映射一致
2. 重启异常 NPU 卡：`npu-smi set -t reset -i <device_id>`
3. 检查物理链路：光模块插紧、网线完好、RDMA 网卡 UP
4. 确认 `tensor_parallel_size` 与实际可用 NPU 数量匹配
5. 如有防火墙，开放 HCCL 通信端口（默认 29500）

### 关联模式
- 设备超时（HCCL 超时常导致后续任务超时）
- 设备异常（NPU 硬件故障可表现为通信错误）
- 资源不足（NPU 资源不足导致 rank 分配失败）

---

## 2. 设备超时错误

### 正则模式
```
(?:TS|task|execute|kernel|op).*timeout
timeout.*(?:davinci|npu|device|execute)
```

### 关键词
timeout, TS timeout, task timeout, execute timeout, stall

### 常见根因
1. NPU 计算任务卡死（模型计算量超出 NPU 处理能力）
2. HCCL 通信等待超时（上游通信错误传导）
3. NPU 驱动固件版本过旧（已知 bug 导致任务卡死）
4. 内存不足导致任务无法分配所需 buffer

### 诊断步骤
1. `npu-smi info -t usages -i <device_id>` — 检查 NPU 使用率和内存
2. `dmesg | grep -i davinci` — 检查内核日志中的设备错误
3. 检查 vLLM 启动参数：`max_model_len`、`max_num_seqs` 是否过大
4. `npu-smi info -t board -i <device_id>` — 检查固件版本

### 修复建议
1. 降低模型参数：减小 `max_model_len` 或 `max_num_seqs`
2. 更新昇腾驱动和固件到最新稳定版本
3. 检查是否存在 HCCL 通信错误（先解决通信问题）
4. 重启异常 NPU 卡后重试
5. 增加 `--gpu-memory-utilization` 参数（默认 0.9）降低内存压力

### 关联模式
- HCCL 通信（通信超时是设备超时的常见上游原因）
- 内存溢出（OOM 后续任务可能超时）
- 设备异常（硬件故障导致任务卡死）

---

## 3. 内存溢出错误

### 正则模式
```
(?:OOM|out of memory|memory alloc(?:ation)? failed|memory exceed|CANN.*memory)
```

### 关键词
OOM, out of memory, memory allocation failed, memory exceed, buffer alloc

### 常见根因
1. 模型参数过大超出 NPU HBM 容量（如 max_model_len 设置过高）
2. KV Cache 占用过多（batch size 过大或序列过长）
3. tensor_parallel_size 不足导致单卡内存压力大
4. CANN 算子内部 buffer 分配失败

### 诊断步骤
1. `npu-smi info -t usages -i <device_id>` — 查看 NPU HBM 使用率
2. 检查 vLLM 启动参数中的 `max_model_len` 和 `max_num_seqs`
3. `free -h` — 检查主机内存是否充足
4. 检查模型实际参数量和 KV Cache 计算需求

### 修复建议
1. 降低 `max_model_len`（如从 8192 降到 4096）
2. 降低 `max_num_seqs`（如从 256 降到 128）
3. 增加 `tensor_parallel_size` 分摊内存压力
4. 使用 `--gpu-memory-utilization 0.9`（默认值）或适当降低
5. 检查是否有多余进程占用 NPU 内存

### 关联模式
- 设备超时（OOM 后续任务可能超时）
- 资源不足（NPU 内存资源耗尽）

---

## 4. 设备异常错误

### 正则模式
```
(?:device|dev\d+|davinci\d+).*(?:error|fault|fail|abnormal|reset)
(?:NPU|npu).*(?:error|fault|fail|abnormal|offline)
```

### 关键词
device error, davinci error, NPU error, device fault, device offline, reset

### 常见根因
1. NPU 硬件故障（芯片损坏、PCIE 链路异常）
2. 驱动与固件不兼容（版本 mismatch）
3. 过热保护触发（散热不足导致设备自动 offline）
4. 电源不稳定导致设备异常重启

### 诊断步骤
1. `npu-smi info -t board -i <device_id>` — 检查设备健康状态
2. `npu-smi info -t common -i <device_id>` — 检查设备是否在线
3. `dmesg | grep -i davinci` — 检查内核层面的设备错误
4. 检查服务器温度和散热状态
5. `lspci | grep -i ascend` — 检查 PCIE 设备是否可见

### 修复建议
1. 重启异常设备：`npu-smi set -t reset -i <device_id>`
2. 重启宿主机尝试恢复 PCIE 链路
3. 更新驱动固件到兼容版本
4. 检查散热系统：风扇转速、环境温度
5. 如反复异常，联系硬件供应商更换 NPU 卡

### 关联模式
- HCCL 通信（设备故障可表现为通信错误）
- 驱动错误（驱动异常导致设备不可用）
- 设备超时（设备异常导致任务卡死超时）

---

## 5. 驱动错误

### 正则模式
```
(?:driver|drv).*(?:error|fail|crash|version mismatch|incompatible)
(?:firmware|fw).*(?:error|fail|version mismatch|upgrade)
CANN.*(?:error|fail|init failed)
```

### 关键词
driver error, drv error, firmware, fw, CANN init failed, version mismatch

### 常见根因
1. 驱动版本与固件版本不匹配（升级不完整）
2. CANN 软件栈初始化失败（环境变量或依赖缺失）
3. 驯动模块未正确加载（`ko` 文件缺失或冲突）
4. 多版本 CANN 共存导致环境冲突

### 诊断步骤
1. `npu-smi info -t board` — 检查驱动和固件版本
2. `cat /usr/local/Ascend/driver/version.info` — 检查驱动版本
3. `cat /usr/local/Ascend/ascend-toolkit/version.info` — 检查 CANN 版本
4. `lsmod | grep -i davinci` — 检查驱动模块是否加载
5. 检查环境变量：`ASCEND_HOME_PATH`、`LD_LIBRARY_PATH`

### 修复建议
1. 确保驱动、固件、CANN 版本三件套一致（参考昇腾兼容性矩阵）
2. 清理多版本残留：只保留一套 CANN + driver
3. 重新加载驱动模块：`rmmod davinci; modprobe davinci`
4. 设置正确环境变量（参考 vLLM-Ascend 文档）
5. 重启宿主机使驱动变更生效

### 关联模式
- 设备异常（驱动问题导致设备不可用）
- 设备超时（驱动 bug 导致任务超时）

---

## 6. 资源不足错误

### 正则模式
```
(?:resource|device).*(?:exhausted|not available|unavailable|busy|occupied)
(?:no available|cannot find).*(?:device|npu|davinci)
```

### 关键词
resource exhausted, no available device, device busy, device occupied

### 常见根因
1. 其他进程占用 NPU 资源（残留训练/推理进程）
2. Device Plugin 配置不当导致资源注册异常
3. NPU 资源分配策略不合理（请求量超过节点实际可用量）
4. 容器资源限制与 NPU 数量不匹配

### 诊断步骤
1. `npu-smi info` — 查看所有 NPU 状态和使用情况
2. `fuser /dev/davinci*` — 检查哪些进程占用 NPU 设备
3. `kubectl describe node <name>` — 检查 NPU 资源注册情况
4. `ps aux | grep -i vllm` — 检查残留 vLLM 进程

### 修复建议
1. 杀掉占用 NPU 的残留进程：`kill -9 <pid>`
2. 检查 Device Plugin 日志确保资源正确注册
3. 调整 Deployment 中的 NPU 资源请求量
4. 确保 Pod 的 NPU limit/request 与实际需要匹配
5. 重启 Device Plugin：`kubectl rollout restart daemonset ascend-device-plugin`

### 关联模式
- 内存溢出（NPU 资源耗尽后内存也溢出）
- HCCL 通信（资源不足导致 rank 分配失败）

---

## 7. 数据对齐错误

### 正则模式
```
(?:alignment|shape|dtype|type).*(?:error|mismatch|not match|incompatible)
(?:tensor|data).*(?:cast|convert|transform).*(?:error|fail)
```

### 关键词
alignment error, shape mismatch, dtype mismatch, type error, cast error

### 常见根因
1. 模型权重数据类型与 NPU 算子不兼容（如 float64 不支持）
2. KV Cache 数据格式不匹配（Prefill 与 Decode 间格式不一致）
3. 模型配置中的 `dtype` 与实际权重 dtype 不符
4. 昇腾 CANN 算子对某些数据类型有限制

### 诊断步骤
1. 检查模型权重 dtype：`python -c "import torch; print(torch.load('model.bin').dtype)"`
2. 检查 vLLM 启动参数中的 `--dtype` 设置
3. 查看 CANN 版本支持的数据类型列表
4. 检查模型 config.json 中的 `torch_dtype` 字段

### 修复建议
1. 确保 `--dtype float16` 或 `--dtype bfloat16`（昇腾推荐 bfloat16）
2. 如使用 PD 分离，确保 Prefill 和 Decode 使用相同的 dtype
3. 更新 CANN 版本以支持更多数据类型
4. 模型转换：将不兼容的 dtype 权重转为支持的 dtype

### 关联模式
- 内存溢出（dtype 不匹配可能导致额外内存分配）
- 设备超时（数据转换耗时可能超时）

---

## 严重等级映射

| 类别 | 默认严重等级 | 触发条件 |
|------|-------------|---------|
| HCCL 通信 | high | 任何 HCCL 错误出现 |
| 设备超时 | high | 超时次数 > 5 |
| 内存溢出 | critical | 任何 OOM 出现 |
| 设备异常 | critical | 设备 offline 或 fault |
| 驕腾错误 | high | 驕动初始化失败 |
| 资源不足 | medium | 资源不可用 |
| 数据对齐 | medium | dtype/shape 不匹配 |

> 低频出现（< 3 次）的设备超时降级为 medium，高频 HCCL 错误升级为 critical。