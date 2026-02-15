#!/bin/bash
# APT 优化配置模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# APT 配置文件
APT_CONFIG_FILE="/etc/apt/apt.conf.d/99-vps-optimization"

# 配置 APT 优化
setup_apt_optimization() {
    log_step "APT 下载优化配置"
    
    # 备份现有配置
    [ -f "$APT_CONFIG_FILE" ] && backup_file "$APT_CONFIG_FILE"
    
    log_info "写入 APT 优化配置"
    cat > "$APT_CONFIG_FILE" <<'EOF'
// Managed by VPS Configuration Script
// APT 优化配置

// 自动重试下载
Acquire::Retries "5";

// 设置超时时间
Acquire::http::Timeout "10";
Acquire::https::Timeout "10";
Acquire::ftp::Timeout "10";

// 允许并发下载
Acquire::Queue-Mode "access";

// 配置更新时保留旧配置
Dpkg::Options {
    "--force-confdef";
    "--force-confold";
};

// 减少不必要的建议包安装
APT::Install-Recommends "false";
APT::Install-Suggests "false";

// 自动清理
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
EOF
    
    log_success "APT 优化配置已写入: $APT_CONFIG_FILE"
    
    # 显示配置内容
    log_info "配置内容:"
    echo "  ✓ 自动重试: 5 次"
    echo "  ✓ 连接超时: 10 秒"
    echo "  ✓ 并发下载: 启用"
    echo "  ✓ 保留旧配置: 启用"
    echo "  ✓ 减少建议包: 启用"
    
    # 测试 APT 配置
    if apt-config dump | grep -q "Acquire::Retries"; then
        log_success "APT 配置加载成功"
    else
        log_warn "APT 配置可能未正确加载"
    fi
    
    return 0
}

# 配置 APT 镜像源（可选）
configure_apt_mirror() {
    local mirror_url="$1"
    local backup_sources="/etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_step "配置 APT 镜像源"
    
    if [ -z "$mirror_url" ]; then
        log_error "请提供镜像源 URL"
        return 1
    fi
    
    # 备份原始 sources.list
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list "$backup_sources"
        log_info "已备份原始源: $backup_sources"
    fi
    
    log_warn "此功能会修改系统软件源，请确认操作"
    
    return 0
}

# 清理 APT 缓存
clean_apt_cache() {
    log_step "清理 APT 缓存"
    
    log_info "清理包缓存..."
    apt-get clean
    
    log_info "自动移除不需要的包..."
    apt-get autoremove -y
    
    log_info "移除孤立的包配置..."
    apt-get autoclean
    
    # 显示磁盘空间
    local cache_size
    cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    log_info "当前缓存大小: $cache_size"
    
    log_success "APT 缓存清理完成"
    return 0
}

# 更新 APT 包索引
update_apt_index() {
    log_step "更新 APT 包索引"
    
    log_info "正在更新包列表..."
    if apt-get update -y; then
        log_success "包索引更新成功"
    else
        log_error "包索引更新失败"
        return 1
    fi
    
    # 显示可升级的包数量
    local upgradable
    upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    log_info "可升级的包: $upgradable 个"
    
    return 0
}

# 升级系统包
upgrade_system() {
    local full_upgrade="${1:-false}"
    
    log_step "系统包升级"
    
    log_warn "这将升级系统中的所有包，可能需要一些时间"
    
    if [ "$full_upgrade" = "true" ]; then
        log_info "执行完整升级 (full-upgrade)..."
        apt-get full-upgrade -y
    else
        log_info "执行常规升级 (upgrade)..."
        apt-get upgrade -y
    fi
    
    log_success "系统升级完成"
    
    # 清理
    clean_apt_cache
    
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    ACTION="${1:-setup}"
    
    case "$ACTION" in
        setup)
            setup_apt_optimization
            ;;
        clean)
            clean_apt_cache
            ;;
        update)
            update_apt_index
            ;;
        upgrade)
            update_apt_index
            upgrade_system "false"
            ;;
        full-upgrade)
            update_apt_index
            upgrade_system "true"
            ;;
        *)
            log_error "未知操作: $ACTION"
            echo "用法: $0 {setup|clean|update|upgrade|full-upgrade}"
            exit 1
            ;;
    esac
fi
