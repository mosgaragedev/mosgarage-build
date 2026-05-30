#!/bin/bash
set -e

# ===== CONFIGURATION =====
SSH_USER="dev"
SSH_HOST="mosgarage.xyz"
SSH_PORT=22
REMOTE_PATH="/remote/data/path"
LOCAL_MOUNT="/workspace/ssh"

# ===== SCRIPT =====
echo "[INFO] Creating local mount point at $LOCAL_MOUNT..."
mkdir -p "$LOCAL_MOUNT"

echo "[INFO] Mounting $SSH_USER@$SSH_HOST:$REMOTE_PATH to $LOCAL_MOUNT..."
sshfs -o allow_other,default_permissions,port=$SSH_PORT \
    "$SSH_USER@$SSH_HOST:$REMOTE_PATH" "$LOCAL_MOUNT"

echo "[INFO] SSHFS mount complete."