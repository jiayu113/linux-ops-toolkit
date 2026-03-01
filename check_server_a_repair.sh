#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/env.sh"

echo "[$(date)] 正在对 SERVER_A 执行状态维护..."

# MySQL 主库可写维护
IS_READONLY=$($SSH_CMD root@$SERVER_A "mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'show variables like \"read_only\";' -N -s" | awk '{print $2}')

if [ "$IS_READONLY" == "ON" ]; then
    echo "[警告] 主库被设置为只读模式，正在尝试恢复写入权限..."
    $SSH_CMD root@$SERVER_A "mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'set global read_only=0;'"
else
    echo "[正常] MySQL 主库处于可写模式。"
fi

# FreeSWITCH 运行状态维护
FS_STATUS=$($SSH_CMD root@$SERVER_A "fs_cli -x 'sofia status' | grep 'RUNNING'")
if[ -z "$FS_STATUS" ]; then
    echo "[警告] FreeSWITCH 状态异常，尝试重启服务..."
    $SSH_CMD root@$SERVER_A "systemctl restart freeswitch"
else
    echo "[正常] FreeSWITCH 运行正常。"
fi