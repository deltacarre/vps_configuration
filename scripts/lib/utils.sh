#!/bin/bash
# 通用工具函数库

# 检查是否为 root 用户
require_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "此脚本必须以 root 权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查用户是否存在
user_exists() {
    id "$1" &>/dev/null
}

# 检查目录是否存在，不存在则创建
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "创建目录: $dir"
    fi
}

# 备份文件
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "已备份: $file -> $backup"
    fi
}

# 安全写入文件（先写入临时文件，再移动）
safe_write_file() {
    local target="$1"
    local content="$2"
    local temp_file
    temp_file=$(mktemp)
    
    echo "$content" > "$temp_file"
    mv "$temp_file" "$target"
    log_info "已写入: $target"
}

# 读取配置值（从配置文件）
read_config() {
    local config_file="$1"
    local key="$2"
    local default="${3:-}"
    
    if [ -f "$config_file" ]; then
        local value
        value=$(grep "^${key}=" "$config_file" | cut -d'=' -f2- | sed 's/^["'\'']\|["'\'']$//g')
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# 获取当前 SSH 端口
get_ssh_port() {
    local port="22"
    
    # 检查 sshd_config.d 目录
    if [ -d /etc/ssh/sshd_config.d ]; then
        local p
        p=$(grep -RhsE '^\s*Port\s+' /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | tail -n1 || true)
        if [ -n "${p:-}" ]; then 
            port="$p"
        fi
    fi
    
    # 检查主配置文件
    local p2
    p2=$(grep -E '^\s*Port\s+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -n1 || true)
    if [ -n "${p2:-}" ]; then 
        port="$p2"
    fi
    
    echo "$port"
}

# 验证端口号
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# 询问用户确认
confirm() {
    local prompt="$1"
    local default="${2:-N}"
    
    read -rp "$prompt (y/N): " response
    response="${response:-$default}"
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# 获取系统信息
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$NAME $VERSION"
    else
        echo "Unknown"
    fi
}

# 检查系统兼容性
check_system_compatibility() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "debian" ]; then
            return 0
        fi
    fi
    log_warn "警告: 此脚本针对 Debian 12 优化，当前系统可能不完全兼容"
    return 1
}
