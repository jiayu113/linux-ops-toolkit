#!/bin/bash
# 强制使用 bash，因为有些高级操作和管道在极简 /bin/sh 下可能行为不一

echo "=========================================="
echo "           CPU 状态诊断报告"
echo "=========================================="
echo "统计时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "主机名称: $(hostname)"
# 优化: 避免 cat，直接用 grep，并做好为空时的兜底
OS_VERSION=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)
echo "系统版本: $OS_VERSION"
echo ""

echo "【基本信息】"
if command -v lscpu >/dev/null 2>&1; then
    # 修复: sed 替换空格更严谨，awk 必须使用单引号
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    CPU_ARCH=$(lscpu | grep "Architecture" | awk '{print $2}')
    CPU_VENDOR=$(lscpu | grep "Vendor ID" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "CPU型号: $CPU_MODEL"
    echo "CPU架构: $CPU_ARCH"
    echo "CPU厂商: $CPU_VENDOR"
else
    # 兜底老旧系统
    CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "CPU型号: ${CPU_MODEL:-Unknown}"
    echo "CPU架构: $(uname -m)"
fi
echo ""

echo "【数量统计】"
# 优化: 精准统计物理 CPU 和逻辑核心数
if [ -f /proc/cpuinfo ]; then
    PHYSICAL_CPUS=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
    [ "$PHYSICAL_CPUS" -eq 0 ] && PHYSICAL_CPUS=1 # 某些云主机会缺少 physical id
    LOGICAL_CORES=$(grep -c "processor" /proc/cpuinfo)
    echo "物理 CPU: $PHYSICAL_CPUS 颗"
    echo "逻辑核心: $LOGICAL_CORES 核"
else
    echo "无法读取 /proc/cpuinfo"
fi
echo ""

echo "【温度状态】"
if ls /sys/class/thermal/thermal_zone*/temp >/dev/null 2>&1; then
    for thermal in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$thermal" ]; then
            temp=$(cat "$thermal" 2>/dev/null)
            zone=$(basename "$(dirname "$thermal")")
            # 防御性编程：确保拿到的确实是数字再做数学运算
            if [ -n "$temp" ] && [ "$temp" -eq "$temp" ] 2>/dev/null; then
                temp_c=$((temp / 1000))
                echo "$zone: ${temp_c}°C"
            fi
        fi
    done | head -n 5
else
    echo "未检测到系统温度传感器。"
fi
echo ""

echo "【调速器信息】"
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    [ -n "$GOVERNOR" ] && echo "当前调速器: $GOVERNOR"
    
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]; then
        AVAILABLE_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
        [ -n "$AVAILABLE_GOV" ] && echo "可用调速器: $AVAILABLE_GOV"
    fi
else
    echo "当前系统不支持或未开放 CPU 频率调节。"
fi
echo ""

echo "【环境检测】"
if [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "运行环境: Docker 容器"
elif [ -f /proc/1/cgroup ] && grep -q lxc /proc/1/cgroup 2>/dev/null; then
    echo "运行环境: LXC 容器"
else
    # 增加对虚拟机的原生检测支持
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT=$(systemd-detect-virt)
        if [ "$VIRT" = "none" ]; then
            echo "运行环境: 物理机 (Bare Metal)"
        else
            echo "运行环境: 虚拟机 ($VIRT)"
        fi
    else
        echo "运行环境: 未知 (非容器环境)"
    fi
fi
echo ""
echo "=========================================="