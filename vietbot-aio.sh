#!/bin/sh

# Cấu hình
ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
ADB="adb"

BASE_URL="https://github.com/thutrang0410/vietbot/releases/download/r1"
PACKAGE_NAME="info.dourok.voicebot"

FREE_APK="free.apk"
PREMIUM_APK="premium.apk"
DLNA_APK="auto-dlna.apk"
UNI_SOUND_APK="uni-sound.apk"

log_info() { echo "[PHICOMM-R1] $*"; }

hide_bloatware() {
    echo "------------------------------------"
    log_info "Đang ẩn files hệ thống (Bloatware)..."
    # Danh sách đầy đủ: device, airskill, exceptionreporter, ijetty, netctl, systemtool, otaservice, productiontest, bugreport
    local apps="device airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport"
    for app in $apps; do
        printf "  [+] Đang vô hiệu hóa: %-18s " "$app"
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
        echo "[OK]"
    done
}

# --- 2. Hàm hiện Player (Quan trọng cho âm thanh) ---
unhide_player() {
    log_info "Đang kích hoạt lại Player hệ thống..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player" >/dev/null 2>&1
}

setup_env() {
    if [ -d "/data/data/com.termux" ]; then
        echo "=====> Cài qua Termux <====="
        pkg upgrade -y >/dev/null 2>&1
        pkg install -y wget curl android-tools >/dev/null 2>&1
    elif command -v apk >/dev/null 2>&1; then
        echo "=====> Cài qua iSH <====="
        apk add wget curl android-tools >/dev/null 2>&1
    else
        echo "Lỗi Script"
        exit 1
    fi
    rm -f "$HOME"/*.apk >/dev/null 2>&1
}

progress_download() {
    url="$1"
    output="$2"
    name="$3"
    echo "Đang tải $name..."
    total_size=$(curl -sIL "$url" | grep -i Content-Length | tail -1 | tr -d '\r' | awk '{print $2}')
    curl -L -sS "$url" -o "$output" >/dev/null 2>&1 &
    pid=$!
    while kill -0 $pid 2>/dev/null; do
        if [ -f "$output" ]; then
            current_size=$(wc -c < "$output" 2>/dev/null)
            if [ -n "$total_size" ] && [ "$total_size" -gt 0 ]; then
                percent=$((current_size * 100 / total_size))
                [ "$percent" -gt 100 ] && percent=100
                bars=$((percent / 10))
                done_bar=$(printf "%${bars}s" | tr ' ' '#')
                printf "\r[%-10s] %3d%%" "$done_bar" "$percent"
            fi
        fi
        sleep 0.2
    done
    wait $pid
    printf "\r[##########] 100%%\n"
}

connect_adb() {
    log_info "Đang kết nối ADB tới $ADB_DEVICE..."
    while ! ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; do
        echo "Vui lòng kết nối Wifi tới loa Phicomm R1..."
        sleep 3
    done
    "$ADB" disconnect >/dev/null 2>&1
    "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
    if "$ADB" devices | grep -q "$ADB_DEVICE.*device"; then
        log_info "Đã kết nối thành công."
    else
        log_info "Lỗi kết nối, đang thử lại..."
        sleep 2
        connect_adb
    fi
}

install_apk() {
    local local_path="$1"
    local apk_file=$(basename "$local_path")
    log_info "Đang cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "/data/local/tmp/$apk_file" >/dev/null 2>&1
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "/data/local/tmp/$apk_file" >/dev/null 2>&1
}

show_menu() {
    clear
    echo "===================================="
    echo "||  CÀI ĐẶT VIETBOT BY THU TRANG  ||"
    echo "===================================="
    echo " 1. Cài Full 3 Apps (Free)"
    echo " 2. Cài Full 3 Apps (Premium)"
    echo " 3. Update Free"
    echo " 4. Update Premium"
    echo " 0. Thoát"
    echo "===================================="
    printf "Chọn số (0-4): "
}

main() {
    setup_env
    while true; do
        show_menu
        read choice < /dev/tty
        case $choice in
            1|2)
                if [ "$choice" = "1" ]; then APK=$FREE_APK; else APK=$PREMIUM_APK; fi
                echo ""
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                
                connect_adb
                
                # Bước 1: Dọn dẹp máy trước
                hide_bloatware
                
                # Bước 2: Cài Vietbot chính
                log_info "Đang gỡ bản cũ..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
                install_apk "$HOME/$APK"
                
                unhide_player
                
                # Bước 4: Cài DLNA & Unisound
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                # Cấp quyền cài đặt
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1
                
                # Đảm bảo Player vẫn hiện trước khi kết thúc
                unhide_player
                
                echo ""
                log_info "Khởi động lại thiết bị..."
                "$ADB" -s "$ADB_DEVICE" reboot
                echo "Xong! Chờ loa khởi động lại."
                exit 0
                ;;
            3|4)
                if [ "$choice" = "3" ]; then APK=$FREE_APK; else APK=$PREMIUM_APK; fi
                echo ""
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Bản cập nhật"
                
                connect_adb
                
                # Update cũng dọn dẹp bloatware
                hide_bloatware
                
                log_info "Đang cập nhật Vietbot..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
                install_apk "$HOME/$APK"
                
                unhide_player
                
                log_info "Khởi động ứng dụng..."
                "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity" >/dev/null 2>&1
                
                echo "Cập nhật thành công!"
                exit 0
                ;;
            0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
