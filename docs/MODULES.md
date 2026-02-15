# 模块说明

本文档详细说明各个功能模块的作用和使用方法。

## 📦 模块概览

VPS Configuration 工具包含 10 个核心模块：

| 模块 | 文件 | 功能 | 可选/必需 |
|------|------|------|----------|
| 用户管理 | `01-user-management.sh` | 创建/管理系统用户 | 必需 |
| 主机名设置 | `02-hostname-setup.sh` | 设置系统主机名 | 可选 |
| 软件包安装 | `03-package-install.sh` | 安装基础工具 | 必需 |
| SSH 安全加固 | `04-ssh-hardening.sh` | SSH 安全配置 | 强烈推荐 |
| 防火墙配置 | `05-firewall-ufw.sh` | UFW 防火墙设置 | 强烈推荐 |
| Fail2ban | `06-fail2ban-setup.sh` | 防暴力破解 | 强烈推荐 |
| 时区设置 | `07-timezone-setup.sh` | 配置系统时区 | 推荐 |
| APT 优化 | `08-apt-optimization.sh` | 优化包管理器 | 推荐 |
| Swap 优化 | `09-swap-optimization.sh` | Swap 空间管理 | 推荐 |
| BBR 网络优化 | `10-network-bbr.sh` | 启用 BBR 拥塞控制 | 推荐 |

---

## 1️⃣ 用户管理模块

### 功能描述
- 创建新用户或验证现有用户
- 创建用户常用目录（project, workspace, data, script）
- 将用户添加到 sudo 组
- 设置正确的目录权限

### 单独使用
```bash
sudo bash scripts/core/01-user-management.sh <username> [interactive]
```

### 配置项
- `VPS_USER`: 用户名
- `ENABLE_USER_SETUP`: 是否启用此模块

### 创建的目录
```
/home/<username>/
├── project/      # 项目目录
├── workspace/    # 工作空间
├── data/         # 数据目录
└── script/       # 脚本目录
```

---

## 2️⃣ 主机名设置模块

### 功能描述
- 设置系统主机名
- 更新 /etc/hostname
- 更新 /etc/hosts

### 单独使用
```bash
sudo bash scripts/core/02-hostname-setup.sh <hostname> [interactive]
```

### 配置项
- `VPS_HOSTNAME`: 新主机名
- `ENABLE_HOSTNAME_SETUP`: 是否启用此模块

### 注意事项
- 主机名仅允许字母、数字和连字符
- 修改后需要重新登录才能在提示符中看到变化

---

## 3️⃣ 软件包安装模块

### 功能描述
安装常用的系统工具和运维软件

### 默认安装的软件包
- `curl` - 数据传输工具
- `git` - 版本控制系统
- `vim` - 文本编辑器
- `htop` - 进程监控工具
- `ufw` - 防火墙
- `fail2ban` - 防暴力破解工具
- `ca-certificates` - SSL 证书

### 单独使用
```bash
# 安装默认软件包
sudo bash scripts/core/03-package-install.sh

# 安装自定义软件包
sudo bash scripts/core/03-package-install.sh curl git nginx
```

### 配置项
- `ENABLE_PACKAGE_INSTALL`: 是否启用此模块

---

## 4️⃣ SSH 安全加固模块

### 功能描述
这是最重要的安全模块，提供：
- 配置 SSH 公钥认证
- 禁用密码登录
- 禁止 root 登录
- 限制允许登录的用户
- 自定义 SSH 端口
- 其他安全加固设置

### 单独使用
```bash
sudo bash scripts/core/04-ssh-hardening.sh <username> [ssh_pubkey] [ssh_port]
```

### 配置项
- `SSH_PUBKEY`: SSH 公钥
- `SSH_PUBKEY_FILE`: 公钥文件路径
- `SSH_PORT`: SSH 端口号
- `SSH_CHANGE_PORT`: 是否修改端口
- `SSH_DISABLE_ROOT`: 禁止 root 登录
- `SSH_DISABLE_PASSWORD`: 禁用密码登录
- `ENABLE_SSH_HARDENING`: 是否启用此模块

### 安全配置详情
```
/etc/ssh/sshd_config.d/
├── 98-vps-port.conf          # 端口配置
└── 99-vps-hardening.conf     # 安全配置
```

### ⚠️ 重要警告
- 执行此模块后，**必须在新终端测试 SSH 连接**
- 确认可以登录后再关闭当前会话
- 如果配置错误可能导致无法登录服务器

---

## 5️⃣ 防火墙配置模块

### 功能描述
使用 UFW (Uncomplicated Firewall) 配置防火墙规则

### 默认策略
- 拒绝所有入站连接
- 允许所有出站连接
- 放行 SSH 端口

### 单独使用
```bash
sudo bash scripts/core/05-firewall-ufw.sh <ssh_port> [extra_ports]

# 示例
sudo bash scripts/core/05-firewall-ufw.sh 2222 "80,443"
```

### 配置项
- `FIREWALL_EXTRA_PORTS`: 额外开放的端口
- `ENABLE_FIREWALL`: 是否启用此模块

### 常用端口
```
80    - HTTP
443   - HTTPS
3000  - Node.js 应用
8080  - 备用 HTTP
3306  - MySQL
5432  - PostgreSQL
6379  - Redis
27017 - MongoDB
```

### 管理命令
```bash
# 查看状态
sudo ufw status verbose

# 添加规则
sudo ufw allow 80/tcp

# 删除规则
sudo ufw delete allow 80/tcp

# 禁用防火墙（不推荐）
sudo ufw disable
```

---

## 6️⃣ Fail2ban 防护模块

### 功能描述
监控 SSH 登录日志，自动封禁暴力破解的 IP

### 工作原理
1. 监听 SSH 日志
2. 检测失败的登录尝试
3. 达到阈值后自动封禁 IP
4. 配合 UFW 执行封禁

### 单独使用
```bash
sudo bash scripts/core/06-fail2ban-setup.sh <ssh_port> [maxretry] [findtime] [bantime]

# 示例
sudo bash scripts/core/06-fail2ban-setup.sh 2222 5 10m 6h
```

### 配置项
- `F2B_MAXRETRY`: 最大重试次数（默认: 5）
- `F2B_FINDTIME`: 查找时间窗口（默认: 10m）
- `F2B_BANTIME`: 封禁时间（默认: 6h）
- `ENABLE_FAIL2BAN`: 是否启用此模块

### 管理命令
```bash
# 查看状态
sudo fail2ban-client status sshd

# 解封 IP
sudo fail2ban-client set sshd unbanip <ip_address>

# 查看被封禁的 IP
sudo fail2ban-client status sshd | grep "Banned IP"

# 重启服务
sudo systemctl restart fail2ban
```

---

## 7️⃣ 时区设置模块

### 功能描述
配置系统时区，确保日志和时间戳正确

### 单独使用
```bash
sudo bash scripts/core/07-timezone-setup.sh <timezone>

# 示例
sudo bash scripts/core/07-timezone-setup.sh Asia/Shanghai
```

### 配置项
- `TIMEZONE`: 时区（默认: Asia/Hong_Kong）
- `ENABLE_TIMEZONE`: 是否启用此模块

### 常用时区
```
Asia/Shanghai     - 中国（北京）
Asia/Hong_Kong    - 香港
Asia/Taipei       - 台北
Asia/Tokyo        - 东京
America/New_York  - 美国东部
Europe/London     - 伦敦
UTC               - 协调世界时
```

### 查看所有时区
```bash
timedatectl list-timezones
```

---

## 8️⃣ APT 优化模块

### 功能描述
优化 APT 包管理器的下载和更新性能

### 优化项
- 自动重试失败的下载
- 设置合理的超时时间
- 启用并发下载
- 配置更新时保留旧配置
- 减少建议包安装

### 单独使用
```bash
# 配置优化
sudo bash scripts/core/08-apt-optimization.sh setup

# 清理缓存
sudo bash scripts/core/08-apt-optimization.sh clean

# 更新索引
sudo bash scripts/core/08-apt-optimization.sh update

# 升级系统
sudo bash scripts/core/08-apt-optimization.sh upgrade
```

### 配置项
- `ENABLE_APT_OPTIMIZATION`: 是否启用此模块

### 配置文件
```
/etc/apt/apt.conf.d/99-vps-optimization
```

---

## 9️⃣ Swap 优化模块

### 功能描述
- 配置 Swap 相关内核参数
- 可选创建 swapfile
- 优化内存使用策略

### 单独使用
```bash
# 只配置参数
sudo bash scripts/core/09-swap-optimization.sh setup

# 创建 2GB swapfile
sudo bash scripts/core/09-swap-optimization.sh create 2G

# 删除 swapfile
sudo bash scripts/core/09-swap-optimization.sh remove

# 查看状态
sudo bash scripts/core/09-swap-optimization.sh status
```

### 配置项
- `SWAP_CREATE`: 是否创建 swapfile
- `SWAP_SIZE`: Swapfile 大小
- `SWAP_SWAPPINESS`: Swappiness 值（0-100）
- `SWAP_CACHE_PRESSURE`: 缓存压力（0-100）
- `ENABLE_SWAP`: 是否启用此模块

### Swappiness 说明
- **0-10**: 最小化使用 swap（适合服务器）
- **60**: 默认值（适合桌面）
- **100**: 积极使用 swap

### 推荐配置
| 内存大小 | Swap 大小 | Swappiness |
|---------|-----------|-----------|
| < 2GB   | 2GB       | 10        |
| 2-4GB   | 2-4GB     | 10        |
| > 4GB   | 按需      | 10        |

---

## 🔟 BBR 网络优化模块

### 功能描述
启用 Google 开发的 BBR (Bottleneck Bandwidth and RTT) 拥塞控制算法

### 优势
- 显著提升网络吞吐量
- 降低网络延迟
- 改善高延迟网络的表现

### 单独使用
```bash
# 启用 BBR
sudo bash scripts/core/10-network-bbr.sh enable

# 查看状态
sudo bash scripts/core/10-network-bbr.sh status

# 验证
sudo bash scripts/core/10-network-bbr.sh verify

# 禁用 BBR
sudo bash scripts/core/10-network-bbr.sh disable
```

### 配置项
- `ENABLE_BBR`: 是否启用此模块

### 要求
- Linux 内核 4.9 或更高版本
- Debian 12 默认支持

### 验证 BBR
```bash
# 检查当前拥塞控制算法
sysctl net.ipv4.tcp_congestion_control

# 检查队列调度
sysctl net.core.default_qdisc

# 查看可用算法
cat /proc/sys/net/ipv4/tcp_available_congestion_control
```

---

## 🔄 模块执行顺序

推荐的执行顺序（已在 bootstrap.sh 中实现）：

1. **用户管理** - 创建用户
2. **主机名设置** - 设置主机名
3. **时区设置** - 配置时区
4. **APT 优化** - 优化包管理器
5. **软件包安装** - 安装必需工具
6. **SSH 安全加固** - 配置 SSH
7. **防火墙配置** - 配置 UFW
8. **Fail2ban 配置** - 启用防护
9. **Swap 优化** - 配置 Swap
10. **BBR 网络优化** - 启用 BBR

---

## 💡 模块组合建议

### 最小安全配置
```bash
ENABLE_USER_SETUP="yes"
ENABLE_PACKAGE_INSTALL="yes"
ENABLE_SSH_HARDENING="yes"
ENABLE_FIREWALL="yes"
```

### 标准配置
```bash
# 启用所有模块
ENABLE_USER_SETUP="yes"
ENABLE_HOSTNAME_SETUP="yes"
ENABLE_PACKAGE_INSTALL="yes"
ENABLE_SSH_HARDENING="yes"
ENABLE_FIREWALL="yes"
ENABLE_FAIL2BAN="yes"
ENABLE_TIMEZONE="yes"
ENABLE_APT_OPTIMIZATION="yes"
ENABLE_SWAP="yes"
ENABLE_BBR="yes"
```

### 性能优化配置
```bash
ENABLE_APT_OPTIMIZATION="yes"
ENABLE_SWAP="yes"
ENABLE_BBR="yes"
```

---

## 📚 相关文档

- [安装指南](INSTALLATION.md)
- [配置说明](CONFIGURATION.md)
- [故障排查](TROUBLESHOOTING.md)
- [常见问题](FAQ.md)
