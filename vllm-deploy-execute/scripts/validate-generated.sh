#!/bin/bash
set -euo pipefail

CONFIG_FILE="${1:-.vllm-deploy/config.json}"
K8S_DIR="${2:-.vllm-deploy/k8s}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found at $CONFIG_FILE" >&2
    exit 1
fi

if [ ! -d "$K8S_DIR" ]; then
    echo "Error: k8s output directory not found at $K8S_DIR" >&2
    exit 1
fi

DEPLOY_MODE=$(jq -r '.deploy_mode' "$CONFIG_FILE")
MODEL_NAME=$(jq -r '.selected_model' "$CONFIG_FILE")

slugify_model_name() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
        | cut -c1-63 \
        | sed -E 's/-+$//'
}

RESOURCE_NAME=$(slugify_model_name "$MODEL_NAME")

if [ -z "$RESOURCE_NAME" ]; then
    echo "Error: selected_model '$MODEL_NAME' cannot be converted to a Kubernetes resource name" >&2
    exit 1
fi

if [ ! -f "$K8S_DIR/all.yaml" ]; then
    echo "Error: missing $K8S_DIR/all.yaml" >&2
    exit 1
fi

if rg -n '\$\{[A-Z0-9_]+\}' "$K8S_DIR" >/tmp/vllm-unresolved-vars.txt; then
    echo "Error: generated artifacts contain unresolved template variables:" >&2
    cat /tmp/vllm-unresolved-vars.txt >&2
    exit 1
fi

if rg -n 'name: .*[^a-z0-9.-]' "$K8S_DIR/all.yaml" >/tmp/vllm-name-lines.txt; then
    while IFS= read -r line; do
        name_value=$(printf '%s' "$line" | sed -E 's/^.*name:[[:space:]]*"?([^"#]+)"?.*$/\1/')
        if ! printf '%s' "$name_value" | grep -Eq '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$'; then
            echo "Error: generated Kubernetes name is not DNS-safe: $name_value" >&2
            exit 1
        fi
    done </tmp/vllm-name-lines.txt
fi

if ! rg -n "model: ${RESOURCE_NAME}" "$K8S_DIR/all.yaml" >/dev/null; then
    echo "Error: all.yaml does not contain normalized model label: $RESOURCE_NAME" >&2
    exit 1
fi

case "$DEPLOY_MODE" in
    single_node|multi_node)
        if [ ! -f "$K8S_DIR/deploy.sh" ]; then
            echo "Error: $DEPLOY_MODE requires generated deploy.sh after Phase 9" >&2
            exit 1
        fi
        ;;
    pd_separate|ha_active_standby)
        if [ -f "$K8S_DIR/deploy.sh" ]; then
            echo "Error: $DEPLOY_MODE should not generate deploy.sh" >&2
            exit 1
        fi
        ;;
    *)
        echo "Error: unknown deploy_mode '$DEPLOY_MODE'" >&2
        exit 1
        ;;
esac

echo "validated generated artifacts for $DEPLOY_MODE ($RESOURCE_NAME)"