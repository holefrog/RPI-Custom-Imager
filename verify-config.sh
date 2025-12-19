#!/bin/bash
# 配置验证脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

source "$SCRIPT_DIR/common.sh" || { echo "错误: 无法加载 common.sh"; exit 1; }

# 加载配置
[ -f "$CONFIG_FILE" ] || { echo_error "配置不存在: $CONFIG_FILE"; echo "执行: cp config.sample.sh config.sh"; exit 1; }
source "$CONFIG_FILE"

ERRORS=0

echo "验证配置..."

# 主机名
[[ "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]] && echo_success "主机名: $HOSTNAME" || { echo_error "主机名格式错误"; ((ERRORS++)); }

# 用户名
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && echo_success "用户名: $USERNAME" || { echo_error "用户名格式错误"; ((ERRORS++)); }

# 密码
if [ -z "$USER_PASSWORD" ]; then
    echo_error "密码未设置"
    ((ERRORS++))
elif [ ${#USER_PASSWORD} -lt 8 ]; then
    echo_warning "密码少于 8 位，建议加强"
    echo_success "密码: ****"
else
    echo_success "密码: ****"
fi

# 时区
[ -n "$TIMEZONE" ] && echo_success "时区: $TIMEZONE" || { echo_error "时区未设置"; ((ERRORS++)); }

# WiFi
if [ -n "$WIFI_SSID" ]; then
    [ -n "$WIFI_PASSWORD" ] && echo_success "WiFi: $WIFI_SSID" || { echo_error "WiFi 密码未设置"; ((ERRORS++)); }
    [[ "$WIFI_COUNTRY" =~ ^[A-Z]{2}$ ]] && echo_success "国家: $WIFI_COUNTRY" || { echo_error "国家代码格式错误"; ((ERRORS++)); }
else
    echo_warning "未配置 WiFi"
fi

# 区域代码
[[ "$REGION_CODE" =~ ^[A-Z]{2}$ ]] && echo_success "区域: $REGION_CODE" || { echo_error "REGION_CODE 格式错误"; ((ERRORS++)); }

# 额外软件包
if [ -n "$EXTRA_PACKAGES" ]; then
    echo_success "软件包: $EXTRA_PACKAGES"
fi

# SSH 公钥
if [ -n "$SSH_PUBLIC_KEY" ]; then
    [[ "$SSH_PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]] && echo_success "SSH 公钥已配置" || { echo_error "SSH 公钥格式错误"; ((ERRORS++)); }
fi

# 检查命令
echo ""
echo "检查依赖..."
REQUIRED_CMDS="dd mount umount sync openssl"

for cmd in $REQUIRED_CMDS; do
    if command -v $cmd &>/dev/null; then
        echo_success "$cmd"
    else
        echo_error "$cmd 未安装"
        ((ERRORS++))
    fi
done

# 检查解压工具（至少一个）
HAS_DECOMPRESS=false
for cmd in xz unzip; do
    if command -v $cmd &>/dev/null; then
        echo_success "$cmd (解压缩)"
        HAS_DECOMPRESS=true
        break
    fi
done

if [ "$HAS_DECOMPRESS" = false ]; then
    echo_error "缺少解压工具 (需要 xz-utils 或 unzip)"
    ((ERRORS++))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo_success "验证通过!"
    echo_info "下一步: sudo ./write-image.sh"
else
    echo_error "发现 $ERRORS 个错误"
    exit 1
fi
