#!/bin/bash
# BBR 网络优化模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# Sysctl 配置文件
SYSCTL_BBR_CONFIG="/etc/sysctl.d/99-vps-bbr.conf"

# 启用 BBR
enable_bbr() {
    log_step "BBR 网络优化配置"
    
    # 检查内核版本
    check_kernel_version
    
    # 配置 BBR
    configure_bbr
    
    # 加载模块
    load_bbr_module
    
    # 应用配置
    apply_bbr_config
    
    # 验证 BBR
    verify_bbr
    
    log_success "BBR 网络优化配置完成"
    return 0
}

# 检查内核版本
check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d'.' -f1-2)
    
    log_info "检查内核版本"
    log_info "当前内核: $(uname -r)"
    
    # BBR 需要内核 4.9+
    local major minor
    major=$(echo "$kernel_version" | cut -d'.' -f1)
    minor=$(echo "$kernel_version" | cut -d'.' -f2)
    
    if [ "$major" -lt 4 ] || { [ "$major" -eq 4 ] && [ "$minor" -lt 9 ]; }; then
        log_warn "BBR 需要 Linux 内核 4.9 或更高版本"
        log_warn "当前版本可能不支持 BBR"
    else
        log_success "内核版本支持 BBR"
    fi
}

# 配置 BBR
configure_bbr() {
    log_info "写入 BBR 配置"
    
    # 备份现有配置
    [ -f "$SYSCTL_BBR_CONFIG" ] && backup_file "$SYSCTL_BBR_CONFIG"
    
    cat > "$SYSCTL_BBR_CONFIG" <<'EOF'
# Managed by VPS Configuration Script
# Generated: $(date)

# BBR 拥塞控制算法
# BBR (Bottleneck Bandwidth and RTT) 是 Google 开发的 TCP 拥塞控制算法
# 能够显著提升网络吞吐量和降低延迟

# 设置默认队列调度算法为 fq (Fair Queue)
net.core.default_qdisc=fq

# 设置 TCP 拥塞控制算法为 BBR
net.ipv4.tcp_congestion_control=bbr

#======================================
# 额外的 TCP 优化参数（可选）
#======================================

# 启用 TCP Fast Open
net.ipv4.tcp_fastopen=3

# TCP 连接超时时间
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=15

# TCP 缓冲区大小
net.core.rmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_default=262144
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# 最大连接数
net.core.somaxconn=32768
net.ipv4.tcp_max_syn_backlog=8192

# TIME_WAIT 复用
net.ipv4.tcp_tw_reuse=1
EOF
    
    log_success "BBR 配置已写入: $SYSCTL_BBR_CONFIG"
}

# 加载 BBR 模块
load_bbr_module() {
    log_info "加载 tcp_bbr 内核模块"
    
    # 尝试加载模块
    if modprobe tcp_bbr 2>/dev/null; then
        log_success "tcp_bbr 模块已加载"
    else
        log_warn "无法加载 tcp_bbr 模块（可能内核不支持）"
    fi
    
    # 检查模块是否已加载
    if lsmod | grep -q tcp_bbr; then
        log_success "tcp_bbr 模块当前已加载"
    else
        log_warn "tcp_bbr 模块未加载"
    fi
    
    # 添加到开机加载
    if [ -d /etc/modules-load.d ]; then
        if ! grep -q "tcp_bbr" /etc/modules-load.d/modules.conf 2>/dev/null; then
            echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
            log_info "已添加到开机自动加载"
        fi
    fi
}

# 应用 BBR 配置
apply_bbr_config() {
    log_info "应用 sysctl 配置"
    
    # 重新加载所有 sysctl 配置
    if sysctl --system >/dev/null 2>&1; then
        log_success "sysctl 配置已应用"
    else
        log_warn "sysctl 配置应用时有警告"
    fi
    
    # 直接应用关键参数（确保生效）
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
}

# 验证 BBR 是否启用
verify_bbr() {
    log_info "验证 BBR 状态"
    
    local qdisc
    local cc_algo
    
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")
    cc_algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    
    echo ""
    echo "=== BBR 配置状态 ==="
    echo "队列调度算法: $qdisc"
    echo "拥塞控制算法: $cc_algo"
    echo ""
    
    # 检查可用的拥塞控制算法
    if [ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]; then
        echo "可用拥塞控制算法:"
        cat /proc/sys/net/ipv4/tcp_available_congestion_control
        echo ""
    fi
    
    # 验证结果
    if [ "$qdisc" = "fq" ] && [ "$cc_algo" = "bbr" ]; then
        log_success "✓ BBR 已成功启用"
        return 0
    elif [ "$cc_algo" = "bbr" ]; then
        log_warn "△ BBR 算法已启用，但队列调度不是 fq"
        return 0
    else
        log_error "✗ BBR 未能正确启用"
        log_info "当前拥塞控制算法: $cc_algo"
        return 1
    fi
}

# 显示 BBR 状态
show_bbr_status() {
    log_step "BBR 状态检查"
    
    echo "=== 内核版本 ==="
    uname -r
    echo ""
    
    echo "=== 内核模块 ==="
    if lsmod | grep -q tcp_bbr; then
        echo "✓ tcp_bbr 模块已加载"
    else
        echo "✗ tcp_bbr 模块未加载"
    fi
    echo ""
    
    echo "=== 网络参数 ==="
    echo "队列调度: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'N/A')"
    echo "拥塞控制: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
    echo ""
    
    if [ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]; then
        echo "可用算法: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control)"
        echo ""
    fi
    
    # 简单的验证
    local cc
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$cc" = "bbr" ]; then
        log_success "BBR 当前已启用"
    else
        log_warn "BBR 未启用（当前: $cc）"
    fi
    
    return 0
}

# 禁用 BBR（恢复默认）
disable_bbr() {
    log_step "禁用 BBR"
    
    log_warn "将恢复默认的拥塞控制算法"
    
    # 备份配置
    [ -f "$SYSCTL_BBR_CONFIG" ] && backup_file "$SYSCTL_BBR_CONFIG"
    
    # 删除配置文件
    rm -f "$SYSCTL_BBR_CONFIG"
    
    # 恢复默认设置
    sysctl -w net.core.default_qdisc=pfifo_fast >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    
    log_success "BBR 已禁用，恢复为默认设置"
    log_info "需要重启才能完全生效"
    
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    ACTION="${1:-enable}"
    
    case "$ACTION" in
        enable)
            enable_bbr
            ;;
        status)
            show_bbr_status
            ;;
        disable)
            disable_bbr
            ;;
        verify)
            verify_bbr
            ;;
        *)
            log_error "未知操作: $ACTION"
            echo "用法: $0 {enable|status|disable|verify}"
            exit 1
            ;;
    esac
fi
