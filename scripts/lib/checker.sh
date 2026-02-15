#!/bin/bash
# 系统检查函数库

# 检查系统必需条件
check_prerequisites() {
    log_step "检查系统前置条件"
    
    # 检查是否为 root
    require_root
    
    # 检查系统类型
    local os_info
    os_info=$(get_os_info)
    log_info "检测到系统: $os_info"
    
    # 检查系统兼容性
    check_system_compatibility
    
    # 检查网络连接
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log_warn "网络连接检查失败，但继续执行"
    else
        log_success "网络连接正常"
    fi
    
    log_success "前置条件检查完成"
}

# 检查配置文件有效性
validate_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "验证配置文件: $config_file"
    
    # 检查必需配置项
    local required_vars=("VPS_USER")
    for var in "${required_vars[@]}"; do
        local value
        value=$(read_config "$config_file" "$var")
        if [ -z "$value" ]; then
            log_error "配置项缺失: $var"
            return 1
        fi
    done
    
    log_success "配置文件验证通过"
    return 0
}

# 检查 SSH 配置安全性
check_ssh_safety() {
    local user="$1"
    
    log_step "检查 SSH 安全配置"
    
    # 检查用户是否有 authorized_keys
    if [ ! -f "/home/$user/.ssh/authorized_keys" ]; then
        log_error "用户 $user 没有配置 SSH 公钥"
        log_error "为了安全，请先配置 SSH 公钥再禁用密码登录"
        return 1
    fi
    
    # 检查 authorized_keys 权限
    local perms
    perms=$(stat -c %a "/home/$user/.ssh/authorized_keys" 2>/dev/null || echo "000")
    if [ "$perms" != "600" ]; then
        log_warn "SSH authorized_keys 权限不正确: $perms（应该为 600）"
    fi
    
    log_success "SSH 安全检查通过"
    return 0
}

# 生成系统报告
generate_system_report() {
    local report_file="${1:-/tmp/vps_init_report.txt}"
    
    {
        echo "====== VPS 配置报告 ======"
        echo "生成时间: $(date)"
        echo ""
        echo "=== 系统信息 ==="
        echo "OS: $(get_os_info)"
        echo "Kernel: $(uname -r)"
        echo "Hostname: $(hostname)"
        echo ""
        echo "=== SSH 配置 ==="
        echo "SSH 端口: $(get_ssh_port)"
        echo ""
        echo "=== 防火墙状态 ==="
        ufw status 2>/dev/null || echo "UFW 未安装或未启用"
        echo ""
        echo "=== Fail2ban 状态 ==="
        systemctl is-active fail2ban 2>/dev/null || echo "Fail2ban 未运行"
        echo ""
        echo "=== Swap 信息 ==="
        swapon --show || echo "无 Swap"
        echo ""
        echo "=== BBR 状态 ==="
        sysctl net.ipv4.tcp_congestion_control 2>/dev/null || echo "无法检查 BBR"
    } > "$report_file"
    
    log_info "系统报告已生成: $report_file"
}
