#!/bin/bash
# RPI-Custom-Imager 配置文件
# 复制此文件为 config.sh 并修改
# ⚠️ 此文件包含敏感信息，不要提交到 Git！

# ============================================
# 基本配置
# ============================================

# 主机名
HOSTNAME="raspberrypi"

# 用户名
USERNAME="pi"

# 用户密码（明文，脚本会自动加密）
USER_PASSWORD="raspberry"

# 时区
# 查看所有时区: timedatectl list-timezones
# 常见时区: Asia/Shanghai, America/New_York, Europe/London
TIMEZONE="Asia/Shanghai"

# 语言环境
LOCALE="en_US.UTF-8"

# 键盘布局
KEYBOARD_LAYOUT="us"

# 是否启用 SSH (true/false)
ENABLE_SSH="true"

# 是否启用串口 (true/false)
ENABLE_SERIAL="false"

# ============================================
# WiFi 配置（可选）
# ============================================

# WiFi 名称（留空则不配置 WiFi）
WIFI_SSID=""

# WiFi 密码
WIFI_PASSWORD=""

# WiFi 国家代码
# CN=中国, US=美国, GB=英国, CA=加拿大
WIFI_COUNTRY="CN"

# ============================================
# SSH 配置（可选）
# ============================================

# SSH 公钥（可选，留空则不配置）
# 从 ~/.ssh/id_ed25519.pub 或 ~/.ssh/id_rsa.pub 复制
SSH_PUBLIC_KEY=""

# 示例：
# SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNLj... user@hostname"

# ============================================
# 高级配置
# ============================================

# 额外要安装的软件包（用空格分隔）
EXTRA_PACKAGES="vim git curl htop"

# 区域代码（用于 cmdline.txt）
# CN=中国, US=美国, GB=英国, CA=加拿大
REGION_CODE="CN"
