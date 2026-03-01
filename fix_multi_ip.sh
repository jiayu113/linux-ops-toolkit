#!/bin/bash

# ===================== 可自定义配置 =====================
TARGET_STATIC_IP="192.168.1.11/24"
GATEWAY="192.168.1.1"               
DNS_SERVERS="223.5.5.5, 114.114.114.114"  
NETWORK_INTERFACE="ens33"         
NETPLAN_FILE="/etc/netplan/00-static-ip.yaml"  # 配置文件路径

# ===================== 前置检查 =====================
# 检查是否为root用户
if[ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m错误：必须以root用户执行此脚本（请加sudo）\033[0m"
    exit 1
fi

# 检查网卡是否存在
if ! ip link show "$NETWORK_INTERFACE" > /dev/null 2>&1; then
    echo -e "\033[31m错误：网卡 $NETWORK_INTERFACE 不存在！\033[0m"
    echo "可用网卡列表："
    ip link show | awk '/^[0-9]+/ {print $2}' | sed 's/://'
    exit 1
fi

# ===================== 备份原有配置 =====================
if[ -f "$NETPLAN_FILE" ]; then
    BACKUP_FILE="${NETPLAN_FILE}.fix_multi_ip_bak_$(date +%Y%m%d_%H%M%S)"
    cp "$NETPLAN_FILE" "$BACKUP_FILE"
    echo -e "\033[33m已备份原有配置到：$BACKUP_FILE\033[0m"
fi

# ===================== 生成最终配置（禁用DHCP）=====================
echo "正在生成禁用DHCP的静态IP配置..."
cat > "$NETPLAN_FILE" << EOF
network:
  ethernets:
    $NETWORK_INTERFACE:
      addresses: [$TARGET_STATIC_IP]
      dhcp4: no          # 禁用IPv4 DHCP
      dhcp6: no          # 禁用IPv6 DHCP
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS]
  version: 2
  renderer: networkd
EOF

# ===================== 应用配置并清除残留IP =====================
echo "应用配置并重启网卡..."
sudo netplan apply

# 重启网卡，彻底清除残留动态IP
sudo ip link set "$NETWORK_INTERFACE" down
sleep 2
sudo ip link set "$NETWORK_INTERFACE" up

# 额外清除非目标的IP
echo "清理残留的非目标IP..."

# 获取当前网卡所有IP（排除回环、目标IP）
CURRENT_IPS=$(ip addr show "$NETWORK_INTERFACE" | grep 'inet ' | awk '{print $2}' | grep -v "$TARGET_STATIC_IP" | grep -v '127.0.0.1')
if [ -n "$CURRENT_IPS" ]; then
    for ip in $CURRENT_IPS; do
        sudo ip addr del "$ip" dev "$NETWORK_INTERFACE"
        echo -e "\033[32m已删除残留IP：$ip\033[0m"
    done
else
    echo -e "\033[32m未检测到残留IP\033[0m"
fi

# ===================== 验证最终结果 =====================
echo -e "\n\033[32m===== 最终配置验证 =====\033[0m"
FINAL_IPS=$(ip addr show "$NETWORK_INTERFACE" | grep 'inet ' | awk '{print $2}')
echo "当前网卡 $NETWORK_INTERFACE 的IP列表："
echo "$FINAL_IPS"

# 检查是否只有目标IP
if echo "$FINAL_IPS" | grep -q "$TARGET_STATIC_IP" && [ $(echo "$FINAL_IPS" | wc -l) -eq 1 ]; then
    echo -e "\033[32m 修复成功！仅保留静态IP：$TARGET_STATIC_IP\033[0m"
else
    echo -e "\033[31m 修复未完全生效，请手动执行 ip addr show $NETWORK_INTERFACE 检查\033[0m"
fi