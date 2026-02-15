#!/bin/bash
# VPS 配置主控制脚本

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载库函数
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/checker.sh"

# 默认配置文件
DEFAULT_CONFIG="$PROJECT_ROOT/config/default.conf"
CONFIG_FILE="${1:-$DEFAULT_CONFIG}"

# 全局变量
SSH_PORT_RESULT="22"

#==========================================
# 主执行流程
#==========================================

main() {
    log_section "VPS 初始化配置开始"
    log_info "配置文件: $CONFIG_FILE"
    echo ""
    
    # 1. 前置检查
    check_prerequisites
    
    # 2. 加载配置
    load_configuration
    
    # 3. 显示配置摘要
    show_configuration_summary
    
    # 4. 执行模块
    execute_modules
    
    # 5. 生成报告
    if [ "${CREATE_REPORT:-yes}" = "yes" ]; then
        generate_system_report "${REPORT_PATH:-/root/vps_init_report.txt}"
    fi
    
    # 6. 完成提示
    show_completion_message
    
    log_section "VPS 初始化配置完成"
}

#==========================================
# 加载配置
#==========================================

load_configuration() {
    log_step "加载配置文件"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    
    # 加载配置文件
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    
    log_success "配置加载完成"
    
    # 处理 SSH 公钥文件
    if [ -z "${SSH_PUBKEY:-}" ] && [ -n "${SSH_PUBKEY_FILE:-}" ]; then
        if [ -f "$SSH_PUBKEY_FILE" ]; then
            SSH_PUBKEY=$(cat "$SSH_PUBKEY_FILE")
            log_info "从文件加载 SSH 公钥: $SSH_PUBKEY_FILE"
        else
            log_warn "SSH 公钥文件不存在: $SSH_PUBKEY_FILE"
        fi
    fi
}

#==========================================
# 显示配置摘要
#==========================================

show_configuration_summary() {
    log_step "配置摘要"
    
    echo "用户设置:"
    echo "  用户名: ${VPS_USER:-未设置}"
    echo "  主机名: ${VPS_HOSTNAME:-保持不变}"
    echo ""
    
    echo "SSH 配置:"
    echo "  SSH 端口: ${SSH_PORT:-22}"
    echo "  修改端口: ${SSH_CHANGE_PORT:-no}"
    echo "  禁用 root: ${SSH_DISABLE_ROOT:-yes}"
    echo "  禁用密码: ${SSH_DISABLE_PASSWORD:-yes}"
    echo "  公钥配置: ${SSH_PUBKEY:+已设置}"
    echo ""
    
    echo "安全配置:"
    echo "  防火墙: ${ENABLE_FIREWALL:-yes}"
    echo "  Fail2ban: ${ENABLE_FAIL2BAN:-yes}"
    echo "  额外端口: ${FIREWALL_EXTRA_PORTS:-无}"
    echo ""
    
    echo "系统优化:"
    echo "  时区: ${TIMEZONE:-Asia/Hong_Kong}"
    echo "  Swap: ${SWAP_CREATE:-no} (${SWAP_SIZE:-2G})"
    echo "  BBR: ${ENABLE_BBR:-yes}"
    echo ""
    
    echo "启用模块:"
    echo "  [${ENABLE_USER_SETUP:-yes}] 用户管理"
    echo "  [${ENABLE_HOSTNAME_SETUP:-yes}] 主机名设置"
    echo "  [${ENABLE_PACKAGE_INSTALL:-yes}] 软件包安装"
    echo "  [${ENABLE_SSH_HARDENING:-yes}] SSH 安全加固"
    echo "  [${ENABLE_FIREWALL:-yes}] 防火墙配置"
    echo "  [${ENABLE_FAIL2BAN:-yes}] Fail2ban"
    echo "  [${ENABLE_TIMEZONE:-yes}] 时区设置"
    echo "  [${ENABLE_APT_OPTIMIZATION:-yes}] APT 优化"
    echo "  [${ENABLE_SWAP:-yes}] Swap 优化"
    echo "  [${ENABLE_BBR:-yes}] BBR 网络优化"
    echo ""
    
    # 交互模式下询问确认
    if [ "${INTERACTIVE_MODE:-yes}" = "yes" ]; then
        if ! confirm "确认以上配置并继续？"; then
            log_warn "用户取消操作"
            exit 0
        fi
    else
        log_info "非交互模式，自动继续..."
        sleep 2
    fi
}

#==========================================
# 执行模块
#==========================================

execute_modules() {
    local interactive="${INTERACTIVE_MODE:-yes}"
    
    # 1. 用户管理
    if [ "${ENABLE_USER_SETUP:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/01-user-management.sh" "${VPS_USER:-}" "$interactive"
    fi
    
    # 2. 主机名设置
    if [ "${ENABLE_HOSTNAME_SETUP:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/02-hostname-setup.sh" "${VPS_HOSTNAME:-}" "$interactive"
    fi
    
    # 3. 时区设置
    if [ "${ENABLE_TIMEZONE:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/07-timezone-setup.sh" "${TIMEZONE:-Asia/Hong_Kong}"
    fi
    
    # 4. APT 优化
    if [ "${ENABLE_APT_OPTIMIZATION:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/08-apt-optimization.sh" setup
    fi
    
    # 5. 软件包安装
    if [ "${ENABLE_PACKAGE_INSTALL:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/03-package-install.sh"
    fi
    
    # 6. SSH 安全加固
    if [ "${ENABLE_SSH_HARDENING:-yes}" = "yes" ]; then
        local ssh_port_to_use="${SSH_PORT:-}"
        
        # 如果配置要求修改端口但没有指定新端口，询问
        if [ "${SSH_CHANGE_PORT:-no}" = "yes" ] && [ "$interactive" = "yes" ] && [ -z "$ssh_port_to_use" ]; then
            read -rp "请输入新的 SSH 端口（1024-65535）: " ssh_port_to_use
        fi
        
        SSH_PORT_RESULT=$(bash "$SCRIPT_DIR/core/04-ssh-hardening.sh" \
            "${VPS_USER:-admin}" \
            "${SSH_PUBKEY:-}" \
            "$ssh_port_to_use" \
            "$interactive")
        
        log_info "SSH 端口: $SSH_PORT_RESULT"
    else
        SSH_PORT_RESULT=$(get_ssh_port)
    fi
    
    # 7. 防火墙配置
    if [ "${ENABLE_FIREWALL:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/05-firewall-ufw.sh" \
            "$SSH_PORT_RESULT" \
            "${FIREWALL_EXTRA_PORTS:-}"
    fi
    
    # 8. Fail2ban 配置
    if [ "${ENABLE_FAIL2BAN:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/06-fail2ban-setup.sh" \
            "$SSH_PORT_RESULT" \
            "${F2B_MAXRETRY:-5}" \
            "${F2B_FINDTIME:-10m}" \
            "${F2B_BANTIME:-6h}"
    fi
    
    # 9. Swap 优化
    if [ "${ENABLE_SWAP:-yes}" = "yes" ]; then
        if [ "${SWAP_CREATE:-no}" = "yes" ]; then
            bash "$SCRIPT_DIR/core/09-swap-optimization.sh" create \
                "${SWAP_SIZE:-2G}" \
                "${SWAP_SWAPPINESS:-10}" \
                "${SWAP_CACHE_PRESSURE:-50}"
        else
            bash "$SCRIPT_DIR/core/09-swap-optimization.sh" setup \
                "${SWAP_SWAPPINESS:-10}" \
                "${SWAP_CACHE_PRESSURE:-50}"
        fi
    fi
    
    # 10. BBR 网络优化
    if [ "${ENABLE_BBR:-yes}" = "yes" ]; then
        bash "$SCRIPT_DIR/core/10-network-bbr.sh" enable
    fi
}

#==========================================
# 完成提示
#==========================================

show_completion_message() {
    echo ""
    log_section "初始化完成！"
    
    echo ""
    echo "======================================"
    echo "  配置摘要"
    echo "======================================"
    echo ""
    echo "SSH 配置:"
    echo "  端口: $SSH_PORT_RESULT"
    echo "  登录用户: ${VPS_USER:-admin}"
    echo "  认证方式: 仅 SSH Key"
    echo ""
    echo "安全设置:"
    echo "  ✓ root SSH 登录已禁用"
    echo "  ✓ 密码登录已禁用"
    echo "  ✓ UFW 防火墙已启用"
    echo "  ✓ Fail2ban 防暴力破解已启用"
    echo ""
    echo "系统优化:"
    [ "${ENABLE_SWAP:-yes}" = "yes" ] && echo "  ✓ Swap 已优化"
    [ "${ENABLE_BBR:-yes}" = "yes" ] && echo "  ✓ BBR 已启用"
    [ "${ENABLE_APT_OPTIMIZATION:-yes}" = "yes" ] && echo "  ✓ APT 已优化"
    echo ""
    
    log_warn "⚠️  重要提示 ⚠️"
    echo ""
    echo "请【立即】在新终端窗口测试 SSH 连接："
    echo ""
    echo "  ssh -p $SSH_PORT_RESULT ${VPS_USER:-admin}@<服务器IP>"
    echo ""
    echo "确认可以正常登录后，再关闭当前会话！"
    echo ""
    
    if [ "${CREATE_REPORT:-yes}" = "yes" ]; then
        echo "系统报告已保存到: ${REPORT_PATH:-/root/vps_init_report.txt}"
        echo ""
    fi
}

#==========================================
# 执行主函数
#==========================================

main "$@"
