#!/bin/bash
# 主机名设置模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# 设置主机名
setup_hostname() {
    local new_hostname="$1"
    local interactive="${2:-false}"
    
    log_step "主机名配置"
    
    local current_hostname
    current_hostname=$(hostname)
    log_info "当前主机名: $current_hostname"
    
    # 如果是交互模式且没有提供主机名，询问
    if [ -z "$new_hostname" ] && [ "$interactive" = "true" ]; then
        read -rp "请输入新的主机名（留空跳过）: " new_hostname
    fi
    
    # 如果没有提供主机名，跳过
    if [ -z "$new_hostname" ]; then
        log_info "跳过主机名修改"
        return 0
    fi
    
    # 验证主机名格式（简单验证）
    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        log_error "主机名格式不合法（仅允许字母、数字和连字符）"
        return 1
    fi
    
    log_info "设置主机名为: $new_hostname"
    
    # 使用 hostnamectl 设置
    if command_exists hostnamectl; then
        hostnamectl set-hostname "$new_hostname"
    else
        # 备用方法
        echo "$new_hostname" > /etc/hostname
        hostname "$new_hostname"
    fi
    
    # 更新 /etc/hosts
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1    $new_hostname" >> /etc/hosts
    else
        sed -i "s/^127.0.1.1.*/127.0.1.1    $new_hostname/" /etc/hosts
    fi
    
    log_success "主机名已设置: $new_hostname"
    log_info "注意: 需要重新登录才能看到提示符变化"
    
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    HOSTNAME="${1:-}"
    INTERACTIVE="${2:-true}"
    
    setup_hostname "$HOSTNAME" "$INTERACTIVE"
fi
