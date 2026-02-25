#!/bin/bash
# 日志和输出函数库

# 颜色定义
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

# 日志级别
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" >&2
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_step() {
    echo -e "\n${COLOR_CYAN}==>${COLOR_RESET} ${COLOR_CYAN}$*${COLOR_RESET}\n" >&2
}

log_section() {
    echo -e "\n${COLOR_GREEN}=====================================${COLOR_RESET}" >&2
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}" >&2
    echo -e "${COLOR_GREEN}=====================================${COLOR_RESET}\n" >&2
}
