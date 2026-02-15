#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 运行此脚本"
  exit 1
fi

log() { echo -e "\n[INFO] $1"; }
warn() { echo -e "\n[WARN] $1"; }

get_ssh_port() {
  local port="22"
  if [ -d /etc/ssh/sshd_config.d ]; then
    local p
    p=$(grep -RhsE '^\s*Port\s+' /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | tail -n1 || true)
    if [ -n "${p:-}" ]; then port="$p"; fi
  fi
  local p2
  p2=$(grep -E '^\s*Port\s+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -n1 || true)
  if [ -n "${p2:-}" ]; then port="$p2"; fi
  echo "$port"
}

CURRENT_SSH_PORT="$(get_ssh_port)"

echo "====== VPS 初始化开始 (Debian 12) ======"
log "检测到当前 SSH 端口：$CURRENT_SSH_PORT"

# 1) 输入用户名：若不存在则创建；若已存在则跳过创建但继续使用该用户名
read -rp "请输入要使用/创建的用户名: " NEWUSER
if id "$NEWUSER" &>/dev/null; then
  log "用户已存在：$NEWUSER —— 跳过创建步骤，继续后续配置。"
else
  log "创建用户：$NEWUSER"
  adduser "$NEWUSER"

  log "创建用户常用目录"
  mkdir -p "/home/$NEWUSER"/{project,workspace,data,script}
  chown -R "$NEWUSER:$NEWUSER" "/home/$NEWUSER"
fi

# 如果用户存在但 home 目录缺失（极少数情况），补齐
if [ ! -d "/home/$NEWUSER" ]; then
  warn "检测到 /home/$NEWUSER 不存在，尝试创建并修复权限"
  mkdir -p "/home/$NEWUSER"
  chown "$NEWUSER:$NEWUSER" "/home/$NEWUSER"
fi

# 2) 加 sudo（重复执行无害）
log "将用户加入 sudo 组（若已加入则不会重复影响）"
usermod -aG sudo "$NEWUSER"

# 3) hostname（可选）
read -rp "请输入新的 hostname（留空跳过）: " NEWHOST
if [ -n "${NEWHOST:-}" ]; then
  log "设置 hostname 为：$NEWHOST"
  hostnamectl set-hostname "$NEWHOST"
else
  log "跳过 hostname 修改"
fi

# 4) 安装基础工具 + fail2ban
log "更新 apt 缓存并安装：curl git vim htop ufw fail2ban"
apt-get update -y
apt-get install -y curl git vim htop ufw ca-certificates fail2ban

# 5) 时区
log "设置时区：Asia/Hong_Kong"
timedatectl set-timezone "Asia/Hong_Kong"

# 6) APT 优化
log "写入 APT 优化配置 /etc/apt/apt.conf.d/99-vps-optim"
cat >/etc/apt/apt.conf.d/99-vps-optim <<'EOF'
Acquire::Retries "5";
Acquire::http::Timeout "10";
Acquire::https::Timeout "10";
Acquire::Queue-Mode "access";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

# 7) SSH 强化（关键：强制只允许 NEWUSER 登录；root 禁止 SSH）
log "SSH 加固：将强制仅允许用户 $NEWUSER SSH 登录（root 禁止 SSH）"
echo "⚠️ 你必须提供 SSH 公钥，否则无法完成“仅允许 key 登录”的加固。"
read -rp "请粘贴你的 SSH 公钥（必填，例如 ssh-ed25519 AAAA...）: " SSH_PUBKEY
if [ -z "${SSH_PUBKEY:-}" ]; then
  warn "未提供公钥。为避免锁死，本脚本退出且不做 SSH 改动。"
  exit 1
fi

# 给 NEWUSER 写公钥（可重复追加；如不想重复可先手动去重）
log "配置 $NEWUSER 的 SSH 公钥登录"
mkdir -p "/home/$NEWUSER/.ssh"
chmod 700 "/home/$NEWUSER/.ssh"
echo "$SSH_PUBKEY" >>"/home/$NEWUSER/.ssh/authorized_keys"
chmod 600 "/home/$NEWUSER/.ssh/authorized_keys"
chown -R "$NEWUSER:$NEWUSER" "/home/$NEWUSER/.ssh"

# 可选改端口
read -rp "是否要修改 SSH 端口？(y/N): " CHANGE_PORT
CHANGE_PORT="${CHANGE_PORT:-N}"
if [[ "$CHANGE_PORT" =~ ^[Yy]$ ]]; then
  read -rp "请输入新的 SSH 端口（1024-65535）: " NEWPORT
  if [[ "$NEWPORT" =~ ^[0-9]+$ ]] && [ "$NEWPORT" -ge 1024 ] && [ "$NEWPORT" -le 65535 ]; then
    log "设置 SSH 端口为：$NEWPORT"
    mkdir -p /etc/ssh/sshd_config.d
    cat >/etc/ssh/sshd_config.d/98-vps-port.conf <<EOF
# Managed by init_vps.sh
Port $NEWPORT
EOF
    CURRENT_SSH_PORT="$NEWPORT"
  else
    warn "端口不合法，跳过端口修改"
  fi
fi

# SSH drop-in：只允许 NEWUSER；root 禁止；禁用密码；启用公钥
log "写入 SSH 加固配置 /etc/ssh/sshd_config.d/99-vps-hardening.conf"
mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-vps-hardening.conf <<EOF
# Managed by init_vps.sh
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no

# 禁止 root SSH 登录（无论密码/密钥）
PermitRootLogin no

# 只允许指定用户登录（强制）
AllowUsers $NEWUSER

UsePAM yes
EOF

# 重新加载 ssh
log "重载 SSH 服务"
systemctl reload ssh || systemctl restart ssh

# 8) UFW：放行 SSH 端口并启用
log "配置 UFW：放行 SSH 端口并启用防火墙"
ufw allow "${CURRENT_SSH_PORT}/tcp" >/dev/null || true
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# 9) Swap 优化（sysctl + 可选创建 swapfile）
log "Swap 优化：swappiness 等"
cat >/etc/sysctl.d/99-vps-swap.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
sysctl --system >/dev/null

if ! swapon --show | grep -q .; then
  warn "检测到当前没有启用 swap。"
  read -rp "是否创建 swapfile？(y/N): " CREATE_SWAP
  CREATE_SWAP="${CREATE_SWAP:-N}"
  if [[ "$CREATE_SWAP" =~ ^[Yy]$ ]]; then
    read -rp "请输入 swap 大小（例如 1G/2G，默认 2G）: " SWAPSIZE
    SWAPSIZE="${SWAPSIZE:-2G}"
    log "创建 swapfile：$SWAPSIZE"
    fallocate -l "$SWAPSIZE" /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    log "swapfile 已启用"
  else
    log "跳过创建 swapfile"
  fi
else
  log "已存在 swap，跳过创建"
fi

# 10) 开启 BBR
log "开启 BBR（fq + bbr）"
cat >/etc/sysctl.d/99-vps-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
modprobe tcp_bbr 2>/dev/null || true
sysctl --system >/dev/null

# 11) fail2ban：sshd 规则（基于日志封禁爆破 IP）
log "配置 fail2ban（sshd）并启用：封禁爆破 IP（配合 UFW）"
mkdir -p /etc/fail2ban/jail.d
cat >/etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ${CURRENT_SSH_PORT}
backend = systemd
banaction = ufw
maxretry = 5
findtime = 10m
bantime  = 6h
EOF

systemctl enable --now fail2ban

log "fail2ban 状态："
fail2ban-client status sshd || true

echo
echo "====== 初始化完成（增强版）====="
echo "SSH 端口: ${CURRENT_SSH_PORT}"
echo "SSH 登录限制：只允许用户 ${NEWUSER} 登录；root 已禁止 SSH"
echo "认证方式：仅允许 SSH key（已禁用密码登录）"
echo "UFW：已启用并放行 SSH 端口"
echo "fail2ban：已启用（sshd 爆破自动封禁）"
echo
echo "⚠️ 重要：现在请【新开一个终端】测试："
echo "   ssh -p ${CURRENT_SSH_PORT} ${NEWUSER}@<你的VPS_IP>"
echo "确认能登录后，再退出当前会话。"
