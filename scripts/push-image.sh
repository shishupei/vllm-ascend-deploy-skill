#!/bin/bash

# SSH 远程执行镜像拉取、打标签、推送
# 输出格式：JSON

set -e

SOURCE_IMAGE="$1"
TARGET_REGISTRY="$2"
REMOTE_NODE_IP="$3"
USERNAME="$4"
PASSWORD="$5"

if [ -z "$SOURCE_IMAGE" ] || [ -z "$TARGET_REGISTRY" ] || [ -z "$REMOTE_NODE_IP" ]; then
    echo '{"error": "SOURCE_IMAGE, TARGET_REGISTRY, and REMOTE_NODE_IP are required"}'
    exit 1
fi

# 提取镜像名称和版本
IMAGE_NAME=$(echo "$SOURCE_IMAGE" | sed 's/.*\//''')
TARGET_IMAGE="${TARGET_REGISTRY}/${IMAGE_NAME}"

# 检查 SSH 是否可用
if ! command -v ssh &> /dev/null; then
    echo '{"error": "ssh not available"}'
    exit 1
fi

# 远程执行镜像处理
SSH_CMD="ssh $REMOTE_NODE_IP"

# 1. 登录镜像仓库
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    LOGIN_RESULT=$($SSH_CMD "docker login -u $USERNAME -p $PASSWORD $TARGET_REGISTRY" 2>&1)
    if [ $? -ne 0 ]; then
        echo '{"error": "Docker login failed", "login_output": "' "$LOGIN_RESULT" '"}'
        exit 1
    fi
fi

# 2. 拉取官方镜像
PULL_RESULT=$($SSH_CMD "docker pull $SOURCE_IMAGE" 2>&1)
if [ $? -ne 0 ]; then
    echo '{"error": "Docker pull failed", "pull_output": "' "$PULL_RESULT" '"}'
    exit 1
fi

# 3. 打标签
TAG_RESULT=$($SSH_CMD "docker tag $SOURCE_IMAGE $TARGET_IMAGE" 2>&1)
if [ $? -ne 0 ]; then
    echo '{"error": "Docker tag failed", "tag_output": "' "$TAG_RESULT" '"}'
    exit 1
fi

# 4. 推送镜像
PUSH_RESULT=$($SSH_CMD "docker push $TARGET_IMAGE" 2>&1)
if [ $? -ne 0 ]; then
    echo '{"error": "Docker push failed", "push_output": "' "$PUSH_RESULT" '"}'
    exit 1
fi

# 输出成功结果
echo '{'
echo '"source_image": "' "$SOURCE_IMAGE" '",'
echo '"target_image": "' "$TARGET_IMAGE" '",'
echo '"push_success": true'
echo '}'