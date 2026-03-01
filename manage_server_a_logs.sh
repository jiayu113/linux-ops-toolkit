#!/bin/bash

# 引入环境配置
BASE_PATH=$(cd "$(dirname "$0")"; pwd)
source "$BASE_PATH/env.sh"

# --- 局部变量 ---
KEEP_DAYS=7
LOG_DIR_A="/usr/local/freeswitch/log"

echo ">>> [$(date)] 启动远程任务：清理 SERVER_A 的 FreeSWITCH 日志"

# 通过 SSH 发送“远程命令集”
$SSH_CMD root@$SERVER_A << EOF
    echo "--- 远程环境检查 ---"
    if[ ! -d "$LOG_DIR_A" ]; then
        echo "错误: 远程服务器目录 $LOG_DIR_A 不存在！"
        exit 1
    fi

    BEFORE=\$(du -sh $LOG_DIR_A | awk '{print \$1}')
    echo "清理前日志占用: \$BEFORE"

    # 压缩 1 天前且未压缩过的日志文件
    find $LOG_DIR_A -name "freeswitch.log.[0-9]*" ! -name "*.gz" -mtime +0 -exec gzip -v {} \;

    # 删除 7 天前的压缩包
    find $LOG_DIR_A -name "freeswitch.log.*.gz" -mtime +$KEEP_DAYS -delete

    AFTER=\$(du -sh $LOG_DIR_A | awk '{print \$1}')
    echo "清理后日志占用: \$AFTER"
    
    echo "当前系统磁盘状态: \$(df -h / | awk 'NR==2 {print \$5}') 使用率"
EOF

# 检查 SSH 执行结果
if [ $? -eq 0 ]; then
    echo ">>> [$(date)] SERVER_A 日志处理成功。"
else
    echo ">>> [$(date)] 警告：远程脚本执行过程中可能出错。"
fi