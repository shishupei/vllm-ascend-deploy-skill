# Phase 7: 生成模板文件

## 目标

复制模板文件到输出目录，保持占位符不变（Skill 2 将填充）。

## 输入

- config.json
- templates/ 目录下的模板文件

## 输出目录

```
.vllm-deploy/
├── config.json
├── image-info.json
└── templates/
    ├── k8s-namespace.yaml
    ├── k8s-configmap.yaml
    ├── k8s-deployment.yaml.template
    ├── k8s-service.yaml
    ├── deploy.sh.template
    └── apply-all.sh.template
```

## AI 执行指南

1. 创建 `.vllm-deploy/templates/` 目录
2. 复制 skill-prepare/templates/ 下所有文件到输出目录
3. 告知用户模板已生成
4. 提示用户运行 `/vllm-deploy-execute` 在 K8s 管理节点继续

## 完成提示

```
准备阶段完成！输出文件已生成到 .vllm-deploy/

下一步：
1. 将 .vllm-deploy/ 目录复制到 K8s 管理节点
2. 运行 /vllm-deploy-execute 继续部署
```