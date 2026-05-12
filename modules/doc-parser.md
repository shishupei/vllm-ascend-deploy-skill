# 文档解析模块

## 输入

**默认 URL：**
`https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html`

用户可指定具体模型教程 URL，如：
`https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/GLM5.html`

## 处理步骤

### 1. 抓取文档 HTML

使用 curl 命令获取页面内容：

```bash
# 默认获取模型列表页
DEFAULT_URL="https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/index.html"

# 或用户指定的 URL
curl -sL "$DEFAULT_URL" > /tmp/vllm-doc.html
```

### 2. 提取模型列表（从 index.html）

从模型列表页提取所有模型教程链接：

```bash
# 提取模型名称和链接
grep -oP 'href="[^"]*\.html".*?>[^<]*</a>' /tmp/vllm-doc.html | \
  sed 's/href="//g' | \
  sed 's/">/:/g' | \
  awk -F: '{print $1, $2}'
```

输出示例：
```
GLM5.html GLM-5
Qwen2.5-7B.html Qwen2.5-7B
DeepSeek-V3.1.html DeepSeek-V3/3.1
```

### 3. 抓取具体模型页面并提取脚本块

用户选择模型后，抓取对应页面并提取脚本：

```bash
curl -sL "https://docs.vllm.com.cn/projects/ascend/en/latest/tutorials/models/<模型>.html" > /tmp/model-doc.html
```

文档使用 `<div class="highlight-bash">` 标签包裹脚本。按 Tab 标签区分硬件规格：

- Tab `A3` → 提取 A3 系列脚本（16 卡）
- Tab `A2` → 提取 A2 系列脚本（8 卡）

提取命令：

```bash
# 提取所有 bash 脚本块
grep -A 200 'class="highlight-bash"' /tmp/model-doc.html | \
  sed 's/<[^>]*>//g' | \
  sed 's/&nbsp;/ /g' | \
  sed 's/&lt;/</g' | \
  sed 's/&gt;/>/g' > /tmp/scripts-raw.txt
```

### 4. 分类脚本

识别脚本类型：

| 脚本类型 | 识别特征 |
|---------|---------|
| Docker 启动 | 包含 `docker run` |
| 单节点部署 | 包含 `vllm serve`，无 `--headless` |
| 多节点部署 | 包含 `vllm serve` + `--headless` 或 `--data-parallel-start-rank` |
| PD分离 | 页面标题包含 "Prefill-Decode" 或章节标题包含 "分离" |

### 5. 提取参数模板

从脚本中提取需要替换的参数：

| 参数 | 来源 |
|------|------|
| `$IMAGE` | Docker 镜像版本 |
| `/dev/davinci[0-N]` | NPU 设备列表 |
| `local_ip` | 需自动探测 |
| `nic_name` | 需自动探测 |
| 模型路径 | 需用户输入 |
| `--tensor-parallel-size` | 根据 NPU 数量计算 |
| `--max-model-len` | 需用户确认 |

## 输出

返回结构化的脚本模板：

```json
{
  "docker_run": {
    "a3": "<A3 Docker 启动脚本>",
    "a2": "<A2 Docker 启动脚本>"
  },
  "deploy": {
    "single_node": "<单节点 vllm serve 脚本>",
    "multi_node": {
      "node0": "<节点0 脚本>",
      "node1": "<节点1 脚本>"
    },
    "pd_disagg": {
      "prefill": "<Prefill 节点脚本>",
      "decode": "<Decode 节点脚本>"
    }
  },
  "params": {
    "auto_detect": ["local_ip", "nic_name", "npu_count"],
    "user_input": ["model_path", "max_model_len"]
  }
}
```

## 错误处理

- URL 无法访问 → 提示用户检查 URL 或网络
- 脚本块未找到 → 提示文档可能不包含部署脚本
- 脚本结构异常 → 提示用户手动提供脚本