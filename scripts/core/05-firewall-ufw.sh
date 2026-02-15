#!/bin/bash
# UFW 防火墙配置模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# 配置 UFW 防火墙
setup_firewall() {
    local ssh_port="${1:-22}"
    local additional_ports="${2:-}"
    
    log_step "配置 UFW 防火墙"
    
    # 检查 UFW 是否安装
    if ! command_exists ufw; then
        log_error "UFW 未安装"
        return 1
    fi
    
    log_info "当前 SSH 端口: $ssh_port"
    
    # 重置 UFW（如果需要）
    if ufw status | grep -q "Status: active"; then
        log_info "UFW 已启用，保留现有规则"
    else
        log_info "初始化 UFW 配置"
    fi
    
    # 设置默认策略
    log_info "设置默认策略: 拒绝入站，允许出站"
    ufw default deny incoming
    ufw default allow outgoing
    
    # 放行 SSH 端口
    log_info "放行 SSH 端口: $ssh_port/tcp"
    ufw allow "$ssh_port/tcp" comment 'SSH'
    
    # 放行额外端口（如果有）
    if [ -n "$additional_ports" ]; then
        log_info "放行额外端口: $additional_ports"
        IFS=',' read -ra PORTS <<< "$additional_ports"
        for port in "${PORTS[@]}"; do
            port=$(echo "$port" | xargs)  # 去除空格
            if validate_port "$port"; then
                ufw allow "$port/tcp"
                log_info "  ✓ 已放行: $port/tcp"
            fi
        done
    fi
    
    # 启用 UFW
    log_info "启用 UFW 防火墙"
    echo "y" | ufw enable
    
    # 显示状态
    log_success "UFW 防火墙配置完成"
    echo ""
    ufw status numbered
    
    return 0
}

# 添加防火墙规则
add_firewall_rule() {
    local port="$1"
    local protocol="${2:-tcp}"
    local comment="${3:-Custom rule}"
    
    if ! validate_port "$port"; then
        log_error "无效的端口号: $port"
        return 1
    fi
    
    log_info "添加防火墙规则: $port/$protocol"
    ufw allow "$port/$protocol" comment "$comment"
    
    log_success "规则已添加"
    return 0
}

# 删除防火墙规则
remove_firewall_rule() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    log_info "删除防火墙规则: $port/$protocol"
    ufw delete allow "$port/$protocol"
    
    log_success "规则已删除"
    return 0
}

# 显示防火墙状态
show_firewall_status() {
    log_step "UFW 防火墙状态"
    
    if ! command_exists ufw; then
        log_error "UFW 未安装"
        return 1
    fi
    
    ufw status verbose
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    SSH_PORT="${1:-22}"
    EXTRA_PORTS="${2:-}"
    
    setup_firewall "$SSH_PORT" "$EXTRA_PORTS"
fi
