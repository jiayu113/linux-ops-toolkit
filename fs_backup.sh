#!/bin/bash
set -e

# ================= 基础配置 =================
FS_BASE="/usr/local/freeswitch"
BACKUP_DIR="/data/freeswitch_backups"
DATE_STR=$(date +%Y%m%d_%H%M%S)

BACKUP_NAME="freeswitch_runtime_${DATE_STR}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

LOG_FILE="${BACKUP_DIR}/backup.log"
RETENTION_DAYS=30
# ============================================

mkdir -p "$BACKUP_DIR"

log() {
  echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

log "开始 FreeSWITCH 可恢复级备份"

# ================= 核心备份 =================
# 可恢复最小集合：
# conf + scripts + db + certs
tar -czPf "$BACKUP_PATH" \
  --exclude="${FS_BASE}/log/*" \
  --exclude="${FS_BASE}/run/*" \
  --exclude="${FS_BASE}/tmp/*" \
  --exclude="${FS_BASE}/recordings/*" \
  --exclude="${FS_BASE}/storage/*" \
  "${FS_BASE}/conf" \
  "${FS_BASE}/scripts" \
  "${FS_BASE}/db" \
  "${FS_BASE}/certs" \
  >> "$LOG_FILE" 2>&1

log "核心运行数据打包完成: $BACKUP_PATH"

# ================= 备份完整性校验 =================
REQUIRED_ITEMS=(
  "conf/dialplan"
  "conf/sip_profiles"
  "scripts"
  "db/sofia_reg_internal.db"
  "db/core.db"
)

for item in "${REQUIRED_ITEMS[@]}"; do
  if ! tar -tf "$BACKUP_PATH" | grep -q "$item"; then
    log "❌ 备份校验失败，缺失关键项: $item"
    exit 1
  fi
done

log "备份完整性校验通过"

# ================= 备份文件信息 =================
FILE_SIZE=$(du -h "$BACKUP_PATH" | awk '{print $1}')
log "备份文件大小: $FILE_SIZE"

# ================= 清理旧备份 =================
log "清理超过 ${RETENTION_DAYS} 天的旧备份"
find "$BACKUP_DIR" \
  -type f \
  -name "freeswitch_runtime_*.tar.gz" \
  -mtime +${RETENTION_DAYS} \
  -exec rm -f {} \; \
  >> "$LOG_FILE" 2>&1

log "备份流程完成"
log "----------------------------------------"

