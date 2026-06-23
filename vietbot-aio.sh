```sh
#!/bin/sh

ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
ADB="adb"

BASE_URL="https://github.com/thutrang0410/aio/releases/download/acb"

FREE_APK="free.apk"
PREMIUM_APK="premium.apk"
AIBOXPLUS_APK="aibox+.apk"
VBOT_APK="VBotClient.apk"
DLNA_APK="auto-dlna.apk"
UNI_SOUND_APK="uni-sound.apk"

PACKAGE_NAME=""
MAIN_ACTIVITY=""

log_info() { echo "[PHICOMM-R1] $*"; }

open_browser() {
    URL="http://192.168.43.1:8081"

    if [ -d "/data/data/com.termux" ] && command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$URL"
    elif command -v apk >/dev/null 2>&1; then
        echo "====================================="
        echo "Mở Chrome và truy cập:"
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

wait_for_wifi() {
    local prompt_shown=0

    while ! ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; do
        if [ "$prompt_shown" -eq 0 ]; then
            echo "[PHICOMM-R1] Hãy kết nối tới Wifi của loa: Phicomm R1"
            prompt_shown=1
        fi
        sleep 3
    done
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

        if is_device_connected; then
            return
        fi

        sleep 2
    done
}

hide_bloatware() {
    local apps="device airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport"

    for app in $apps; do
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
    done
}

launch() {
    log_info "Khởi chạy ứng dụng..."
    "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/$MAIN_ACTIVITY"
}

install_apk() {
    local local_path="$1"
    local apk_file=$(basename "$local_path")

    "$ADB" -s "$ADB_DEVICE" push "$local_path" "/data/local/tmp/$apk_file" >/dev/null
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "/data/local/tmp/$apk_file"
}

show_menu() {
    clear
    offset="        "

    echo "${offset}======================================="
    echo "${offset}||        CÀI ĐẶT ALL-IN-ONE         ||"
    echo "${offset}======================================="
    echo "${offset}||   CÀI ĐẶT AI - DLNA - UNISOUND    ||"
    echo "${offset}||  1. [VIETBOT] FULL FREE          ||"
    echo "${offset}||  2. [VIETBOT] FULL PREMIUM       ||"
    echo "${offset}||  3. [AIBOX++] FULL               ||"
    echo "${offset}||  4. [VBOT] FULL                  ||"
    echo "${offset}======================================="
    echo "${offset}||          CHỈ CÀI MỖI AI           ||"
    echo "${offset}||  5. [VIETBOT] FREE              ||"
    echo "${offset}||  6. [VIETBOT] PREMIUM           ||"
    echo "${offset}||  7. [AIBOX++]                   ||"
    echo "${offset}||  8. [VBOT]                      ||"
    echo "${offset}======================================="
    echo "${offset}||  0. Thoát                       ||"
    echo "${offset}======================================="
    printf "Chọn số theo danh sách (0-8): "
}

main() {
    setup_env

    while true; do
        show_menu
        read choice < /dev/tty

        case "$choice" in
            1)
                APK=$FREE_APK
                PACKAGE_NAME="info.dourok.voicebot"
                MAIN_ACTIVITY=".java.activities.MainActivity"
                ;;
            2)
                APK=$PREMIUM_APK
                PACKAGE_NAME="info.dourok.voicebot"
                MAIN_ACTIVITY=".java.activities.MainActivity"
                ;;
            3)
                APK=$AIBOXPLUS_APK
                PACKAGE_NAME="info.dourok.voicebot"
                MAIN_ACTIVITY=".java.activities.MainActivity"
                ;;
            4)
                APK=$VBOT_APK
                PACKAGE_NAME="com.vbot_client.phicommr1"
                MAIN_ACTIVITY=".MainActivity"
                ;;
            5)
                APK=$FREE_APK
                PACKAGE_NAME="info.dourok.voicebot"
                MAIN_ACTIVITY=".java.activities.MainActivity"
                ;;
            6)
                APK=$PREMIUM_APK
                PACKAGE_NAME="info.dourok.voicebot"
                MAIN_ACTIVITY=".java.activities.MainActivity"
                ;;
            7)
                APK=$AIBOXPLUS_APK
                PACKAGE_NAME="info.dourok.voicebot"
                MAIN_ACTIVITY=".java.activities.MainActivity"
                ;;
            8)
                APK=$VBOT_APK
                PACKAGE_NAME="com.vbot_client.phicommr1"
                MAIN_ACTIVITY=".MainActivity"
                ;;
            0)
                exit 0
                ;;
            *)
                echo "Lựa chọn không hợp lệ!"
                sleep 2
                continue
                ;;
        esac

        connect_adb
        hide_bloatware

        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1

        progress_download "$BASE_URL/$APK" "$HOME/$APK" "$APK"
        install_apk "$HOME/$APK"

        launch

        if [ "$choice" -le 4 ]; then
            progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
            progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"

            install_apk "$HOME/$DLNA_APK"
            install_apk "$HOME/$UNI_SOUND_APK"

            "$ADB" -s "$ADB_DEVICE" reboot
        else
            open_browser
        fi

        exit 0
    done
}

main
```
