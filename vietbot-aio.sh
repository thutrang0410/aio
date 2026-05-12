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

setup_env() {
    if [ -d "/data/data/com.termux" ]; then
        echo "=====> Cài qua Termux <====="
        echo ""
        echo "Vui lòng chờ cài đặt các gói."
        echo ""
        pkg upgrade -y >/dev/null 2>&1
        pkg install -y wget curl android-tools >/dev/null 2>&1
    elif command -v apk >/dev/null 2>&1; then
        echo "=====> Cài qua iSH <====="
        echo ""
        echo "Vui lòng chờ cài đặt các gói."
        echo ""
        apk add wget curl android-tools >/dev/null 2>&1
    else
        echo "Lỗi Script"
        exit 1
    fi
    echo "Đã cài thành công, chờ xoá bộ nhớ cũ."
    echo ""
    rm -f "$HOME"/*.apk >/dev/null 2>&1
    rm -f "$HOME"/*.sh >/dev/null 2>&1  
    echo "Đã xoá bộ nhớ."
    echo ""
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

wait_for_wifi() {
    local prompt_shown=0
    while ! ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; do
        if [ "$prompt_shown" -eq 0 ]; then
            echo "[PHICOMM-R1] Hãy kết nối tới Wifi của loa: Phicomm R1"
            prompt_shown=1
        fi
        sleep 3
    done
    log_info "Đã ping thành công $ADB_DEVICE_IP."
}

is_device_connected() {
    "$ADB" devices 2>/dev/null | grep -q "$ADB_DEVICE.*device"
}

connect_adb() {
    log_info "Khởi động lại kết nối ADB..."
    wait_for_wifi
    local prompt_adb=0
    while true; do
        "$ADB" disconnect >/dev/null 2>&1
        "$ADB" kill-server >/dev/null 2>&1
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
        if is_device_connected; then
            return
        fi
        if [ "$prompt_adb" -eq 0 ]; then
            echo "[PHICOMM-R1] Đã thấy thiết bị nhưng ADB chưa sẵn sàng, đang thử lại..."
            prompt_adb=1
        fi
        sleep 2
    done
}

hide_bloatware() {
    log_info "Vô hiệu hóa bloatware..."
    local apps="device airskill exceptionreporter systemtool otaservice productiontest bugreport"
    for app in $apps; do
        log_info "Vô hiệu $app"
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app"
    done
}

install_apk() {
    local local_path="$1"
    local apk_file=$(basename "$local_path")
    local remote_path="/data/local/tmp/$apk_file"
    log_info "Đẩy APKs lên thiết bị..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "$remote_path"
    log_info "Cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "$remote_path"
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
                echo "[1/2] Chuẩn bị cài đặt."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                
                echo ""
                echo "[2/2] Cài đặt Vietbot."
                log_info "Kiểm tra Adb..."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị trước khi cài đặt..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
                
                log_info "Kích hoạt player"
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player"
                
                echo ""
                log_info "Khởi động lại thiết bị..."
                "$ADB" -s "$ADB_DEVICE" reboot
                echo ""
                echo "Cài đặt hoàn tất."
                echo "Vào wifi Phicomm R1, truy cập http://192.168.43.1:8081 để cấu hình Wi-Fi cho thiết bị."
                exit 0
                ;;
            3|4)
                if [ "$choice" = "3" ]; then APK=$FREE_APK; else APK=$PREMIUM_APK; fi
                echo ""
                echo "[1/2] Chuẩn bị cài đặt."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot"
                
                echo ""
                echo "[2/2] Cài đặt Vietbot."
                log_info "Kiểm tra Adb..."
                connect_adb
                
                log_info "Kiểm tra làm sạch thiết bị trước khi cài đặt..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                
                log_info "Khởi động ứng dụng..."
                "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity"
                
                echo ""
                echo "Cài đặt hoàn tất."
                echo "Vào wifi Phicomm R1, truy cập http://192.168.43.1:8081 để cấu hình Wi-Fi cho thiết bị."
                exit 0
                ;;
            0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
