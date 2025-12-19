#!/bin/bash
# RPI-Custom-Imager - 公共函数库
# 其他脚本通过 source ./common.sh 引入

# 颜色定义
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
BLUE='\033[38;5;21m'
CYAN='\033[38;5;51m'
NC='\033[0m'


# 日志函数
echo_error() { echo -e "${RED}✗ $1${NC}" >&2; }
echo_success() { echo -e "${GREEN}✓ $1${NC}"; }
echo_info() { echo -e "${YELLOW}ℹ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
echo_highlight() { echo -e "${CYAN}$1${NC}"; }

# 检查 root 权限
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo_error "此脚本需要 root 权限"
        echo_info "请使用: ${CYAN}sudo $0 $@${NC}"
        exit 1
    fi
}

# 检查文件是否存在
require_file() {
    local file=$1
    local message=$2
    
    if [ ! -f "$file" ]; then
        echo_error "$message"
        exit 1
    fi
}

# 检查命令是否存在
require_command() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        echo_error "$cmd 未安装"
        if [ -n "$package" ]; then
            echo_info "安装命令: sudo apt install $package"
        fi
        return 1
    fi
    return 0
}
