#!/bin/bash

# ================= 配置区域 =================
DOMAIN="domain.com" # 请替换为真实域名
LE_DIR="/etc/letsencrypt/live/$DOMAIN"
EMQX_DIR="/etc/emqx/certs"
LOG_FILE="/var/log/cert_update.log"
# ===========================================

# 定义日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始更新 EMQX 证书..."

# 检查源文件是否存在
if [ ! -d "$LE_DIR" ]; then
    log "错误：找不到 Let's Encrypt 证书目录 $LE_DIR"
    exit 1
fi

# 强制复制证书 
log "正在从 $LE_DIR 复制证书到 $EMQX_DIR ..."
cp -L -f "$LE_DIR/fullchain.pem" "$EMQX_DIR/fullchain.pem"
cp -L -f "$LE_DIR/privkey.pem" "$EMQX_DIR/privkey.pem"

if [ $? -eq 0 ]; then
    log "证书复制成功。"
else
    log "错误：证书复制失败！"
    exit 1
fi

# 修复权限
log "正在修复文件权限..."
chown -R emqx:emqx "$EMQX_DIR"
chmod 644 "$EMQX_DIR/fullchain.pem"
chmod 600 "$EMQX_DIR/privkey.pem"

# 重启 EMQX 服务
log "正在重启 EMQX 服务..."
if command -v systemctl &> /dev/null; then
    systemctl restart emqx
    if [ $? -eq 0 ]; then
        log "EMQX (systemd) 重启成功！"
    else
        log "警告：systemctl 重启失败，尝试直接使用 emqx 命令..."
        emqx restart
    fi
else
    emqx restart
fi

# 重载 Nginx
log "正在重载 Nginx..."
if [ -f "/usr/local/nginx/sbin/nginx" ]; then
    /usr/local/nginx/sbin/nginx -s reload
    log "Nginx 重载命令已发送。"
else
    systemctl reload nginx 2>/dev/null || log "未找到标准 Nginx 服务，跳过。"
fi

log "所有更新操作完成！HTTPS 和 MQTTS 已更新到最新证书。"
log "---------------------------------------------------"