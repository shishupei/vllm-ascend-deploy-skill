# Phase 6: 配置参数

## 目的
通过交互式问答收集部署所需的关键配置参数，包括命名空间、模型路径、性能参数和 PD 分离配置（如适用）。

## 输入
- Phase 2-5 结果（模型选择、硬件规格、部署模式、镜像信息）
- Phase 3 脚本模板

## 执行位置
- 交互式问答（管理节点或本地终端）

## 步骤
1. **Q1：Namespace 名称**
   - 提示输入 K8s 命名空间名称
   - 默认建议：`vllm-deploy`
   - 输出参数：`namespace`

2. **Q2：模型路径**
   - 提示输入模型在宿主机上的路径
   - 示例：`/data/models/GLM-5`
   - 输出参数：`model_path`

3. **Q3：性能参数确认**
   - 展示从文档解析的默认参数（`max-model-len`、`max-num-seqs` 等）
   - 询问是否修改，如修改则更新参数
   - 输出参数：`max_model_len`、`max_num_seqs`

4. **Q4：PD 分离配置**（仅当部署模式为 PD 分离时）
   - 询问 Prefill 节点数量和 Decode 节点数量
   - 输出参数：`prefill_nodes`、`decode_nodes`

5. 汇总并确认所有配置参数

## 输出
```json
{
  "namespace": "vllm-deploy",
  "model_path": "/data/models/GLM-5",
  "max_model_len": 8192,
  "max_num_seqs": 256,
  "prefill_nodes": null,
  "decode_nodes": null,
  "deploy_mode": "multi_node",
  "hw_spec": "A3",
  "target_image": "harbor.example.com/library/vllm-ascend:v0.6.0"
}
```

## 失败处理
| 场景 | 处理方式 |
|-----|---------|
| Namespace 名称格式错误 | 提示 K8s 命名空间命名规范（小写字母、数字、连字符） |
| 模型路径不存在 | 警告用户，但不阻止流程（可能在节点上验证时失败） |
| 性能参数格式错误 | 提示参数应为正整数，要求重新输入 |
| PD 分离节点数量配置不合理 | 警告用户，建议 Prefill 和 Decode 节点数量匹配 |

## 关联资源
- 脚本：无
- 模板：`templates/k8s-configmap.yaml`
- 下一阶段：`modules/k8s-yaml-generator.md`