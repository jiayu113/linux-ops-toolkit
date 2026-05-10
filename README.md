#  Linux Server Ops Toolkit | 运维自动化脚本工具箱

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()

本仓库包含了一套基于 **Shell** 编写的生产级 Linux 服务器自动化运维脚本。涵盖了网络配置、核心服务（FreeSWITCH、EMQX、MySQL、Nginx、Java）的自动化部署、状态巡检、故障自愈、日志管理以及数据备份。

脚本设计融入了 **IaC (基础设施即代码)** 的理念，通过统一的 `env.sh` 集中管理多服务器的基础设施凭据与状态，支持跨服务器的远程指令分发与执行。

##  适用场景 & 架构假设

本工具箱默认假设您拥有一个分布式或者主从架构的服务器集群。为了方便管理，脚本将节点分为以下几类（您可根据实际业务灵活调整）：
- **中控机 (Control Node)**：运行大部分定时任务与巡检脚本的机器。
- **Server A (通讯/存储节点)**：例如运行 FreeSWITCH 核心服务及 MySQL 数据库。
- **Server B (业务/消息节点)**：例如运行 Java 业务后端程序及 EMQX 消息队列服务。

---

##  脚本功能目录

### 1.  网络与基础设施 (Networking)
* `set_static_ip.sh`：自动检测物理网卡，基于 Netplan 一键配置静态 IP，带语法校验与网络连通性回滚测试。
* `fix_multi_ip.sh`：一键修复由于 DHCP 和静态 IP 冲突导致的 Ubuntu 多 IP 问题，强制禁用 DHCP 并清理残留 IP。

### 2.  环境配置 (Environment)
* `env.example.sh`：**全局配置文件**。集中存储 IP、端口、目录路径及服务密码。所有多节点联动脚本均依赖此文件。

### 3.  状态巡检与故障自愈 (Watchdog & Auto-Repair)
* `watchdog_server_b.sh`：巡检业务节点（Server B），当检测到 Java 进程或 EMQX 离线时，自动拉起服务。
* `check_server_a_repair.sh`：监控核心节点（Server A）。自动检测 MySQL 是否异常进入锁表（Read-Only）模式并修复；监控 FreeSWITCH Sofia 模块运行状态并提供宕机重启机制。

### 4.  数据备份与灾备 (Backup & Disaster Recovery)
* `mysql_backup.sh`：带有**故障自检逻辑**的 MySQL 备份方案。支持服务宕机日志分析、周日全量备份（Mysqldump）与日常增量备份（Binlog 同步）。
* `fs_backup.sh`：FreeSWITCH 可恢复级核心配置备份方案。过滤臃肿的缓存与录音，仅打包 `conf`、`scripts`、`db` 等拉起服务所需的核心文件。

### 5.  数据同步与日志清理 (Sync & Cleanup)
* `archive_recordings.sh`：将远端（Server A）的历史录音文件增量拉取至归档服务器，利用 `--exclude` 安全绕过当天活跃文件，并自动清理远端空目录。
* `manage_server_a_logs.sh`：通过 SSH 远程下发多行指令，自动按天数压缩、清理远端服务器的 FreeSWITCH 庞大日志文件。

### 6.  安全与证书运维 (Security & SSL)
* `update_certs.sh`：提取 Let's Encrypt 的新 SSL 证书，自动分发并赋予正确权限给 EMQX 目录，并在无缝热重载 Nginx/EMQX 服务。

### 7.  性能与监控 (Monitoring)
* `cpu.sh`：提供极致详尽的 Linux 主机 CPU 参数与负载统计报告，包括：物理核数、频率、缓存、超线程、虚拟化环境检测及实时温度信息。
* `install_nginx_static.sh`：Nginx 源码编译级一键安装脚本。

---

##  快速开始

### 1. 克隆仓库
```bash
git clone https://github.com/jiayu113/linux-ops-toolkit.git
```

### 2. 配置环境变量 (关键步骤)
将模板文件复制为系统读取的真实配置文件：
```bash
cp env.example.sh env.sh
```
使用 `vim` 修改 `env.sh` 中的敏感信息（IP、端口、MySQL密码等）。
> **⚠️ 提示**：此仓库已通过 `.gitignore` 忽略了 `env.sh`，防止您不小心将真实的服务器密码推送到公共代码库。

### 3. 配置 SSH 免密登录 (用于跨服脚本)
对于带有 `_server_a` / `_server_b` 的脚本，需要中控机能够无密码管理目标服务器。
在中控机执行：
```bash
ssh-keygen -t rsa -b 4096 -N ""
ssh-copy-id -p <YOUR_SSH_PORT> root@<SERVER_A_IP>
ssh-copy-id -p <YOUR_SSH_PORT> root@<SERVER_B_IP>
```

### 4. 配置自动化任务 (Crontab)
建议通过 Linux Cron 定时执行这些脚本，示例 `crontab -e` 规则：
```crontab
# 每天凌晨 2:00 清理服务器日志
0 2 * * * /path/to/manage_server_a_logs.sh >> /var/log/ops_logs.log 2>&1

# 每天凌晨 3:00 归档昨日录音
0 3 * * * /path/to/archive_recordings.sh >> /var/log/ops_archive.log 2>&1

# 每天凌晨 4:00 备份 MySQL 和 FreeSWITCH 配置
0 4 * * * /path/to/mysql_backup.sh
30 4 * * * /path/to/fs_backup.sh

# 每 5 分钟执行一次高可用巡检
*/5 * * * * /path/to/watchdog_server_b.sh
*/5 * * * * /path/to/check_server_a_repair.sh
```

---

##  最佳实践与注意事项
1. **安全第一**：强烈建议在非 Root 用户的虚拟环境中测试后，再投入生产环境运行。
2. **权限配置**：执行 `.sh` 脚本前，请确保具备可执行权限：`chmod +x *.sh`。
3. **日志追踪**：多数守护脚本自带日志记录输出，方便后期排障（参考各脚本中的 `LOG_FILE` 变量）。

##  贡献指南
欢迎提交 Issue 和 Pull Request，我们致力于打造更稳定、更轻量的服务器运维工具集合。

##  开源许可
本项目遵循 [MIT License](LICENSE) 许可协议。您可以自由地使用、修改和分发。
