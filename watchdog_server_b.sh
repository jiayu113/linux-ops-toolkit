#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/env.sh"

echo "[$(date)] 开始巡检 SERVER_B..."

# Java 检查
PID=$($SSH_CMD root@$SERVER_B "pgrep -f $JAR_NAME")
if [ -z "$PID" ]; then
    echo "[警告] Java 离线，正在启动..."
    $SSH_CMD root@$SERVER_B "cd $JAVA_DIR && ./start.sh"
else
    echo "[正常] Java 运行中 (PID: $PID)"
fi

# EMQX 检查
$SSH_CMD root@$SERVER_B "emqx ctl status > /dev/null 2>&1"
if[ $? -ne 0 ]; then
    echo "[警告] EMQX 状态检查失败，尝试拉起服务..."
    $SSH_CMD root@$SERVER_B "emqx start"
else
    echo "[正常] EMQX 运行正常。"
fi