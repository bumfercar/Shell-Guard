#!/bin/bash
# battery-manager.sh

check_bluetooth_device() {
    local name=$1
    local mac=$2
    
    # UPower로 확인
    battery=$(upower -i /org/freedesktop/UPower/devices/$(upower -e | grep -i "$name") | grep percentage | awk '{print $2}')
    
    if [ -n "$battery" ]; then
        echo "$name: $battery"
        
        # 20% 미만이면 알림
        level=${battery%\%}
        if [ $level -lt 20 ]; then
            notify-send "⚠️ $name 배터리 부족" "$battery - 충전 필요!"
        fi
    fi
}

# 모든 장치 체크
check_bluetooth_device "Mouse" "AA:BB:CC:DD:EE:FF"
check_bluetooth_device "Keyboard" "11:22:33:44:55:66"

# 노트북 배터리
laptop_battery=$(cat /sys/class/power_supply/BAT0/capacity)
echo "Laptop: $laptop_battery%"