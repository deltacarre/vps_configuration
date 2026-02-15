#!/bin/bash
# 软件包安装模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# 默认要安装的软件包
DEFAULT_PACKAGES=(
    "curl"
    "git"
    "vim"
    "htop"
    "ufw"
    "fail2ban"
    "ca-certificates"
)

# 安装基础软件包
install_packages() {
    local packages=("$@")
    
    log_step "安装基础软件包"
    
    # 如果没有指定包，使用默认列表
    if [ ${#packages[@]} -eq 0 ]; then
        packages=("${DEFAULT_PACKAGES[@]}")
    fi
    
    log_info "准备安装以下软件包:"
    for pkg in "${packages[@]}"; do
        echo "  - $pkg"
    done
    
    # 更新包索引
    log_info "更新软件包索引..."
    if ! apt-get update -y; then
        log_error "apt-get update 失败"
        return 1
    fi
    
    # 安装软件包
    log_info "开始安装软件包..."
    if ! apt-get install -y "${packages[@]}"; then
        log_error "软件包安装失败"
        return 1
    fi
    
    log_success "所有软件包安装完成"
    
    # 显示已安装的版本
    log_info "已安装版本:"
    for pkg in "${packages[@]}"; do
        if command_exists "$pkg"; then
            local version
            version=$("$pkg" --version 2>/dev/null | head -n1 || echo "已安装")
            echo "  ✓ $pkg: $version"
        fi
    done
    
    return 0
}

# 清理不需要的包
cleanup_packages() {
    log_step "清理系统"
    
    log_info "清理不需要的软件包..."
    apt-get autoremove -y
    apt-get clean
    
    log_success "系统清理完成"
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    if [ $# -eq 0 ]; then
        install_packages
    else
        install_packages "$@"
    fi
fi
