#!/bin/bash
# 用户管理模块

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# 创建或验证用户
setup_user() {
    local username="$1"
    local interactive="${2:-false}"
    
    log_step "用户管理配置"
    
    # 如果是交互模式且没有提供用户名，询问
    if [ -z "$username" ] && [ "$interactive" = "true" ]; then
        read -rp "请输入要使用/创建的用户名: " username
    fi
    
    if [ -z "$username" ]; then
        log_error "用户名不能为空"
        return 1
    fi
    
    # 检查用户是否存在
    if user_exists "$username"; then
        log_info "用户已存在: $username —— 跳过创建，继续后续配置"
    else
        log_info "创建新用户: $username"
        
        # 创建用户（交互式输入密码）
        if ! adduser "$username"; then
            log_error "用户创建失败"
            return 1
        fi
        
        log_success "用户创建成功: $username"
    fi
    
    # 确保 home 目录存在
    if [ ! -d "/home/$username" ]; then
        log_warn "检测到 /home/$username 不存在，创建并修复权限"
        mkdir -p "/home/$username"
        chown "$username:$username" "/home/$username"
    fi
    
    # 创建常用目录
    create_user_directories "$username"
    
    # 将用户加入 sudo 组
    add_user_to_sudo "$username"
    
    log_success "用户配置完成: $username"
    echo "$username"
    return 0
}

# 创建用户常用目录
create_user_directories() {
    local username="$1"
    local user_home="/home/$username"
    
    log_info "创建用户常用目录"
    
    local dirs=("project" "workspace" "data" "script")
    for dir in "${dirs[@]}"; do
        local full_path="$user_home/$dir"
        if [ ! -d "$full_path" ]; then
            mkdir -p "$full_path"
            log_info "  ✓ 创建: ~/$dir"
        else
            log_info "  ✓ 已存在: ~/$dir"
        fi
    done
    
    # 修复权限
    chown -R "$username:$username" "$user_home"
    
    log_success "用户目录创建完成"
}

# 将用户加入 sudo 组
add_user_to_sudo() {
    local username="$1"
    
    if groups "$username" | grep -q "\bsudo\b"; then
        log_info "用户已在 sudo 组中: $username"
    else
        log_info "将用户加入 sudo 组: $username"
        usermod -aG sudo "$username"
        log_success "已将 $username 加入 sudo 组"
    fi
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    USERNAME="${1:-}"
    INTERACTIVE="${2:-true}"
    
    setup_user "$USERNAME" "$INTERACTIVE"
fi
