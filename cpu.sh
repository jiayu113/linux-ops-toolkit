#!/bin/sh

echo "=========================================="
echo "           CPU信息统计报告"
echo "=========================================="
echo "统计时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "主机名称: $(hostname)"
echo "系统版本: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || uname -s)"
echo ""
​
# 基本CPU信息
echo "【基本信息】"
if command -v lscpu >/dev/null 2>&1; then
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')
    CPU_ARCH=$(lscpu | grep "Architecture" | awk "{print $2}")
    CPU_VENDOR=$(lscpu | grep "Vendor ID" | cut -d: -f2 | sed 's/^ *//')
    echo "CPU型号: $CPU_MODEL"
    echo "CPU架构: $CPU_ARCH"
    echo "CPU厂商: $CPU_VENDOR"
else
    CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2 | sed 's/^ *//')
    echo "CPU型号: $CPU_MODEL"
    echo "CPU架构: $(uname -m)"
fi
​
echo ""
​
# CPU数量统计
echo "【数量统计】"
PHYSICAL_CPU=$(cat /proc/cpuinfo | grep "physical id" | sort | uniq | wc -l)
LOGICAL_CPU=$(nproc)
CPU_CORES=$(cat /proc/cpuinfo | grep "cpu cores" | head -1 | cut -d: -f2 | sed 's/^ *//')
​
# 处理某些系统可能没有cpu cores字段的情况
if [ -z "$CPU_CORES" ] || [ "$CPU_CORES" = "" ]; then
    CPU_CORES=$(cat /proc/cpuinfo | grep "core id" | sort | uniq | wc -l)
    if [ "$CPU_CORES" -eq 0 ]; then
        CPU_CORES=$LOGICAL_CPU
    fi
fi
​
# 处理物理CPU为0的情况（某些虚拟机环境）
if [ "$PHYSICAL_CPU" -eq 0 ]; then
    PHYSICAL_CPU=1
fi
​
echo "物理CPU数量: $PHYSICAL_CPU 个"
echo "逻辑CPU数量: $LOGICAL_CPU 个"
echo "每个CPU核心数: $CPU_CORES 个"
​
# 判断是否支持超线程
TOTAL_CORES=$((PHYSICAL_CPU * CPU_CORES))
if [ $LOGICAL_CPU -gt $TOTAL_CORES ]; then
    THREADS_PER_CORE=$((LOGICAL_CPU / TOTAL_CORES))
    echo "超线程支持: 是 (每核心 $THREADS_PER_CORE 线程)"
else
    echo "超线程支持: 否"
fi
​
echo ""
​
# CPU频率信息
echo "【频率信息】"
if [ -f /proc/cpuinfo ]; then
    FREQ_LIST=$(cat /proc/cpuinfo | grep "cpu MHz" | awk "{print $4}")
    if [ ! -z "$FREQ_LIST" ]; then
        MIN_FREQ=$(echo "$FREQ_LIST" | sort -n | head -1)
        MAX_FREQ=$(echo "$FREQ_LIST" | sort -n | tail -1)
        AVG_FREQ=$(echo "$FREQ_LIST" | awk '{sum+=$1; count++} END {printf "%.2f", sum/count}')
        
        echo "当前最低频率: ${MIN_FREQ} MHz"
        echo "当前最高频率: ${MAX_FREQ} MHz"
        echo "当前平均频率: ${AVG_FREQ} MHz"
    fi
fi
​
# 尝试获取CPU基础频率和最大频率
if command -v lscpu >/dev/null 2>&1; then
    BASE_FREQ=$(lscpu | grep "CPU MHz" | awk "{print $3}")
    MAX_BOOST_FREQ=$(lscpu | grep "CPU max MHz" | awk "{print $4}")
    MIN_BOOST_FREQ=$(lscpu | grep "CPU min MHz" | awk "{print $4}")
    
    [ ! -z "$BASE_FREQ" ] && echo "CPU基础频率: ${BASE_FREQ} MHz"
    [ ! -z "$MAX_BOOST_FREQ" ] && echo "CPU最大频率: ${MAX_BOOST_FREQ} MHz"
    [ ! -z "$MIN_BOOST_FREQ" ] && echo "CPU最小频率: ${MIN_BOOST_FREQ} MHz"
fi
​
echo ""
​
# 缓存信息
echo "【缓存信息】"
if command -v lscpu >/dev/null 2>&1; then
    L1D_CACHE=$(lscpu | grep "L1d cache" | awk "{print $3}")
    L1I_CACHE=$(lscpu | grep "L1i cache" | awk "{print $3}")
    L2_CACHE=$(lscpu | grep "L2 cache" | awk "{print $3}")
    L3_CACHE=$(lscpu | grep "L3 cache" | awk "{print $3}")
    
    [ ! -z "$L1D_CACHE" ] && echo "L1数据缓存: $L1D_CACHE"
    [ ! -z "$L1I_CACHE" ] && echo "L1指令缓存: $L1I_CACHE"
    [ ! -z "$L2_CACHE" ] && echo "L2缓存: $L2_CACHE"
    [ ! -z "$L3_CACHE" ] && echo "L3缓存: $L3_CACHE"
else
    echo "无法获取缓存信息 (lscpu命令不可用)"
fi
​
echo ""
​
# CPU特性
echo "【CPU特性】"
if [ -f /proc/cpuinfo ]; then
    CPU_FLAGS=$(cat /proc/cpuinfo | grep "flags" | head -1 | cut -d: -f2)
    
    # 检查一些重要特性
    echo -n "虚拟化支持: "
    if echo $CPU_FLAGS | grep -q "vmx\|svm"; then
        if echo $CPU_FLAGS | grep -q "vmx"; then
            echo "是 (Intel VT-x)"
        else
            echo "是 (AMD-V)"
        fi
    else
        echo "否"
    fi
    
    echo -n "AES加速: "
    if echo $CPU_FLAGS | grep -q "aes"; then
        echo "是"
    else
        echo "否"
    fi
    
    echo -n "SSE4支持: "
    if echo $CPU_FLAGS | grep -q "sse4"; then
        echo "是"
    else
        echo "否"
    fi
    
    echo -n "AVX支持: "
    if echo $CPU_FLAGS | grep -q "avx"; then
        echo "是"
    else
        echo "否"
    fi
    
    echo -n "AVX2支持: "
    if echo $CPU_FLAGS | grep -q "avx2"; then
        echo "是"
    else
        echo "否"
    fi
fi
​
echo ""
​
# 当前CPU使用情况
echo "【当前状态】"
if command -v uptime >/dev/null 2>&1; then
    UPTIME_INFO=$(uptime)
    echo "系统负载: $UPTIME_INFO"
fi
​
# CPU温度信息（如果可用）
if command -v sensors >/dev/null 2>&1; then
    echo ""
    echo "【温度信息】"
    sensors 2>/dev/null | grep -E "Core|CPU|temp" | head -5
elif [ -d /sys/class/thermal ]; then
    echo ""
    echo "【温度信息】"
    for thermal in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$thermal" ]; then
            temp=$(cat "$thermal")
            zone=$(basename $(dirname "$thermal"))
            temp_c=$((temp / 1000))
            echo "$zone: ${temp_c}°C"
        fi
    done 2>/dev/null | head -5
fi
​
# CPU调速器信息
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo ""
    echo "【调速器信息】"
    GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    [ ! -z "$GOVERNOR" ] && echo "当前调速器: $GOVERNOR"
    
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]; then
        AVAILABLE_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
        [ ! -z "$AVAILABLE_GOV" ] && echo "可用调速器: $AVAILABLE_GOV"
    fi
fi
​
# 虚拟化环境检测
echo ""
echo "【环境检测】"
if [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup; then
    echo "运行环境: Docker容器"
elif [ -f /.dockerenv ]; then
    echo "运行环境: Docker容器"
elif command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_TYPE" != "none" ]; then
        echo "运行环境: 虚拟机 ($VIRT_TYPE)"
    else
        echo "运行环境: 物理机"
    fi
elif [ -f /proc/cpuinfo ] && grep -q "hypervisor" /proc/cpuinfo; then
    echo "运行环境: 虚拟机"
else
    echo "运行环境: 物理机"
fi
​
echo ""
echo "=========================================="
echo "           统计完成"
echo "=========================================="
