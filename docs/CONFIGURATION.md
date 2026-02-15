# 配置说明

本文档详细说明所有可用的配置选项。

## 📁 配置文件位置

- `config/default.conf` - 默认配置（交互模式）
- `config/template.conf` - 配置模板（包含所有选项和注释）
- `config/production.conf.example` - 生产环境示例

## 🔧 配置项详解

### 用户配置

#### VPS_USER
- **类型**: 字符串
- **必需**: 是
- **默认值**: `admin`
- **说明**: 要创建或使用的系统用户名
- **示例**: `VPS_USER="deploy"`

#### VPS_HOSTNAME
- **类型**: 字符串
- **必需**: 否
- **默认值**: 空（保持当前主机名）
- **说明**: 新的主机名，留空则不修改
- **示例**: `VPS_HOSTNAME="web-server-01"`

---

### SSH 配置

#### SSH_PUBKEY
- **类型**: 字符串
- **必需**: 是（如果启用 SSH 加固）
- **默认值**: 空
- **说明**: SSH 公钥内容，用于密钥认证
- **示例**: 
  ```bash
  SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host"
  ```

#### SSH_PUBKEY_FILE
- **类型**: 文件路径
- **必需**: 否
- **默认值**: 空
- **说明**: SSH 公钥文件路径，如果设置了 SSH_PUBKEY 则忽略此项
- **示例**: 
  ```bash
  SSH_PUBKEY_FILE="~/.ssh/id_ed25519.pub"
  ```

#### SSH_PORT
- **类型**: 数字
- **必需**: 否
- **默认值**: `22`
- **说明**: SSH 端口号
- **范围**: 1-65535（建议 1024-65535）
- **示例**: `SSH_PORT="2222"`

#### SSH_CHANGE_PORT
- **类型**: yes/no
- **必需**: 否
- **默认值**: `no`
- **说明**: 是否修改 SSH 端口
- **示例**: `SSH_CHANGE_PORT="yes"`

#### SSH_DISABLE_ROOT
- **类型**: yes/no
- **必需**: 否
- **默认值**: `yes`
- **说明**: 是否禁止 root 通过 SSH 登录
- **建议**: 生产环境设为 `yes`
- **示例**: `SSH_DISABLE_ROOT="yes"`

#### SSH_DISABLE_PASSWORD
- **类型**: yes/no
- **必需**: 否
- **默认值**: `yes`
- **说明**: 是否禁用密码登录（强制使用密钥）
- **建议**: 生产环境设为 `yes`
- **示例**: `SSH_DISABLE_PASSWORD="yes"`

---

### 防火墙配置

#### FIREWALL_EXTRA_PORTS
- **类型**: 字符串（逗号分隔）
- **必需**: 否
- **默认值**: 空
- **说明**: 除 SSH 外需要开放的端口
- **示例**: 
  ```bash
  FIREWALL_EXTRA_PORTS="80,443,8080"
  ```

---

### Fail2ban 配置

#### F2B_MAXRETRY
- **类型**: 数字
- **必需**: 否
- **默认值**: `5`
- **说明**: 触发封禁前的最大失败尝试次数
- **建议**: 生产环境可设为 3-5
- **示例**: `F2B_MAXRETRY="3"`

#### F2B_FINDTIME
- **类型**: 时间字符串
- **必需**: 否
- **默认值**: `10m`
- **说明**: 查找失败尝试的时间窗口
- **格式**: s(秒), m(分), h(小时), d(天)
- **示例**: `F2B_FINDTIME="15m"`

#### F2B_BANTIME
- **类型**: 时间字符串
- **必需**: 否
- **默认值**: `6h`
- **说明**: 封禁持续时间
- **格式**: s(秒), m(分), h(小时), d(天)
- **示例**: `F2B_BANTIME="24h"`

---

### 时区配置

#### TIMEZONE
- **类型**: 字符串
- **必需**: 否
- **默认值**: `Asia/Hong_Kong`
- **说明**: 系统时区
- **示例**: 
  ```bash
  TIMEZONE="Asia/Shanghai"
  TIMEZONE="America/New_York"
  TIMEZONE="Europe/London"
  ```
- **查看所有时区**: `timedatectl list-timezones`

---

### Swap 配置

#### SWAP_CREATE
- **类型**: yes/no
- **必需**: 否
- **默认值**: `no`
- **说明**: 是否创建 swapfile
- **建议**: 内存 < 2GB 建议启用
- **示例**: `SWAP_CREATE="yes"`

#### SWAP_SIZE
- **类型**: 大小字符串
- **必需**: 否
- **默认值**: `2G`
- **说明**: Swapfile 大小
- **格式**: M(MB), G(GB)
- **建议**: 
  - 内存 < 2GB: 2G
  - 内存 2-4GB: 2-4G
  - 内存 > 4GB: 按需设置
- **示例**: 
  ```bash
  SWAP_SIZE="1G"
  SWAP_SIZE="2048M"
  ```

#### SWAP_SWAPPINESS
- **类型**: 数字
- **必需**: 否
- **默认值**: `10`
- **说明**: 使用 swap 的倾向（0-100）
- **建议**: 
  - 服务器: 10
  - 桌面: 60
- **示例**: `SWAP_SWAPPINESS="10"`

#### SWAP_CACHE_PRESSURE
- **类型**: 数字
- **必需**: 否
- **默认值**: `50`
- **说明**: 缓存压力（0-100）
- **建议**: 保持默认值 50
- **示例**: `SWAP_CACHE_PRESSURE="50"`

---

### 模块启用开关

以下配置项控制各个功能模块是否执行：

#### ENABLE_USER_SETUP
- **默认值**: `yes`
- **说明**: 启用用户管理模块

#### ENABLE_HOSTNAME_SETUP
- **默认值**: `yes`
- **说明**: 启用主机名设置模块

#### ENABLE_PACKAGE_INSTALL
- **默认值**: `yes`
- **说明**: 启用软件包安装模块

#### ENABLE_SSH_HARDENING
- **默认值**: `yes`
- **说明**: 启用 SSH 安全加固模块

#### ENABLE_FIREWALL
- **默认值**: `yes`
- **说明**: 启用防火墙配置模块

#### ENABLE_FAIL2BAN
- **默认值**: `yes`
- **说明**: 启用 Fail2ban 模块

#### ENABLE_TIMEZONE
- **默认值**: `yes`
- **说明**: 启用时区设置模块

#### ENABLE_APT_OPTIMIZATION
- **默认值**: `yes`
- **说明**: 启用 APT 优化模块

#### ENABLE_SWAP
- **默认值**: `yes`
- **说明**: 启用 Swap 优化模块

#### ENABLE_BBR
- **默认值**: `yes`
- **说明**: 启用 BBR 网络优化模块

---

### 高级配置

#### INTERACTIVE_MODE
- **类型**: yes/no
- **必需**: 否
- **默认值**: `yes`
- **说明**: 是否启用交互模式
- **区别**:
  - `yes`: 脚本会询问用户输入
  - `no`: 完全使用配置文件中的值
- **示例**: `INTERACTIVE_MODE="no"`

#### VERBOSE
- **类型**: yes/no
- **必需**: 否
- **默认值**: `yes`
- **说明**: 是否显示详细输出
- **示例**: `VERBOSE="yes"`

#### CREATE_REPORT
- **类型**: yes/no
- **必需**: 否
- **默认值**: `yes`
- **说明**: 是否生成系统报告
- **示例**: `CREATE_REPORT="yes"`

#### REPORT_PATH
- **类型**: 文件路径
- **必需**: 否
- **默认值**: `/root/vps_init_report.txt`
- **说明**: 系统报告保存路径
- **示例**: `REPORT_PATH="/var/log/vps_init_$(date +%Y%m%d).txt"`

---

## 📋 配置示例

### 基础配置（个人开发环境）

```bash
VPS_USER="dev"
VPS_HOSTNAME="dev-server"
SSH_PUBKEY="ssh-ed25519 AAAA... dev@laptop"
SSH_PORT="22"
TIMEZONE="Asia/Shanghai"
SWAP_CREATE="yes"
SWAP_SIZE="2G"
```

### 生产环境配置

```bash
VPS_USER="deploy"
VPS_HOSTNAME="prod-web-01"
SSH_PUBKEY="ssh-ed25519 AAAA... ops@workstation"
SSH_PORT="2222"
SSH_CHANGE_PORT="yes"
SSH_DISABLE_ROOT="yes"
SSH_DISABLE_PASSWORD="yes"
FIREWALL_EXTRA_PORTS="80,443"
F2B_MAXRETRY="3"
F2B_BANTIME="24h"
TIMEZONE="Asia/Hong_Kong"
SWAP_CREATE="yes"
SWAP_SIZE="4G"
INTERACTIVE_MODE="no"
```

### 最小配置

```bash
VPS_USER="admin"
SSH_PUBKEY="ssh-ed25519 AAAA... user@host"
```

---

## 🔍 配置验证

创建配置文件后，可以使用以下命令验证：

```bash
# 检查语法错误
bash -n config/myconfig.conf

# 查看将要使用的配置
source config/myconfig.conf
env | grep -E '^(VPS_|SSH_|SWAP_|ENABLE_)'
```

---

## 💡 最佳实践

1. **始终设置 SSH 公钥**: 这是最重要的安全措施
2. **修改默认 SSH 端口**: 可以减少自动化扫描
3. **启用所有安全模块**: 特别是 Fail2ban 和防火墙
4. **使用配置文件**: 便于管理和重复部署
5. **保存配置文件**: 用于后续维护和记录

## 📚 相关文档

- [安装指南](INSTALLATION.md)
- [模块文档](MODULES.md)
- [故障排查](TROUBLESHOOTING.md)
- [常见问题](FAQ.md)
