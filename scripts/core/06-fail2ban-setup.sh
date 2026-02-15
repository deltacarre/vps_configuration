#!/bin/bash
# Fail2ban 防暴力破解模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# Fail2ban 配置文件
F2B_JAIL_DIR="/etc/fail2ban/jail.d"
F2B_SSHD_CONFIG="$F2B_JAIL_DIR/sshd.local"

# 配置 Fail2ban
setup_fail2ban() {
    local ssh_port="${1:-22}"
    local max_retry="${2:-5}"
    local find_time="${3:-10m}"
    local ban_time="${4:-6h}"
    
    log_step "配置 Fail2ban 防暴力破解"
    
    # 检查 Fail2ban 是否安装
    if ! command_exists fail2ban-client; then
        log_error "Fail2ban 未安装"
        return 1
    fi
    
    log_info "配置参数:"
    echo "  - SSH 端口: $ssh_port"
    echo "  - 最大重试: $max_retry 次"
    echo "  - 查找时间: $find_time"
    echo "  - 封禁时间: $ban_time"
    
    # 创建配置目录
    ensure_directory "$F2B_JAIL_DIR"
    
    # 备份现有配置
    [ -f "$F2B_SSHD_CONFIG" ] && backup_file "$F2B_SSHD_CONFIG"
    
    # 写入 SSHD 配置
    log_info "写入 Fail2ban SSHD 配置"
    cat > "$F2B_SSHD_CONFIG" <<EOF
# Managed by VPS Configuration Script
# Generated: $(date)

[sshd]
# 启用 SSHD 监控
enabled = true

# SSH 端口
port = $ssh_port

# 日志后端（使用 systemd）
backend = systemd

# 封禁动作（配合 UFW）
banaction = ufw

# 最大重试次数
maxretry = $max_retry

# 查找时间窗口
findtime = $find_time

# 封禁时间
bantime = $ban_time

# 日志路径（systemd 会自动处理）
# logpath = /var/log/auth.log
EOF
    
    log_success "Fail2ban 配置已写入"
    
    # 启用并启动服务
    log_info "启用 Fail2ban 服务"
    systemctl enable fail2ban
    
    log_info "重启 Fail2ban 服务"
    systemctl restart fail2ban
    
    # 等待服务启动
    sleep 2
    
    # 检查状态
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban 服务运行正常"
    else
        log_error "Fail2ban 服务启动失败"
        return 1
    fi
    
    # 显示 SSHD jail 状态
    log_info "Fail2ban SSHD 监控状态:"
    fail2ban-client status sshd 2>/dev/null || log_warn "SSHD jail 尚未初始化（正常）"
    
    log_success "Fail2ban 配置完成"
    return 0
}

# 显示 Fail2ban 状态
show_fail2ban_status() {
    log_step "Fail2ban 状态"
    
    if ! command_exists fail2ban-client; then
        log_error "Fail2ban 未安装"
        return 1
    fi
    
    # 服务状态
    echo "=== 服务状态 ==="
    systemctl status fail2ban --no-pager || true
    echo ""
    
    # Jail 列表
    echo "=== 活动 Jails ==="
    fail2ban-client status || true
    echo ""
    
    # SSHD 详细状态
    echo "=== SSHD Jail 详情 ==="
    fail2ban-client status sshd 2>/dev/null || echo "SSHD jail 未启用"
    
    return 0
}

# 解封 IP
unban_ip() {
    local ip="$1"
    local jail="${2:-sshd}"
    
    if [ -z "$ip" ]; then
        log_error "请提供要解封的 IP 地址"
        return 1
    fi
    
    log_info "解封 IP: $ip (jail: $jail)"
    fail2ban-client set "$jail" unbanip "$ip"
    
    log_success "IP 已解封: $ip"
    return 0
}

# 查看被封禁的 IP
show_banned_ips() {
    local jail="${1:-sshd}"
    
    log_step "被封禁的 IP 列表 (jail: $jail)"
    
    if ! fail2ban-client status "$jail" &>/dev/null; then
        log_error "Jail 不存在或未启用: $jail"
        return 1
    fi
    
    fail2ban-client status "$jail" | grep "Banned IP"
    
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    SSH_PORT="${1:-22}"
    MAX_RETRY="${2:-5}"
    FIND_TIME="${3:-10m}"
    BAN_TIME="${4:-6h}"
    
    setup_fail2ban "$SSH_PORT" "$MAX_RETRY" "$FIND_TIME" "$BAN_TIME"
fi
