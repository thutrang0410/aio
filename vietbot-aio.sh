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

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*"; }

setup_env() {
    if command -v pkg >/dev/null 2>&1; then
        pkg update -y && pkg up -y wget
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
    log_info "Đang tải $name..."
    total_size=$(curl -sIL "$url" | grep -i Content-Length | tail -1 | tr -d '\r' | awk '{print $2}')
    curl -L -sS "$url" -o "$output" >/dev/null 2>&1 &
    pid=$!
    while kill -0 $pid 2>/dev/null; do
        if [ -f "$output" ]; then
            current_size=$(wc -c < "$output" 2>/dev/null)
            if [ -n "$total_size" ] && [ "$total_size" -gt 0 ]; then
                percent=$((current_size * 100 / total_size))
                [ "$percent" -gt 100 ] && percent=100
                bars=$((percent / 5))
                done_bar=$(printf "%${bars}s" | tr ' ' '#')
                printf "\r[%-20s] %3d%%" "$done_bar" "$percent"
            fi
        fi
        sleep 0.2
    done
    wait $pid
    printf "\r[####################] 100%%\n"
}

wait_for_wifi() {
    local prompt_shown=0
    while ! ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; do
        if [ "$prompt_shown" -eq 0 ]; then
            log_warn "Hãy kết nối tới Wifi của loa: Phicomm R1"
            prompt_shown=1
        fi
        sleep 3
    done
    log_info "Đã thấy thiết bị trực tuyến."
}

is_device_connected() {
    "$ADB" devices 2>/dev/null | grep -q "$ADB_DEVICE.*device"
}

connect_adb() {
    wait_for_wifi
    local prompt_adb=0
    while true; do
        "$ADB" disconnect >/dev/null 2>&1
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
        if is_device_connected; then
            log_info "Kết nối ADB thành công!"
            return
        fi
        if [ "$prompt_adb" -eq 0 ]; then
            log_warn "Đã thấy thiết bị nhưng ADB chưa sẵn sàng, đang thử lại..."
            prompt_adb=1
        fi
        sleep 2
    done
}

hide_bloatware() {
    log_info "Đang vô hiệu hóa ứng dụng rác (bloatware)..."
    local apps="airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport device"
    for app in $apps; do
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
    done
}

install_apk() {
    local local_path="$1"
    local name="$2"
    local remote_path="/data/local/tmp/$(basename "$local_path")"
    log_info "Đang đẩy $name lên loa..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "$remote_path"
    log_info "Đang cài đặt $name (Vui lòng đợi)..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "$remote_path" >/dev/null 2>&1
}

show_menu() {
    clear
    echo "===================================================="
    echo "||            VIETBOT ALL-IN-ONE                  ||"
    echo "||               By Thu Trang                     ||"
    echo "===================================================="
    echo " 1. Cài Full 3 Apps (Free)"
    echo " 2. Cài Full 3 Apps (Premium)"
    echo " 3. Update Free"
    echo " 4. Update Premium"
    echo " 0. Thoát"
    echo "===================================================="
    printf "Chọn số (0-4): "
}

main() {
    setup_env
    while true; do
        show_menu
        read choice < /dev/tty
        case $choice in
            1|2)
                if [ "$choice" = "1" ]; then APK=$FREE_APK; NAME="Vietbot Free"; else APK=$PREMIUM_APK; NAME="Vietbot Premium"; fi
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "$NAME"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                connect_adb
                hide_bloatware
                log_info "Đang dọn dẹp bản cài cũ..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
                install_apk "$HOME/$APK" "$NAME"
                install_apk "$HOME/$DLNA_APK" "DLNA"
                install_apk "$HOME/$UNI_SOUND_APK" "Unisound"
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player" >/dev/null 2>&1
                log_info "Hoàn tất! Đang khởi động lại loa..."
                "$ADB" -s "$ADB_DEVICE" reboot
                exit 0
                ;;
            3|4)
                if [ "$choice" = "3" ]; then APK=$FREE_APK; NAME="Vietbot Free"; else APK=$PREMIUM_APK; NAME="Vietbot Premium"; fi
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Update $NAME"
                connect_adb
                install_apk "$HOME/$APK" "$NAME"
                log_info "Đang khởi chạy ứng dụng..."
                "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity" >/dev/null 2>&1
                log_info "Cập nhật thành công!"
                exit 0
                ;;
            0) exit 0 ;;
            *) log_error "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
