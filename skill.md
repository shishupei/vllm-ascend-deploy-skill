# vLLM-Deploy Skill

该文档是 `SKILL.md` 的兼容入口，供依赖 README 目录约定的环境使用。

## 使用时机

当用户需要基于 vLLM-Ascend 教程页面，在 Kubernetes 集群上完成模型部署准备、镜像处理、YAML 生成和 Pod 内部署脚本生成时，使用该 skill。

## 执行环境

- Kubernetes 管理节点
- 已安装并配置 `kubectl`
- 能够访问 Docker 或兼容镜像工具

## Phase 流程

1. Phase 1 使用 `modules/model-list-fetcher.md`
2. Phase 2 使用 `modules/user-selector.md`
3. Phase 3 使用 `modules/doc-parser.md`
4. Phase 4 使用 `modules/k8s-env-detector.md`
5. Phase 5 使用 `modules/image-handler.md`
6. Phase 6 使用 `modules/config-guide.md`
7. Phase 7 使用 `modules/k8s-yaml-generator.md`
8. Phase 8 使用 `modules/k8s-apply-guide.md`
9. Phase 9 使用 `modules/container-env-detector.md`
10. Phase 10 使用 `modules/deploy-generator.md`
11. Phase 11 使用 `modules/deploy-execution-guide.md`
12. Phase 12 使用 `modules/output-guide.md`

## 关联模板

- `templates/k8s-namespace.yaml`
- `templates/k8s-configmap.yaml`
- `templates/k8s-deployment.yaml`
- `templates/k8s-service.yaml`
- `templates/deploy.sh`
- `templates/apply-all.sh`