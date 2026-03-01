#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/env.sh"

# 获取今天的日期 (格式: 2025-10-06)
TODAY=$(date +%Y-%m-%d)

mkdir -p $REC_DIR_LOCAL

echo "[$(date)] 开始从 SERVER_A 搬运录音 (排除今天: $TODAY)..."

rsync -avz --remove-source-files \
    -e "ssh -p $SSH_PORT" \
    --exclude="$TODAY" \
    root@$SERVER_A:$REC_DIR_A/ $REC_DIR_LOCAL/

if [ $? -eq 0 ]; then
    echo "[成功] 历史录音同步完成。"

    echo "正在清理 SERVER_A 上的空历史目录..."
    $SSH_CMD root@$SERVER_A "find $REC_DIR_A -type d -not -name '$TODAY' -not -path '$REC_DIR_A' -empty -delete"
else
    echo "[错误] 录音同步失败，请检查网络或 SSH 免密设置！"
fi