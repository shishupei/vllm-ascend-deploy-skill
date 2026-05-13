#!/bin/bash

# SSH 远程执行镜像拉取、打标签、推送
# 输出格式：JSON

SOURCE_IMAGE="$1"
TARGET_REGISTRY="$2"
REMOTE_NODE_IP="$3"
SSH_USER="$4"           # SSH 登录用户名
DOCKER_USERNAME="$5"    # Docker 仓库用户名
DOCKER_PASSWORD="$6"    # Docker 仓库密码

if [ -z "$SOURCE_IMAGE" ] || [ -z "$TARGET_REGISTRY" ] || [ -z "$REMOTE_NODE_IP" ]; then
    echo '{"error": "SOURCE_IMAGE, TARGET_REGISTRY, and REMOTE_NODE_IP are required"}'
    exit 1
fi

# 提取镜像名称和版本
IMAGE_NAME=$(basename "$SOURCE_IMAGE")
TARGET_IMAGE="${TARGET_REGISTRY}/${IMAGE_NAME}"

# 检查 SSH 是否可用
if ! command -v ssh &> /dev/null; then
    echo '{"error": "ssh not available"}'
    exit 1
fi

# 构建 SSH 命令（支持指定用户）
if [ -n "$SSH_USER" ]; then
    SSH_CMD="ssh ${SSH_USER}@${REMOTE_NODE_IP}"
else
    SSH_CMD="ssh ${REMOTE_NODE_IP}"
fi

# 1. 登录镜像仓库（使用 --password-stdin，用户名通过环境变量避免命令行暴露）
if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
    LOGIN_RESULT=$($SSH_CMD "echo '${DOCKER_PASSWORD}' | docker login -u '${DOCKER_USERNAME}' --password-stdin ${TARGET_REGISTRY}" 2>&1) || {
        echo '{"error": "Docker login failed", "login_output": "'"${LOGIN_RESULT}"'"}'
        exit 1
    }
fi

# 2. 拉取官方镜像
PULL_RESULT=$($SSH_CMD "docker pull $SOURCE_IMAGE" 2>&1) || {
    echo '{"error": "Docker pull failed", "pull_output": "'"${PULL_RESULT}"'"}'
    exit 1
}

# 3. 打标签
TAG_RESULT=$($SSH_CMD "docker tag $SOURCE_IMAGE $TARGET_IMAGE" 2>&1) || {
    echo '{"error": "Docker tag failed", "tag_output": "'"${TAG_RESULT}"'"}'
    exit 1
}

# 4. 推送镜像
PUSH_RESULT=$($SSH_CMD "docker push $TARGET_IMAGE" 2>&1) || {
    echo '{"error": "Docker push failed", "push_output": "'"${PUSH_RESULT}"'"}'
    exit 1
}

# 输出成功结果
echo '{'
echo '"source_image": "'"$SOURCE_IMAGE"'",'
echo '"target_image": "'"$TARGET_IMAGE"'",'
echo '"push_success": true'
echo '}'