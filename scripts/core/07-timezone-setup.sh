#!/bin/bash
# 时区设置模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# 设置时区
setup_timezone() {
    local timezone="${1:-Asia/Hong_Kong}"
    
    log_step "时区配置"
    
    # 获取当前时区
    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
    log_info "当前时区: $current_tz"
    
    # 验证时区是否有效
    if [ ! -f "/usr/share/zoneinfo/$timezone" ]; then
        log_error "时区无效: $timezone"
        log_info "请使用 'timedatectl list-timezones' 查看可用时区"
        return 1
    fi
    
    log_info "设置时区为: $timezone"
    
    # 使用 timedatectl 设置时区
    if command_exists timedatectl; then
        timedatectl set-timezone "$timezone"
    else
        # 备用方法
        ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
        echo "$timezone" > /etc/timezone
    fi
    
    # 验证设置
    local new_tz
    new_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)
    
    if [ "$new_tz" = "$timezone" ]; then
        log_success "时区已设置: $timezone"
        log_info "当前时间: $(date)"
    else
        log_error "时区设置失败"
        return 1
    fi
    
    return 0
}

# 显示可用时区（常用的）
show_common_timezones() {
    log_info "常用时区列表:"
    echo ""
    echo "  亚洲:"
    echo "    - Asia/Shanghai      (中国 - 北京)"
    echo "    - Asia/Hong_Kong     (中国 - 香港)"
    echo "    - Asia/Taipei        (中国 - 台北)"
    echo "    - Asia/Tokyo         (日本 - 东京)"
    echo "    - Asia/Seoul         (韩国 - 首尔)"
    echo "    - Asia/Singapore     (新加坡)"
    echo ""
    echo "  美洲:"
    echo "    - America/New_York   (美国东部)"
    echo "    - America/Chicago    (美国中部)"
    echo "    - America/Los_Angeles (美国西部)"
    echo ""
    echo "  欧洲:"
    echo "    - Europe/London      (英国)"
    echo "    - Europe/Paris       (法国/德国)"
    echo "    - Europe/Moscow      (俄罗斯)"
    echo ""
    echo "  其他:"
    echo "    - UTC                (协调世界时)"
    echo ""
    log_info "使用 'timedatectl list-timezones' 查看完整列表"
}

# 显示当前时间信息
show_time_info() {
    log_step "系统时间信息"
    
    if command_exists timedatectl; then
        timedatectl status
    else
        echo "时区: $(cat /etc/timezone 2>/dev/null || echo 'Unknown')"
        echo "本地时间: $(date)"
        echo "UTC 时间: $(date -u)"
    fi
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    require_root
    
    TIMEZONE="${1:-Asia/Hong_Kong}"
    
    if [ "$TIMEZONE" = "--list" ] || [ "$TIMEZONE" = "-l" ]; then
        show_common_timezones
    elif [ "$TIMEZONE" = "--show" ] || [ "$TIMEZONE" = "-s" ]; then
        show_time_info
    else
        setup_timezone "$TIMEZONE"
    fi
fi
