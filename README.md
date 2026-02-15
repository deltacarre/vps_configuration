# VPS Configuration

> 🚀 专业的 VPS 初始化与安全加固工具 - 模块化、工程化、易维护

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-12-green.svg)](https://www.debian.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

专为 **Debian 12** 系统设计的 VPS 自动化配置工具，集成用户管理、SSH 安全加固、防火墙配置、网络优化与系统性能调优。模块化设计，支持配置文件管理，适用于个人开发环境、生产环境部署和批量服务器管理。

---

## ✨ 特性

- 🔧 **模块化设计** - 10 个独立功能模块，可选择性启用
- 📝 **配置文件驱动** - 支持配置文件管理，便于批量部署
- 🛡️ **安全优先** - SSH 密钥认证、防火墙、Fail2ban 防暴力破解
- ⚡ **性能优化** - BBR 拥塞控制、Swap 优化、APT 加速
- 🔄 **幂等性** - 可重复执行，不会破坏现有配置
- 📚 **完整文档** - 详细的安装、配置和故障排查文档
- 🚫 **防锁死** - 智能检查，避免配置错误导致无法登录

---

## 🚀 快速开始

### 方式一：交互模式（推荐首次使用）

```bash
git clone https://github.com/deltacarre/vps_configuration.git
cd vps_configuration
chmod +x install.sh
sudo ./install.sh
```

### 方式二：配置文件模式（推荐批量部署）

```bash
# 1. 克隆仓库
git clone https://github.com/deltacarre/vps_configuration.git
cd vps_configuration

# 2. 复制并编辑配置文件
cp config/template.conf config/myserver.conf
vim config/myserver.conf

# 3. 执行安装
sudo ./install.sh --config config/myserver.conf
```

### 最小配置示例

```bash
# config/myserver.conf
VPS_USER="admin"
SSH_PUBKEY="ssh-ed25519 AAAA... user@host"
```

---

## 📦 功能模块

| 模块 | 功能 | 状态 |
|------|------|------|
| 👤 **用户管理** | 创建用户、配置目录、sudo 权限 | ✅ |
| 🏷️ **主机名** | 设置系统主机名 | ✅ |
| 📦 **软件包** | 安装基础工具（curl, git, vim, htop 等） | ✅ |
| 🔐 **SSH 加固** | 密钥认证、禁用密码、限制用户 | ✅ |
| 🛡️ **防火墙** | UFW 配置、端口管理 | ✅ |
| 🚫 **Fail2ban** | SSH 防暴力破解、自动封禁 | ✅ |
| 🌏 **时区** | 系统时区配置 | ✅ |
| ⚡ **APT 优化** | 包管理器加速、自动重试 | ✅ |
| 💾 **Swap** | 交换空间管理、内存优化 | ✅ |
| 🌐 **BBR** | 网络拥塞控制、性能提升 | ✅ |

详细说明请查看 [模块文档](docs/MODULES.md)

---

## 📋 项目结构

```
vps_configuration/
├── install.sh                 # 安装入口脚本
├── config/                    # 配置文件
│   ├── default.conf          # 默认配置
│   ├── template.conf         # 配置模板
│   └── production.conf.example
├── scripts/                   # 核心脚本
│   ├── bootstrap.sh          # 主控制脚本
│   ├── core/                 # 功能模块
│   │   ├── 01-user-management.sh
│   │   ├── 04-ssh-hardening.sh
│   │   ├── 05-firewall-ufw.sh
│   │   └── ...
│   └── lib/                  # 库函数
│       ├── logger.sh         # 日志函数
│       ├── utils.sh          # 工具函数
│       └── checker.sh        # 检查函数
├── templates/                 # 配置模板
├── docs/                      # 文档
│   ├── INSTALLATION.md       # 安装指南
│   ├── CONFIGURATION.md      # 配置说明
│   ├── MODULES.md            # 模块文档
│   ├── TROUBLESHOOTING.md    # 故障排查
│   └── FAQ.md                # 常见问题
└── README.md                 # 项目说明
```

---

## 🔒 安全特性

执行完成后，你的服务器将拥有：

- ✅ 仅允许 SSH 密钥登录
- ✅ 禁止 root 用户 SSH 登录
- ✅ 限制只有指定用户可以登录
- ✅ UFW 防火墙保护（默认拒绝入站）
- ✅ Fail2ban 自动封禁暴力破解 IP
- ✅ 最小化安装（只安装必需软件）
- ✅ 系统性能优化（BBR、Swap）

---

## 📖 文档

- [📥 安装指南](docs/INSTALLATION.md) - 详细的安装步骤和使用方法
- [⚙️ 配置说明](docs/CONFIGURATION.md) - 所有配置项的详细说明
- [📦 模块文档](docs/MODULES.md) - 各个功能模块的详细介绍
- [🔧 故障排查](docs/TROUBLESHOOTING.md) - 常见问题的诊断和解决
- [❓ 常见问题](docs/FAQ.md) - FAQ 和快速解答

---

## ⚙️ 使用示例

### 只执行特定模块

```bash
# 只配置 SSH 和防火墙
sudo ./install.sh --modules ssh,firewall,fail2ban
```

### 生产环境配置

```bash
# config/production.conf
VPS_USER="deploy"
VPS_HOSTNAME="prod-web-01"
SSH_PUBKEY="ssh-ed25519 AAAA..."
SSH_PORT="2222"
SSH_CHANGE_PORT="yes"
FIREWALL_EXTRA_PORTS="80,443"
F2B_MAXRETRY="3"
F2B_BANTIME="24h"
SWAP_CREATE="yes"
SWAP_SIZE="4G"
INTERACTIVE_MODE="no"

# 执行
sudo ./install.sh --config config/production.conf
```

### 单独运行模块

```bash
# 单独配置 SSH
sudo bash scripts/core/04-ssh-hardening.sh admin "ssh-ed25519 AAAA..."

# 单独配置防火墙
sudo bash scripts/core/05-firewall-ufw.sh 2222 "80,443"

# 启用 BBR
sudo bash scripts/core/10-network-bbr.sh enable
```

---

## ⚠️ 重要提示

### 执行前

- ✅ 准备好 SSH 公钥（必需）
- ✅ 记录当前 SSH 端口
- ✅ 确保网络连接正常

### 执行后

- 🔴 **立即在新终端测试 SSH 连接！**
- 🔴 **确认可以登录后再关闭当前会话！**
- ✅ 测试 sudo 权限是否正常
- ✅ 保存系统报告

### 测试连接

```bash
# 在另一个终端窗口
ssh -p <SSH_PORT> <USERNAME>@<SERVER_IP>

# 测试 sudo
sudo whoami
```

---

## 🌍 兼容性

### 完全支持
- ✅ Debian 12 (Bookworm)

### 基本支持
- 🟡 Debian 11 (Bullseye)
- 🟡 Ubuntu 22.04 LTS
- 🟡 Ubuntu 24.04 LTS

### 要求
- systemd 初始化系统
- OpenSSH Server
- Bash 4.0+

---

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证

---

## 🔗 相关链接

- [GitHub 仓库](https://github.com/deltacarre/vps_configuration)
- [问题反馈](https://github.com/deltacarre/vps_configuration/issues)

---

## 💡 提示

- 建议在测试环境先验证再部署到生产环境
- 定期更新系统和软件包：`sudo apt update && sudo apt upgrade`
- 保存好配置文件和 SSH 密钥
- 定期查看系统日志和安全报告

---

## 🙏 致谢

感谢所有为这个项目做出贡献的开发者和用户！

---

**如果这个项目对你有帮助，请给个 ⭐️ Star 支持一下！**
