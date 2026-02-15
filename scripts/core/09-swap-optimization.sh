#!/bin/bash
# Swap 交换空间优化模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# Sysctl 配置文件
SYSCTL_SWAP_CONFIG="/etc/sysctl.d/99-vps-swap.conf"
SWAPFILE_PATH="/swapfile"

# Swap 优化主函数
setup_swap_optimization() {
    local create_swap="${1:-false}"
    local swap_size="${2:-2G}"
    local swappiness="${3:-10}"
    local cache_pressure="${4:-50}"
    
    log_step "Swap 优化配置"
    
    # 配置 sysctl 参数
    configure_swap_sysctl "$swappiness" "$cache_pressure"
    
    # 检查是否需要创建 swapfile
    if [ "$create_swap" = "true" ]; then
        create_swapfile "$swap_size"
    else
        # 检查现有 swap
        if swapon --show | grep -q .; then
            log_info "系统已有 Swap 配置:"
            swapon --show
        else
            log_warn "系统当前没有 Swap"
            log_info "如需创建，请运行: $0 true <size>"
        fi
    fi
    
    log_success "Swap 优化配置完成"
    return 0
}

# 配置 swap 相关的 sysctl 参数
configure_swap_sysctl() {
    local swappiness="$1"
    local cache_pressure="$2"
    
    log_info "配置 Swap 内核参数"
    
    # 备份现有配置
    [ -f "$SYSCTL_SWAP_CONFIG" ] && backup_file "$SYSCTL_SWAP_CONFIG"
    
    cat > "$SYSCTL_SWAP_CONFIG" <<EOF
# Managed by VPS Configuration Script
# Generated: $(date)

# Swap 使用倾向 (0-100)
# 值越低，越倾向使用物理内存
# 推荐值: 10（服务器）, 60（桌面）
vm.swappiness=$swappiness

# 缓存压力 (0-100)
# 值越低，越倾向保留目录和 inode 缓存
# 推荐值: 50
vm.vfs_cache_pressure=$cache_pressure
EOF
    
    log_success "Swap 参数配置已写入: $SYSCTL_SWAP_CONFIG"
    
    # 应用配置
    log_info "应用 sysctl 配置..."
    sysctl --system >/dev/null 2>&1
    
    # 验证配置
    local current_swappiness
    local current_pressure
    current_swappiness=$(sysctl -n vm.swappiness 2>/dev/null || echo "N/A")
    current_pressure=$(sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo "N/A")
    
    log_info "当前配置:"
    echo "  ✓ vm.swappiness: $current_swappiness"
    echo "  ✓ vm.vfs_cache_pressure: $current_pressure"
    
    return 0
}

# 创建 swapfile
create_swapfile() {
    local swap_size="$1"
    
    log_step "创建 Swapfile"
    
    # 检查是否已存在 swapfile
    if [ -f "$SWAPFILE_PATH" ]; then
        log_warn "Swapfile 已存在: $SWAPFILE_PATH"
        
        if swapon --show | grep -q "$SWAPFILE_PATH"; then
            log_info "Swapfile 已启用"
            swapon --show | grep "$SWAPFILE_PATH"
            return 0
        else
            log_warn "Swapfile 存在但未启用，将重新配置"
            rm -f "$SWAPFILE_PATH"
        fi
    fi
    
    # 检查当前是否有 swap
    if swapon --show | grep -q .; then
        log_warn "系统已有 Swap 配置:"
        swapon --show
        
        if ! confirm "是否继续创建新的 swapfile？"; then
            log_info "跳过 swapfile 创建"
            return 0
        fi
    fi
    
    log_info "创建 swapfile: $swap_size"
    
    # 获取可用磁盘空间
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    log_info "根分区可用空间: $((available_space / 1024)) MB"
    
    # 创建 swapfile
    log_info "正在创建 swapfile（这可能需要一些时间）..."
    
    # 尝试使用 fallocate（更快）
    if fallocate -l "$swap_size" "$SWAPFILE_PATH" 2>/dev/null; then
        log_success "使用 fallocate 创建 swapfile"
    else
        # 备用方法：使用 dd
        log_info "使用 dd 创建 swapfile..."
        local size_mb
        size_mb=$(echo "$swap_size" | sed 's/G/*1024/' | sed 's/M//' | bc 2>/dev/null || echo "2048")
        dd if=/dev/zero of="$SWAPFILE_PATH" bs=1M count="$size_mb" status=progress
    fi
    
    # 设置权限
    log_info "设置 swapfile 权限"
    chmod 600 "$SWAPFILE_PATH"
    
    # 格式化为 swap
    log_info "格式化 swapfile"
    mkswap "$SWAPFILE_PATH"
    
    # 启用 swap
    log_info "启用 swapfile"
    swapon "$SWAPFILE_PATH"
    
    # 添加到 fstab
    if ! grep -q "^$SWAPFILE_PATH" /etc/fstab; then
        log_info "添加到 /etc/fstab（开机自动挂载）"
        echo "$SWAPFILE_PATH none swap sw 0 0" >> /etc/fstab
    else
        log_info "Swapfile 已在 /etc/fstab 中"
    fi
    
    # 显示 swap 状态
    log_success "Swapfile 创建完成"
    echo ""
    swapon --show
    echo ""
    free -h
    
    return 0
}

# 删除 swapfile
remove_swapfile() {
    log_step "删除 Swapfile"
    
    if [ ! -f "$SWAPFILE_PATH" ]; then
        log_warn "Swapfile 不存在: $SWAPFILE_PATH"
        return 1
    fi
    
    log_warn "即将删除 swapfile: $SWAPFILE_PATH"
    
    # 禁用 swap
    if swapon --show | grep -q "$SWAPFILE_PATH"; then
        log_info "禁用 swapfile..."
        swapoff "$SWAPFILE_PATH"
    fi
    
    # 从 fstab 中移除
    if grep -q "^$SWAPFILE_PATH" /etc/fstab; then
        log_info "从 /etc/fstab 中移除..."
        sed -i "\|^$SWAPFILE_PATH|d" /etc/fstab
    fi
    
    # 删除文件
    log_info "删除 swapfile 文件..."
    rm -f "$SWAPFILE_PATH"
    
    log_success "Swapfile 已删除"
    return 0
}

# 显示 swap 状态
show_swap_status() {
    log_step "Swap 状态"
    
    echo "=== Swap 设备 ==="
    if swapon --show | grep -q .; then
        swapon --show
    else
        echo "（无 Swap）"
    fi
    
    echo ""
    echo "=== 内存使用 ==="
    free -h
    
    echo ""
    echo "=== Swap 参数 ==="
    echo "vm.swappiness: $(sysctl -n vm.swappiness 2>/dev/null || echo 'N/A')"
    echo "vm.vfs_cache_pressure: $(sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo 'N/A')"
    
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    ACTION="${1:-setup}"
    
    case "$ACTION" in
        setup)
            SWAPPINESS="${2:-10}"
            CACHE_PRESSURE="${3:-50}"
            setup_swap_optimization "false" "" "$SWAPPINESS" "$CACHE_PRESSURE"
            ;;
        create)
            SIZE="${2:-2G}"
            SWAPPINESS="${3:-10}"
            CACHE_PRESSURE="${4:-50}"
            setup_swap_optimization "true" "$SIZE" "$SWAPPINESS" "$CACHE_PRESSURE"
            ;;
        remove)
            remove_swapfile
            ;;
        status)
            show_swap_status
            ;;
        *)
            log_error "未知操作: $ACTION"
            echo "用法: $0 {setup|create <size>|remove|status}"
            echo ""
            echo "示例:"
            echo "  $0 setup              # 只配置参数，不创建 swap"
            echo "  $0 create 2G          # 创建 2GB swapfile"
            echo "  $0 remove             # 删除 swapfile"
            echo "  $0 status             # 显示 swap 状态"
            exit 1
            ;;
    esac
fi
