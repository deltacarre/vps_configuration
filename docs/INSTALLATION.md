# 安装指南

本文档介绍如何使用 VPS Configuration 工具初始化和配置你的 VPS 服务器。

## 📋 前置要求

- **系统**: Debian 12 (Bookworm) 或兼容系统
- **权限**: root 或 sudo 权限
- **网络**: 能够访问互联网
- **SSH 公钥**: 用于密钥认证登录

## 🚀 快速开始

### 方式一：直接运行（推荐用于首次部署）

```bash
# 1. 克隆仓库
git clone https://github.com/deltacarre/vps_configuration.git
cd vps_configuration

# 2. 赋予执行权限
chmod +x install.sh

# 3. 运行安装（交互模式）
sudo ./install.sh
```

### 方式二：使用配置文件（推荐用于批量部署）

```bash
# 1. 克隆仓库
git clone https://github.com/deltacarre/vps_configuration.git
cd vps_configuration

# 2. 复制并编辑配置文件
cp config/template.conf config/myserver.conf
vim config/myserver.conf

# 3. 使用配置文件运行
sudo ./install.sh --config config/myserver.conf
```

### 方式三：一键远程安装

```bash
# 注意：此方式需要提前准备配置文件
curl -sSL https://raw.githubusercontent.com/deltacarre/vps_configuration/main/install.sh | sudo bash
```

## 📝 配置文件说明

### 必需配置项

在使用配置文件模式时，以下配置项必须设置：

```bash
# 用户名（必需）
VPS_USER="admin"

# SSH 公钥（必需，用于密钥登录）
SSH_PUBKEY="ssh-ed25519 AAAA... user@host"
```

### 推荐配置项

```bash
# 主机名
VPS_HOSTNAME="my-server"

# 时区
TIMEZONE="Asia/Hong_Kong"

# SSH 端口（建议修改）
SSH_CHANGE_PORT="yes"
SSH_PORT="2222"

# 需要开放的端口
FIREWALL_EXTRA_PORTS="80,443"
```

完整的配置说明请参考 [配置文档](CONFIGURATION.md)。

## 🔧 高级用法

### 只执行特定模块

```bash
# 只配置 SSH 和防火墙
sudo ./install.sh --modules ssh,firewall
```

### 使用不同的配置文件

```bash
# 生产环境配置
sudo ./install.sh --config config/production.conf

# 开发环境配置
sudo ./install.sh --config config/development.conf
```

### 非交互模式

```bash
# 完全使用配置文件中的值，不询问用户
sudo ./install.sh --config config/myserver.conf
```

## ⚠️ 重要提示

### 1. 在执行脚本前

- ✅ 准备好你的 SSH 公钥
- ✅ 确认服务器可以正常访问互联网
- ✅ 如果是生产环境，建议先在测试环境验证

### 2. 执行脚本时

- 📝 记录下设置的 SSH 端口号
- 📝 记录下创建的用户名
- 🔒 不要关闭当前 SSH 会话

### 3. 执行脚本后

- ✅ **立即在新终端测试 SSH 连接**
- ✅ 确认可以使用密钥登录
- ✅ 验证 sudo 权限正常
- ✅ 只有测试成功后才能关闭原会话

### 测试连接

```bash
# 在另一个终端窗口测试
ssh -p <SSH_PORT> <USERNAME>@<SERVER_IP>

# 测试 sudo 权限
sudo whoami
```

## 🔍 故障排查

### 无法连接 SSH

1. 检查 SSH 端口是否正确
2. 检查防火墙是否放行了 SSH 端口
3. 检查 SSH 服务是否运行：`systemctl status ssh`

### 密钥认证失败

1. 检查 `~/.ssh/authorized_keys` 权限（应为 600）
2. 检查 `~/.ssh` 目录权限（应为 700）
3. 查看 SSH 日志：`journalctl -u ssh -f`

### 用户没有 sudo 权限

```bash
# 以 root 身份重新添加
usermod -aG sudo <username>
```

更多故障排查信息，请参考 [故障排查文档](TROUBLESHOOTING.md)。

## 📚 下一步

- 阅读 [配置文档](CONFIGURATION.md) 了解所有配置选项
- 阅读 [模块文档](MODULES.md) 了解各个模块的功能
- 查看 [常见问题](FAQ.md) 解决常见疑问

## 💡 提示和技巧

### 生成 SSH 密钥

如果你还没有 SSH 密钥：

```bash
# 生成 ED25519 密钥（推荐）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 查看公钥
cat ~/.ssh/id_ed25519.pub
```

### 批量部署多台服务器

为每台服务器创建一个配置文件：

```bash
config/
├── server-01.conf
├── server-02.conf
└── server-03.conf
```

然后依次执行：

```bash
for conf in config/server-*.conf; do
    ssh root@<server-ip> 'bash -s' < install.sh -- --config "$conf"
done
```

## 🆘 获取帮助

- 查看命令帮助：`./install.sh --help`
- 提交 Issue: https://github.com/deltacarre/vps_configuration/issues
- 查看文档: https://github.com/deltacarre/vps_configuration/tree/main/docs
