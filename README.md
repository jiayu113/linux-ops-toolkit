# linux-ops-toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)

一组用于多台 Linux 服务器日常运维的 Shell 脚本:服务巡检与自动拉起、MySQL / FreeSWITCH 备份、日志与录音归档清理、SSL 证书更新分发等。节点信息与凭据集中在 `env.sh`,由中控机通过 SSH 管理其余节点。

## 架构假设

脚本按"一台中控机 + 若干业务节点"组织,角色可按实际环境调整:

```
        中控机(跑定时任务与巡检脚本)
         │ SSH            │ SSH
    Server A          Server B
    FreeSWITCH        Java 后端
    MySQL             EMQX
```

## 脚本列表

| 脚本 | 说明 |
|------|------|
| `env.example.sh` | 配置模板:IP、端口、路径与服务凭据。多节点脚本均依赖复制出的 `env.sh` |
| `set_static_ip.sh` | 基于 Netplan 配置静态 IP,自动检测网卡;带语法校验,连通性测试失败自动回滚 |
| `fix_multi_ip.sh` | 修复 DHCP 与静态 IP 冲突导致的多 IP 问题,禁用 DHCP 并清理残留 IP |
| `watchdog_server_b.sh` | 巡检业务节点,Java 进程或 EMQX 离线时自动拉起 |
| `check_server_a_repair.sh` | 监控 MySQL 只读(锁表)状态并自动修复;检查 FreeSWITCH Sofia 模块,支持宕机重启 |
| `mysql_backup.sh` | MySQL 备份:周日 mysqldump 全量 + 日常 binlog 增量;备份前自检服务状态、分析宕机日志 |
| `fs_backup.sh` | FreeSWITCH 配置备份:只打包 `conf` / `scripts` / `db` 等恢复所需文件,不含缓存与录音 |
| `archive_recordings.sh` | 从远端增量拉取历史录音归档,跳过当天活跃文件,清理远端空目录 |
| `manage_server_a_logs.sh` | 通过 SSH 远程按天数压缩、清理 FreeSWITCH 日志 |
| `update_certs.sh` | 提取 Let's Encrypt 新证书,分发并设置权限,热重载 Nginx / EMQX |
| `install_nginx_static.sh` | Nginx 源码编译安装 |
| `cpu.sh` | 输出 CPU 参数与负载报告:核数、频率、缓存、超线程、虚拟化、温度 |

## 使用

```bash
git clone https://github.com/jiayu113/linux-ops-toolkit.git
cd linux-ops-toolkit
chmod +x *.sh

cp env.example.sh env.sh
vim env.sh    # 填入实际的 IP、端口、凭据
```

`env.sh` 已在 `.gitignore` 中,不会被提交。

跨节点脚本(带 `_server_a` / `_server_b` 后缀)需要中控机对目标节点免密登录:

```bash
ssh-keygen -t rsa -b 4096 -N ""
ssh-copy-id -p <SSH_PORT> ops@<SERVER_A_IP>
ssh-copy-id -p <SSH_PORT> ops@<SERVER_B_IP>
```

巡检与备份类脚本建议交给 cron,`crontab -e` 示例:

```crontab
0 2 * * *    /path/to/manage_server_a_logs.sh >> /var/log/ops_logs.log 2>&1
0 3 * * *    /path/to/archive_recordings.sh   >> /var/log/ops_archive.log 2>&1
0 4 * * *    /path/to/mysql_backup.sh
30 4 * * *   /path/to/fs_backup.sh
*/5 * * * *  /path/to/watchdog_server_b.sh
*/5 * * * *  /path/to/check_server_a_repair.sh
```

## 注意

- 先在测试机验证脚本行为,再用于生产环境
- 网络类脚本(`set_static_ip.sh` / `fix_multi_ip.sh`)面向 Ubuntu / Netplan
- 守护类脚本的日志路径见各脚本内 `LOG_FILE` 变量

## License

[MIT](LICENSE)
