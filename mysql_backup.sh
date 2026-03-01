#!/bin/bash

# --- 配置区域 ---

# 备份存储根目录
BACKUP_ROOT="/data/mysql_backups"

# 脚本运行日志
SCRIPT_LOG="/var/log/mysql_ops_manager.log"

# MySQL 自身的错误日志 
MYSQL_ERROR_LOG="/var/log/mysql/error.log"

# MySQL 服务名称
SERVICE_NAME="mysql"

# 备份保留天数
RETENTION_DAYS=30

# 是否是主从架构的从库 (true/false)
IS_SLAVE=false

# --- 基础工具函数 ---

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SCRIPT_LOG"
}

alert() {
    echo "[ALERT] ⚠️ $1" | tee -a "$SCRIPT_LOG"
}

# --- 环境自检 ---

check_auth() {
    if ! mysqladmin ping >/dev/null 2>&1; then
        if mysqladmin ping 2>&1 | grep -q "Access denied"; then
            alert "错误：无法连接数据库。请确保已配置 /root/.my.cnf 且权限正确 (chmod 600)。"
            exit 1
        fi
    fi
}

get_binlog_dir() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        local bin_base
        bin_base=$(mysql -N -e "SHOW VARIABLES LIKE 'log_bin_basename';" | awk '{print $2}')
        
        if [ -z "$bin_base" ]; then
            echo "" 
        else
            dirname "$bin_base" 
        fi
    else
        echo "/var/lib/mysql" 
    fi
}

# --- 故障分析与修复模块 ---

analyze_and_fix() {
    log ">>> 检测到 $SERVICE_NAME 服务异常，开始分析..."
    local data_dir="/var/lib/mysql"
    local disk_usage=$(df -h "$data_dir" | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$disk_usage" -ge 98 ]; then
        alert "严重故障: 磁盘空间已满 ($disk_usage%)。脚本无法修复，请手动清理！"
        exit 1
    fi
    if [ -f "$MYSQL_ERROR_LOG" ]; then
        log "正在分析日志: $MYSQL_ERROR_LOG"
        local recent_logs=$(tail -n 30 "$MYSQL_ERROR_LOG")
        
        echo "$recent_logs" >> "$SCRIPT_LOG"

        if echo "$recent_logs" | grep -q "Permission denied"; then
            alert "发现权限错误，尝试修复 /var/lib/mysql 权限..."
            chown -R mysql:mysql /var/lib/mysql
            chmod 750 /var/lib/mysql
        elif echo "$recent_logs" | grep -q "The server quit without updating PID file"; then
            alert "PID 文件丢失或进程僵死，尝试强制清理..."
        fi
    else
        alert "找不到 MySQL 错误日志文件，无法分析！"
    fi
    log "尝试重启 $SERVICE_NAME 服务..."
    systemctl restart "$SERVICE_NAME"
    sleep 5
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "自动修复成功: 服务已恢复运行。"
    else
        alert " 自动修复失败: 服务无法启动，请人工介入！"
        exit 1
    fi
}

# --- 备份模块 ---

perform_backup() {

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        alert "备份取消：服务未运行。"
        return
    fi
    local FULL_DIR="$BACKUP_ROOT/full"
    local INC_DIR="$BACKUP_ROOT/inc"
    mkdir -p "$FULL_DIR" "$INC_DIR"
    local WEEK_DAY=$(date +%u)
    local DATE_TIME=$(date +%Y%m%d_%H%M%S)
    local BINLOG_DIR=$(get_binlog_dir)
    if [ "$WEEK_DAY" -eq 7 ]; then
        log ">>> [周日] 开始全量备份 (Mysqldump)..."  
        mysqladmin flush-logs  
        mysqldump --all-databases \
            --single-transaction \
            --master-data=2 \
            --triggers --routines --events \
            | gzip > "$FULL_DIR/full_$DATE_TIME.sql.gz" 
        if [ $? -eq 0 ]; then
            log "全量备份成功: full_$DATE_TIME.sql.gz"
            find "$FULL_DIR" -type f -mtime +$RETENTION_DAYS -delete
        else
            alert "全量备份失败！"
        fi
    else
        log ">>> [日常] 开始增量备份 (Sync Binlog)..."
        if [ -z "$BINLOG_DIR" ]; then
            alert "未检测到 Binlog 配置，无法执行增量备份！请检查 my.cnf 中 log_bin 设置。"
            return
        fi
        mysqladmin flush-logs
        log "正在从 $BINLOG_DIR 同步日志..."
        rsync -av --ignore-existing \
            --include='mysql-bin.*' --exclude='*' \
            "$BINLOG_DIR/" "$INC_DIR/" >> "$SCRIPT_LOG" 2>&1
        if [ $? -eq 0 ]; then
            log "增量备份成功。"
            find "$INC_DIR" -type f -mtime +$RETENTION_DAYS -delete
        else
            alert "增量备份失败！请检查 rsync 日志。"
        fi
    fi
}

# --- 状态检查模块 ---

check_replication() {
    if [ "$IS_SLAVE" = false ]; then return; fi
    local slave_status=$(mysql -e "SHOW SLAVE STATUS\G")
    local io_run=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print $2}')
    local sql_run=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print $2}')
    if [ "$io_run" == "Yes" ] && [ "$sql_run" == "Yes" ]; then
        log "主从复制状态正常。"
    else
        alert "主从复制异常! IO:$io_run, SQL:$sql_run"
        if [ "$io_run" == "No" ] && [ "$sql_run" == "Yes" ]; then
            log "尝试自动重启 Slave IO 线程..."
            mysql -e "STOP SLAVE IO_THREAD; START SLAVE IO_THREAD;"
        fi
    fi
}

# --- 主执行逻辑 ---

log "==================== 任务开始 ===================="

# 权限预检
check_auth

# 检查服务存活
if mysqladmin ping >/dev/null 2>&1; then
    log "MySQL 服务运行正常。"
else
    alert "MySQL 服务无响应 (Ping Failed)。"
    analyze_and_fix
fi

# 检查主从 (如果配置了 IS_SLAVE=true)
check_replication

# 执行备份 (只有服务活着才备份)
if mysqladmin ping >/dev/null 2>&1; then
    perform_backup
fi

log "==================== 任务结束 ===================="
echo "" >> "$SCRIPT_LOG"
