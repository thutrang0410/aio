#!/bin/sh

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

wait_for_wifi() {
    local prompt_shown=0
    while ! ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; do
        if [ "$prompt_shown" -eq 0 ]; then
            echo "[PHICOMM-R1] Hãy kết nối tới Wifi của loa: Phicomm R1"
            prompt_shown=1
        fi
        sleep 3
    done
    log_info "Đã ping thành công tới loa."
}

is_device_connected() {
    "$ADB" devices 2>/dev/null | grep -q "$ADB_DEVICE.*device"
}

# --- 3. Hàm kết nối ADB (Dừng chờ đúng như bản gốc) ---
connect_adb() {
    log_info "Đang khởi động kết nối ADB..."
    wait_for_wifi
    local prompt_adb=0
    while true; do
        "$ADB" disconnect >/dev/null 2>&1
        "$ADB" kill-server >/dev/null 2>&1
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
        if is_device_connected; then
            log_info "Đã kết nối thành công!"
            return
        fi
        if [ "$prompt_adb" -eq 0 ]; then
            echo "[PHICOMM-R1] Đang chờ ADB sẵn sàng, vui lòng đợi..."
            prompt_adb=1
        fi
        sleep 5
    done
}

hide_bloatware() {
    echo "------------------------------------"
    log_info "Đang dọn dẹp ứng dụng rác..."
    local apps="device airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport"
    for app in $apps; do
        printf "  [+] Đang ẩn: %-18s " "$app"
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
        echo "[OK]"
    done
}

unhide_player() {
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player" >/dev/null 2>&1
}

setup_env() {
    if [ -d "/data/data/com.termux" ]; then
        pkg upgrade -y >/dev/null 2>&1
        pkg install -y wget curl android-tools >/dev/null 2>&1
    elif command -v apk >/dev/null 2>&1; then
        apk add wget curl android-tools >/dev/null 2>&1
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
    echo " 1. Cài Full 3 Apps (Miễn phí)"
    echo " 2. Cài Full 3 Apps (Premium)"
    echo " 3. Cập nhật bản Miễn phí"
    echo " 4. Cập nhật bản Premium"
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
                [ "$choice" = "1" ] && APK=$FREE_APK || APK=$PREMIUM_APK
                echo ""
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                
                connect_adb
                hide_bloatware
                
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
                install_apk "$HOME/$APK"
                unhide_player
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1
                unhide_player
                
                echo ""
                log_info "Khởi động lại thiết bị..."
                "$ADB" -s "$ADB_DEVICE" reboot
                exit 0
                ;;
            3|4)
                [ "$choice" = "3" ] && APK=$FREE_APK || APK=$PREMIUM_APK
                echo ""
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Bản cập nhật"
                
                connect_adb
                hide_bloatware
                
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
                install_apk "$HOME/$APK"
                unhide_player
                
                log_info "Khởi động ứng dụng..."
                "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity" >/dev/null 2>&1
                exit 0
                ;;
            0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
