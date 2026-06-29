#!/bin/sh

ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
ADB="adb"

BASE_URL="https://github.com/thutrang0410/aio/releases/download/acb"
PACKAGE_NAME="info.dourok.voicebot"

FREE_APK="free.apk"
PREMIUM_APK="premium.apk"
AIBOXPLUS_APK="aibox+.apk"
DLNA_APK="auto-dlna.apk"
UNI_SOUND_APK="uni-sound.apk"

log_info() { echo "[PHICOMM-R1] $*"; }

open_browser() {
    URL="http://192.168.43.1:8081"

    if [ -d "/data/data/com.termux" ] && command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$URL"

    elif command -v apk >/dev/null 2>&1; then
        echo "====================================="
        echo "Truy cập Safari và mở:"
        echo "$URL"
        echo "====================================="

    elif command -v open >/dev/null 2>&1; then
        open "$URL" >/dev/null 2>&1

    else
        echo "Truy cập: $URL"
    fi
}

setup_env() {
    if [ -d "/data/data/com.termux" ]; then
        echo "=====> Cài qua Termux <====="
        pkg upgrade -y >/dev/null 2>&1
        pkg install -y wget curl android-tools >/dev/null 2>&1

    elif command -v apk >/dev/null 2>&1; then
        echo "=====> Cài qua iSH <====="
        apk update >/dev/null 2>&1
        apk add wget curl android-tools >/dev/null 2>&1

    elif command -v brew >/dev/null 2>&1; then
        echo "=====> Cài qua macOS <====="
        brew install wget curl android-platform-tools >/dev/null 2>&1

    else
        echo "Không hỗ trợ môi trường này."
        exit 1
    fi

    echo "Đã cài thành công, chờ xoá bộ nhớ cũ."
    rm -f "$HOME"/*.apk >/dev/null 2>&1
    echo "Đã xoá bộ nhớ."
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
    log_info "Khởi động kết nối ADB..."
    wait_for_wifi
    while true; do
        "$ADB" disconnect >/dev/null 2>&1
        "$ADB" kill-server >/dev/null 2>&1
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
        if is_device_connected; then return; fi
        sleep 2
    done
}

hide_bloatware() {
    log_info "Vô hiệu hóa bloatware..."
    local apps="device airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport"
    for app in $apps; do
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
    done
}

launch() {
    log_info "Khởi chạy ứng dụng Voicebot..."
    "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity"
}

install_apk() {
    local local_path="$1"
    local apk_file=$(basename "$local_path")
    log_info "Đẩy $apk_file lên thiết bị..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "/data/local/tmp/$apk_file"
    log_info "Cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "/data/local/tmp/$apk_file"
}

show_menu() {
    clear
    echo "======================================="
	echo "||   CÀI ĐẶT AI - DLNA - UNISOUND    ||"
	echo "||  1. [VIETBOT] FULL FREE - V1.2    ||"
    echo "||  2. [VIETBOT] FULL PREMIUM - V1.2 ||"
	echo "||  3. [AIBOX++] FULL - V5.1.3       ||"
	echo "======================================="
	echo "||          CHỈ CÀI MỖI AI           ||"
	echo "||  4. [VIETBOT] FREE - V1.2         ||"
    echo "||  5. [VIETBOT] PREMIUM - V1.2      ||"
    echo "||  6. [AIBOX++] - V5.1.3            ||"
	echo "======================================="
    echo "||  0. Thoát                         ||"
    echo "======================================="
    printf "Chọn số theo danh sách (0-6): "
}

main() {
    setup_env
    while true; do
        show_menu
        read choice < /dev/tty
        case $choice in
            1|2|3)
        case "$choice" in
            1) APK=$FREE_APK ;;
            2) APK=$PREMIUM_APK ;;
			3) APK=$AIBOXPLUS_APK ;;
        esac
                echo ""
                echo "[1/2] Chuẩn bị tải file."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Voicebot"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                
                echo ""
                echo "[2/2] Cài đặt Voicebot."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                launch
                
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player"
                
                echo ""
                log_info "Đang khởi động lại loa..."
				log_info "Cài đặt hoàn tất."
				log_info "Vào wifi Phicomm R1, truy cập 192.168.43.1:8081 để cấu hình Wi-Fi cho thiết bị."
                sleep 2
                "$ADB" -s "$ADB_DEVICE" reboot
                
                exit 0
                ;;	
            4|5|6)
        case "$choice" in
            4) APK=$FREE_APK ;;
            5) APK=$PREMIUM_APK ;;
            6) APK=$AIBOXPLUS_APK ;;
        esac
                echo ""
                echo "[1/2] Chuẩn bị tải file cập nhật."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Voicebot"
                
                echo ""
                echo "[2/2] Cập nhật Voicebot."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                launch
                
                echo ""
				echo "Đang mở trang cấu hình..."
                echo "Cài đặt hoàn tất."
                sleep 1
                open_browser
                exit 0
                ;;
			0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
