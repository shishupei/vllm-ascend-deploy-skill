---
name: vllm-deploy
description: Use when deploying vLLM-Ascend models on Kubernetes and you need to fetch model docs, inspect the cluster, prepare images, generate K8s manifests, and produce an in-pod deployment script
---

# vLLM-Deploy

## Overview

Use this skill on a Kubernetes management node when the goal is to turn a vLLM-Ascend model tutorial into a runnable K8s deployment package. The skill follows the README-defined 12-phase flow and keeps explicit user confirmation points for manifest apply and final in-pod execution.

## Environment

- Requires `kubectl` access to the target cluster
- Requires Docker access for image pull, retag, and push
- Assumes the operator can run commands on a K8s management node

## Workflow

1. Phase 1: Read [modules/model-list-fetcher.md](modules/model-list-fetcher.md) and use `scripts/fetch-model-list.sh`
2. Phase 2: Read [modules/user-selector.md](modules/user-selector.md)
3. Phase 3: Read [modules/doc-parser.md](modules/doc-parser.md) and use `scripts/parse-model-doc.sh`
4. Phase 4: Read [modules/k8s-env-detector.md](modules/k8s-env-detector.md) and use `scripts/detect-k8s-env.sh`
5. Phase 5: Read [modules/image-handler.md](modules/image-handler.md) and use `scripts/push-image.sh`
6. Phase 6: Read [modules/config-guide.md](modules/config-guide.md)
7. Phase 7: Read [modules/k8s-yaml-generator.md](modules/k8s-yaml-generator.md) and fill `templates/k8s-namespace.yaml`, `templates/k8s-configmap.yaml`, `templates/k8s-deployment.yaml`, `templates/k8s-service.yaml`, and `templates/apply-all.sh`
8. Phase 8: Read [modules/k8s-apply-guide.md](modules/k8s-apply-guide.md)
9. Phase 9: Read [modules/container-env-detector.md](modules/container-env-detector.md) and use `scripts/detect-container-npu.sh`
10. Phase 10: Read [modules/deploy-generator.md](modules/deploy-generator.md) and fill `templates/deploy.sh`
11. Phase 11: Read [modules/deploy-execution-guide.md](modules/deploy-execution-guide.md)
12. Phase 12: Read [modules/output-guide.md](modules/output-guide.md)

## Output

The final delivery should be a `.vllm-deploy/k8s/` directory containing:

- `README.md`
- `namespace.yaml`
- `configmap.yaml`
- `deployment-node1.yaml`
- `deployment-node2.yaml`
- `service.yaml`
- `apply-all.sh`
- `deploy.sh`