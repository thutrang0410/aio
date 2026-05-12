Mình hiểu ý bạn. Việc ẩn các dòng thông báo của ADB giúp script trông "sạch" hơn nhưng lại khiến bạn không biết kết quả thực tế là thành công hay thất bại (như dòng chữ `Success` quen thuộc của Android).

Mình sẽ bỏ phần ẩn thông báo (`>/dev/null 2>&1`) ở các lệnh **Cài đặt** và **Gỡ bỏ** để bạn có thể nhìn thấy trực tiếp kết quả từ loa trả về.

Đây là hàm `install_apk` và đoạn gỡ bản cũ đã được mở thông báo:

```bash
install_apk() {
    # ... đoạn push file giữ nguyên ...

    # Mở thông báo để hiện Success hoặc Failure
    log_info "Đang cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "$remote_path"
}

# Trong hàm main:
log_info "Đang gỡ bỏ bản cũ (nếu có)..."
"$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
```

Bản Script đầy đủ (đã hiện thông báo cài đặt):

```bash
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

check_adb() {
    log_info "Đang kiểm tra ADB..."
    if ! command -v "$ADB" >/dev/null 2>&1; then
        log_info "ADB chưa được cài. Đang thử cài đặt android-tools..."
        if command -v pkg >/dev/null 2>&1; then
            pkg install -y android-tools >/dev/null 2>&1
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache android-tools >/dev/null 2>&1
        else
            echo "LỖI: Không tìm thấy ADB và không thể tự cài đặt. Hãy cài thủ công!"
            exit 1
        fi
        if ! command -v "$ADB" >/dev/null 2>&1; then
            echo "LỖI: Cài đặt ADB thất bại!"
            exit 1
        fi
    fi
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
    log_info "Đã nhận được tín hiệu từ loa."
}

is_device_connected() {
    "$ADB" devices 2>/dev/null | grep -q "$ADB_DEVICE.*device"
}

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
    local remote_path="/data/local/tmp/$apk_file"
    local total_size=$(wc -c < "$local_path")

    echo "Đang đẩy $apk_file lên loa..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "$remote_path" >/dev/null 2>&1 &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        local current_size=$("$ADB" -s "$ADB_DEVICE" shell ls -l "$remote_path" 2>/dev/null | awk '{print $4}')
        if [ -n "$current_size" ] && [ "$current_size" -eq "$current_size" ] 2>/dev/null; then
            local percent=$((current_size * 100 / total_size))
            [ "$percent" -gt 100 ] && percent=100
            local bars=$((percent / 10))
            local done_bar=$(printf "%${bars}s" | tr ' ' '#')
            printf "\r[%-10s] %3d%%" "$done_bar" "$percent"
        fi
        sleep 0.5
    done
    wait $pid
    printf "\r[##########] 100%%\n"

    # Hiện thông báo cài đặt (Success/Failure)
    log_info "Đang cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "$remote_path"
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
    check_adb
    setup_env
    while true; do
        show_menu
        read choice < /dev/tty
        case $choice in
            1|2)
                [ "$choice" = "1" ] && APK=$FREE_APK || APK=$PREMIUM_APK
                echo ""
                echo "[1/2] Đang tải các ứng dụng..."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Vietbot"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                
                connect_adb
                hide_bloatware
                
                log_info "Đang gỡ bỏ bản cũ (nếu có)..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                unhide_player
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1
                unhide_player
                
                echo ""
                log_info "Đang khởi động lại loa..."
                "$ADB" -s "$ADB_DEVICE" reboot
                echo "Cài đặt hoàn tất!"
                exit 0
                ;;
            3|4)
                [ "$choice" = "3" ] && APK=$FREE_APK || APK=$PREMIUM_APK
                echo ""
                echo "[1/2] Đang tải bản cập nhật..."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Update"
                
                connect_adb
                hide_bloatware
                
                log_info "Đang gỡ bỏ bản cũ (nếu có)..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                unhide_player
                
                log_info "Đang khởi động ứng dụng..."
                "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity"
                echo "Cập nhật hoàn tất!"
                exit 0
                ;;
            0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
```
