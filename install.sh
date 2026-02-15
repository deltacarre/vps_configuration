#!/bin/bash
# VPS 配置安装入口脚本

set -euo pipefail

# 版本信息
VERSION="1.0.0"
REPO_URL="https://github.com/deltacarre/vps_configuration"

# 颜色定义
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'

# 打印信息
print_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

print_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# 显示帮助信息
show_help() {
    cat <<EOF
VPS 配置管理工具 v${VERSION}

用法:
    ./install.sh [选项]

选项:
    -c, --config <file>     指定配置文件 (默认: config/default.conf)
    -i, --interactive       交互模式（询问用户输入）
    -m, --modules <list>    只执行指定模块（逗号分隔）
    -h, --help              显示此帮助信息
    -v, --version           显示版本信息

示例:
    # 使用默认配置（交互模式）
    ./install.sh

    # 使用自定义配置文件
    ./install.sh --config config/production.conf

    # 只执行特定模块
    ./install.sh --modules ssh,firewall,fail2ban

    # 非交互模式
    ./install.sh --config myconfig.conf

更多信息: $REPO_URL

EOF
}

# 显示版本
show_version() {
    echo "VPS Configuration v${VERSION}"
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "此脚本需要 root 权限运行"
        print_info "请使用: sudo $0 $*"
        exit 1
    fi
}

# 检查系统兼容性
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_info "检测到系统: $NAME $VERSION"
        
        if [ "$ID" != "debian" ]; then
            print_error "警告: 此脚本主要针对 Debian 12 优化"
            print_info "当前系统可能需要额外调整"
        fi
    fi
}

# 主函数
main() {
    local config_file=""
    local interactive_mode="yes"
    local modules=""
    
    # 获取脚本目录
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive_mode="yes"
                shift
                ;;
            -m|--modules)
                modules="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示欢迎信息
    echo ""
    echo "======================================"
    echo "  VPS 配置管理工具 v${VERSION}"
    echo "======================================"
    echo ""
    
    # 前置检查
    check_root "$@"
    check_system
    
    # 确定配置文件
    if [ -z "$config_file" ]; then
        config_file="$script_dir/config/default.conf"
    fi
    
    # 检查配置文件
    if [ ! -f "$config_file" ]; then
        print_error "配置文件不存在: $config_file"
        exit 1
    fi
    
    print_info "使用配置文件: $config_file"
    
    # 设置交互模式环境变量
    if [ -n "$interactive_mode" ]; then
        export INTERACTIVE_MODE="$interactive_mode"
    fi
    
    # 如果指定了模块，修改配置
    if [ -n "$modules" ]; then
        print_info "只执行模块: $modules"
        # TODO: 实现模块选择逻辑
    fi
    
    # 执行主脚本
    print_info "开始执行配置..."
    echo ""
    
    if bash "$script_dir/scripts/bootstrap.sh" "$config_file"; then
        print_success "VPS 配置完成！"
        exit 0
    else
        print_error "配置过程中出现错误"
        exit 1
    fi
}

# 执行主函数
main "$@"
