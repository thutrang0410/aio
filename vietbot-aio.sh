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

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo "${RED}[ERROR]${NC} $*"
}

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
                printf "\r[${GREEN}%-20s${NC}] %3d%%" "$done_bar" "$percent"
            fi
        fi
        sleep 0.2
    done
    wait $pid
    printf "\r[${GREEN}####################${NC}] 100%%\n"
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
    log_info "Kết nối ADB tới $ADB_DEVICE..."
    "$ADB" disconnect >/dev/null 2>&1
    "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
    
    if is_device_connected; then
        log_info "Kết nối thành công!"
    else
        log_error "Không thể kết nối ADB. Vui lòng kiểm tra lại!"
        exit 1
    fi
}

hide_bloatware() {
    log_info "Vô hiệu hóa bloatware..."
    local apps="airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport device"
    for app in $apps; do
        log_info "Vô hiệu: $app"
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
    done
}

install_apk() {
    local local_path="$1"
    local remote_name=$(basename "$local_path")
    local remote_path="/data/local/tmp/$remote_name"

    log_info "Đang đẩy $remote_name lên thiết bị..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "$remote_path" >/dev/null 2>&1
    
    log_info "Đang cài đặt $remote_name..."
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
                [ "$choice" = "1" ] && APK=$FREE_APK || APK=$PREMIUM_APK
                
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot APK"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA APK"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound APK"
                
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1

                install_apk "$HOME/$APK"
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
                
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player" >/dev/null 2>&1
                
                log_info "Cài đặt hoàn tất. Đang khởi động lại loa..."
                "$ADB" -s "$ADB_DEVICE" reboot
                echo "Xong! Chờ loa khởi động lại."
                exit 0
                ;;
            3|4)
                [ "$choice" = "3" ] && APK=$FREE_APK || APK=$PREMIUM_APK
                
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot APK Update"
                
                connect_adb
                install_apk "$HOME/$APK"
                
                log_info "Khởi động ứng dụng..."
                "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity" >/dev/null 2>&1
                
                log_info "Cập nhật thành công!"
                exit 0
                ;;
            0)
                log_info "Cảm ơn bạn đã sử dụng!"
                exit 0
                ;;
            *)
                log_error "Lựa chọn không hợp lệ!"
                sleep 2
                ;;
        esac
    done
}

main
