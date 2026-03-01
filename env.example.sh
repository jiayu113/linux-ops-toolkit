#!/bin/bash
# env.example.sh (在实际使用时请复制并重命名为 env.sh)

# --- 服务器基础信息 ---
export SERVER_A="<YOUR_SERVER_A_IP>"  # 例如音视频通讯服务器
export SERVER_B="<YOUR_SERVER_B_IP>"  # 例如业务服务服务器
export SSH_PORT="22"                  # 替换为真实的 SSH 端口

# Server_A 录音源路径
export REC_DIR_A="/usr/local/freeswitch/recordings"

# 本地服务器存储路径
export REC_DIR_LOCAL="/data/fs_recordings_archive"

# --- 数据库信息 ---
export MYSQL_USER="<YOUR_DB_USER>"
export MYSQL_PASS="<YOUR_DB_PASSWORD>"

# --- 业务路径 ---
export JAVA_DIR="/opt/web"
export JAR_NAME="app-0.0.1-SNAPSHOT.jar"

# 定义一个通用的 SSH 基础命令，后续脚本直接调用
export SSH_CMD="ssh -p $SSH_PORT -o BatchMode=yes -o ConnectTimeout=10"