#!/bin/bash
# SSH 安全加固模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# SSH 配置目录
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_PORT_CONFIG="$SSH_CONFIG_DIR/98-vps-port.conf"
SSH_HARDENING_CONFIG="$SSH_CONFIG_DIR/99-vps-hardening.conf"

# SSH 安全加固主函数
ssh_hardening() {
    local username="$1"
    local ssh_pubkey="$2"
    local ssh_port="${3:-}"
    local interactive="${4:-false}"
    
    log_step "SSH 安全加固"
    
    # 验证用户存在
    if ! user_exists "$username"; then
        log_error "用户不存在: $username"
        return 1
    fi
    
    # 获取当前 SSH 端口
    local current_port
    current_port=$(get_ssh_port)
    log_info "当前 SSH 端口: $current_port"
    
    # 配置 SSH 公钥
    if ! setup_ssh_key "$username" "$ssh_pubkey" "$interactive"; then
        log_error "SSH 公钥配置失败"
        log_warn "为避免锁死，不进行 SSH 加固"
        return 1
    fi
    
    # 配置 SSH 端口（可选）
    if [ "$interactive" = "true" ]; then
        if confirm "是否要修改 SSH 端口？"; then
            read -rp "请输入新的 SSH 端口（1024-65535）: " ssh_port
        fi
    fi
    
    if [ -n "$ssh_port" ]; then
        if validate_port "$ssh_port"; then
            configure_ssh_port "$ssh_port"
            current_port="$ssh_port"
        else
            log_warn "端口号不合法，跳过端口修改"
        fi
    fi
    
    # 应用安全配置
    apply_ssh_hardening "$username"
    
    # 重载 SSH 服务
    reload_ssh_service
    
    log_success "SSH 安全加固完成"
    log_warn "⚠️ 重要提示: 请在新终端测试 SSH 连接"
    log_info "测试命令: ssh -p $current_port $username@<SERVER_IP>"
    
    # 返回当前端口（供防火墙使用）
    echo "$current_port"
    return 0
}

# 配置 SSH 公钥
setup_ssh_key() {
    local username="$1"
    local ssh_pubkey="$2"
    local interactive="${3:-false}"
    
    log_info "配置 SSH 公钥认证"
    
    # 交互模式下询问公钥
    if [ -z "$ssh_pubkey" ] && [ "$interactive" = "true" ]; then
        echo "请粘贴你的 SSH 公钥（例如: ssh-ed25519 AAAA...）"
        read -rp "SSH 公钥: " ssh_pubkey
    fi
    
    # 验证公钥是否提供
    if [ -z "$ssh_pubkey" ]; then
        log_error "未提供 SSH 公钥"
        return 1
    fi
    
    # 简单验证公钥格式
    if [[ ! "$ssh_pubkey" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ]]; then
        log_error "SSH 公钥格式不正确"
        return 1
    fi
    
    local user_home="/home/$username"
    local ssh_dir="$user_home/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    # 创建 .ssh 目录
    ensure_directory "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # 检查公钥是否已存在
    if [ -f "$auth_keys" ] && grep -Fxq "$ssh_pubkey" "$auth_keys"; then
        log_info "SSH 公钥已存在，跳过添加"
    else
        # 添加公钥
        echo "$ssh_pubkey" >> "$auth_keys"
        log_success "SSH 公钥已添加"
    fi
    
    # 设置正确的权限
    chmod 600 "$auth_keys"
    chown -R "$username:$username" "$ssh_dir"
    
    log_success "SSH 公钥配置完成"
    return 0
}

# 配置 SSH 端口
configure_ssh_port() {
    local new_port="$1"
    
    log_info "配置 SSH 端口: $new_port"
    
    ensure_directory "$SSH_CONFIG_DIR"
    
    cat > "$SSH_PORT_CONFIG" <<EOF
# Managed by VPS Configuration Script
# Generated: $(date)
Port $new_port
EOF
    
    log_success "SSH 端口已配置: $new_port"
}

# 应用 SSH 安全加固配置
apply_ssh_hardening() {
    local username="$1"
    
    log_info "应用 SSH 安全加固配置"
    
    ensure_directory "$SSH_CONFIG_DIR"
    
    # 备份现有配置
    [ -f "$SSH_HARDENING_CONFIG" ] && backup_file "$SSH_HARDENING_CONFIG"
    
    cat > "$SSH_HARDENING_CONFIG" <<EOF
# Managed by VPS Configuration Script
# Generated: $(date)

# 启用公钥认证
PubkeyAuthentication yes

# 禁用密码认证
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no

# 禁止 root 登录
PermitRootLogin no

# 只允许指定用户登录
AllowUsers $username

# 使用 PAM
UsePAM yes

# 其他安全设置
X11Forwarding no
MaxAuthTries 3
MaxSessions 2
EOF
    
    log_success "SSH 安全配置已写入"
}

# 重载 SSH 服务
reload_ssh_service() {
    log_info "重载 SSH 服务"
    
    # 先测试配置
    if sshd -t 2>/dev/null; then
        log_success "SSH 配置测试通过"
    else
        log_error "SSH 配置测试失败"
        return 1
    fi
    
    # 重载服务
    if systemctl reload ssh 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        log_success "SSH 服务已重载"
    else
        log_error "SSH 服务重载失败"
        return 1
    fi
    
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    USERNAME="${1:-}"
    SSH_KEY="${2:-}"
    SSH_PORT="${3:-}"
    
    if [ -z "$USERNAME" ]; then
        log_error "用法: $0 <username> [ssh_pubkey] [ssh_port]"
        exit 1
    fi
    
    ssh_hardening "$USERNAME" "$SSH_KEY" "$SSH_PORT" "true"
fi
