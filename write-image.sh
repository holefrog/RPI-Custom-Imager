#!/bin/bash
set -e

# 基础路径配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
IMAGES_DIR="$SCRIPT_DIR/images"

# 加载公共函数库并检查权限
source "$SCRIPT_DIR/common.sh" || { echo "错误: 无法加载 common.sh"; exit 1; }
require_root

# 1. 加载用户配置
[ -f "$CONFIG_FILE" ] || { echo_error "配置不存在: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

# 2. 查找镜像文件并计算大小
IMAGE_FILE=$(find "$IMAGES_DIR" -maxdepth 1 -type f \( -name "*.img" -o -name "*.xz" -o -name "*.zip" \) | head -n 1)
[ -z "$IMAGE_FILE" ] && { echo_error "在 $IMAGES_DIR 中未找到镜像文件"; exit 1; }

echo_info "计算镜像大小..."
if [[ "$IMAGE_FILE" == *.xz ]]; then
    TOTAL_SIZE=$(xz --robot --list "$IMAGE_FILE" 2>/dev/null | awk '/totals/{print $5}')
elif [[ "$IMAGE_FILE" == *.zip ]]; then
    TOTAL_SIZE=$(unzip -l "$IMAGE_FILE" 2>/dev/null | tail -n1 | awk '{print $1}')
else
    TOTAL_SIZE=$(stat -c%s "$IMAGE_FILE" 2>/dev/null)
fi
[ -z "$TOTAL_SIZE" ] || [ "$TOTAL_SIZE" -eq 0 ] && TOTAL_SIZE=1

# 3. 交互式选择目标设备 (过滤系统盘及 >64GB 硬盘)
echo_highlight "可用存储设备:"
DEVICES=()
ROOT_DISK=$(lsblk -no PKNAME $(findmnt -n -o SOURCE /) 2>/dev/null || echo "")

while IFS= read -r line; do
    DEV=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    FULL_DEV="/dev/$DEV"
    [ "$DEV" = "$ROOT_DISK" ] && continue
    SIZE_BYTES=$(lsblk -bdno SIZE "$FULL_DEV" 2>/dev/null || echo 0)
    if [ "$SIZE_BYTES" -gt 68719476736 ]; then
        echo_warning "跳过 $FULL_DEV ($SIZE) - 容量超过 64GB"
        continue
    fi
    DEVICES+=("$FULL_DEV")
    echo "  [${#DEVICES[@]}] $FULL_DEV ($SIZE)"
done < <(lsblk -dno NAME,SIZE,MODEL 2>/dev/null | grep -v "^loop")

[ ${#DEVICES[@]} -eq 0 ] && { echo_error "无可用设备"; exit 1; }
read -p "选择编号: " CHOICE
TARGET_DEVICE="${DEVICES[$((CHOICE-1))]}"

# 确认操作
echo_error "⚠️ 警告: 将清空 $TARGET_DEVICE!"
read -p "输入 YES 继续: " CONFIRM
[ "$CONFIRM" != "YES" ] && exit 0
umount "${TARGET_DEVICE}"* 2>/dev/null || true

# 4. 进度显示写入逻辑
process_progress() {
    while read -d $'\r' -r line || read -r line; do
        if [[ "$line" =~ ^([0-9]+) ]]; then
            local pct=$(( ${BASH_REMATCH[1]} * 100 / TOTAL_SIZE ))
            [ "$pct" -gt 100 ] && pct=100
            printf "\r\033[K[写入中] %d%% | %s" "$pct" "$line"
        fi
    done
    echo ""
}

echo_info "开始写入镜像..."
case "$IMAGE_FILE" in
    *.xz)  xzcat "$IMAGE_FILE" | dd of="$TARGET_DEVICE" bs=4M status=progress 2>&1 | process_progress ;;
    *.zip) unzip -p "$IMAGE_FILE" | dd of="$TARGET_DEVICE" bs=4M status=progress 2>&1 | process_progress ;;
    *)     dd if="$IMAGE_FILE" of="$TARGET_DEVICE" bs=4M status=progress 2>&1 | process_progress ;;
esac

# 5. 同步数据并挂载分区 (包含稳定性修复)
echo_info "同步数据并挂载分区..."
sync && sleep 3
partprobe "$TARGET_DEVICE" 2>/dev/null || true
udevadm settle  # 等待系统生成设备节点

BOOT_PART=$(lsblk -lnpo NAME,FSTYPE "$TARGET_DEVICE" | grep -E "vfat|fat" | head -n1 | awk '{print $1}')
BOOT_MNT="/tmp/rpi_boot_$$"
mkdir -p "$BOOT_MNT"
mount "$BOOT_PART" "$BOOT_MNT"

# 清理旧版配置残留
rm -f "$BOOT_MNT/userconf.txt"
rm -f "$BOOT_MNT/firstrun.sh"

# 6. 注入 Cloud-init (user-data) 配置
echo_info "生成系统初始化配置 (user-data)..."
PASS_HASH=$(echo "$USER_PASSWORD" | openssl passwd -6 -stdin)

SSH_SECTION=""
if [ -n "$SSH_PUBLIC_KEY" ]; then
    SSH_SECTION="    ssh_authorized_keys:
      - \"$SSH_PUBLIC_KEY\""
fi

cat > "$BOOT_MNT/user-data" <<USERDATA_EOF
#cloud-config
hostname: $HOSTNAME
timezone: $TIMEZONE
locale: $LOCALE
users:
  - name: $USERNAME
    gecos: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    passwd: "$PASS_HASH"
    lock_passwd: false
$SSH_SECTION

chpasswd: { expire: False }

runcmd:
  - [ rfkill, unblock, wifi ]
  - [ nmcli, radio, wifi, on ]
  - [ raspi-config, nonint, do_wifi_country, $WIFI_COUNTRY ]
USERDATA_EOF

# 7. 注入 NetworkManager WiFi 配置
if [ -n "$WIFI_SSID" ]; then
    cat > "$BOOT_MNT/network-config" <<NETEOF
version: 2
renderer: NetworkManager
wifis:
  wlan0:
    dhcp4: true
    access-points:
      "$WIFI_SSID":
        password: "$WIFI_PASSWORD"
NETEOF
fi

# 8. 启用 SSH 标志
touch "$BOOT_MNT/ssh"

# 9. 修正 cmdline.txt 并完成同步
echo_info "最终修正启动参数..."
CMDLINE=$(cat "$BOOT_MNT/cmdline.txt" | tr -d '\n' | \
    sed 's| cfg80211.ieee80211_regdom=[^ ]*||g' | \
    sed 's| systemd.run=[^ ]*||g' | \
    sed 's| systemd.run_success_action=[^ ]*||g' | \
    sed 's| systemd.unit=[^ ]*||g' | \
    sed 's|[[:space:]]\+| |g')

echo -n "$CMDLINE cfg80211.ieee80211_regdom=$REGION_CODE" > "$BOOT_MNT/cmdline.txt"

sync
umount "$BOOT_MNT"
rmdir "$BOOT_MNT"
echo_success "✅ 写入与配置注入圆满完成！"
