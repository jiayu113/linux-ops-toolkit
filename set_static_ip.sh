#!/bin/bash
set -e  # 遇到错误立即退出

# ===================== 配置参数 (使用前请修改) =====================
STATIC_IP="192.168.1.11/24"
GATEWAY="192.168.1.1"         
DNS_SERVERS="8.8.8.8, 114.114.114.114"  
NETPLAN_FILE="/etc/netplan/00-static-ip.yaml"  
# ===================== 前置检查 =====================
# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m错误：必须以root用户执行此脚本\033[0m"
    exit 1
fi

# 自动检测活跃的物理网卡
echo "正在检测活跃网卡..."
NETWORK_INTERFACE=$(ip link show | \
    grep -v LOOPBACK | \
    grep -v docker | \
    grep -v veth | \
    grep -v virbr | \
    awk '/UP/ {print $2}' | \
    sed 's/://' | \
    head -n1)

# 检查是否检测到网卡
if [ -z "$NETWORK_INTERFACE" ]; then
    echo -e "\033[31m错误：未检测到活跃的物理网卡，请手动确认网卡名称\033[0m"
    echo "可用网卡列表："
    ip link show | awk '/^[0-9]+/ {print $2}' | sed 's/://'
    exit 1
fi

echo -e "\033[32m检测到活跃网卡：$NETWORK_INTERFACE\033[0m"

# ===================== 备份原有配置 =====================
if [ -f "$NETPLAN_FILE" ]; then
    BACKUP_FILE="${NETPLAN_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$NETPLAN_FILE" "$BACKUP_FILE"
    echo -e "\033[33m已备份原有配置到：$BACKUP_FILE\033[0m"
fi

# ===================== 生成Netplan配置文件 =====================
echo "正在生成静态IP配置文件..."
cat > "$NETPLAN_FILE" << EOF
network:
  ethernets:
    $NETWORK_INTERFACE:
      addresses: [$STATIC_IP]
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS]
  version: 2
  renderer: networkd
EOF

# 检查配置文件语法
echo "正在校验配置文件语法..."
if ! netplan try --timeout 10; then
    echo -e "\033[31m配置文件语法错误，已自动回滚\033[0m"
    exit 1
fi

# ===================== 应用配置并验证 =====================
echo "应用静态IP配置..."
sudo netplan apply

# 验证IP是否生效
echo -e "\n\033[32m===== 配置结果验证 =====\033[0m"
CURRENT_IP=$(ip addr show "$NETWORK_INTERFACE" | grep 'inet ' | awk '{print $2}' | head -n1)
if [ "$CURRENT_IP" = "$STATIC_IP" ]; then
    echo -e " 静态IP配置成功：$CURRENT_IP"
else
    echo -e "\033[31m 静态IP配置失败，当前IP：$CURRENT_IP\033[0m"
fi

# 测试网关连通性
echo -n "测试网关($GATEWAY)连通性："
if ping -c 2 -W 2 "$GATEWAY" > /dev/null 2>&1; then
    echo -e "\033[32m成功\033[0m"
else
    echo -e "\033[31m失败（请检查网关地址）\033[0m"
fi

# 测试外网连通性
echo -n "测试外网连通性："
if ping -c 2 -W 2 www.baidu.com > /dev/null 2>&1; then
    echo -e "\033[32m成功\033[0m"
else
    echo -e "\033[31m失败（请检查DNS或网关配置）\033[0m"
fi

echo -e "\n\033[32m配置完成！重启网络服务或主机后配置依然生效\033[0m"