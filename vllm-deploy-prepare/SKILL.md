---
name: vllm-deploy-prepare
description: vLLM-Ascend 部署准备 - 获取模型列表、解析文档、处理镜像、生成配置
---

vLLM-Ascend 部署准备阶段，在任意有网络的环境执行。

## 触发方式

- `/vllm-deploy-prepare`
- `vllm 部署准备`

## 执行流程

按顺序读取以下模块并执行：

1. **Phase 1**: `modules/model-list-fetcher.md` - 获取模型列表
2. **Phase 2**: `modules/user-selector.md` - 用户选择
3. **Phase 3**: `modules/doc-parser.md` - 文档解析
4. **Phase 5**: `modules/image-handler.md` - 镜像处理
5. **Phase 6**: `modules/config-guide.md` - 交互配置
6. **Phase 7**: `modules/template-generator.md` - 生成模板
7. **Phase 7.5**: `modules/deploy-script-generator.md` - 生成启动脚本

## 输出

生成 `.vllm-deploy/` 目录，包含：
- `config.json` - 用户配置汇总
- `image-info.json` - 镜像信息
- `templates/` - K8s 模板文件
- `scripts/` - vLLM 启动脚本

## 下一步

完成后运行 `/vllm-deploy-execute` 在 K8s 管理节点执行部署。