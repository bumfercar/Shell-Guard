#!/bin/bash

echo "==============================="
echo "     Simple Sys Monitor"
echo "==============================="
echo

# ---- 시스템 정보 ----
echo "[시스템 정보]"
echo "시간 : $(date '+%Y-%m-%d %H:%M:%S')"
echo "업타임 : $(uptime -p | sed 's/up //')"
echo

# ---- 메모리 ----
echo "[메모리]"
total_mem=$(free -g | awk '/Mem:/ {print $2}')
used_mem=$(free -m | awk '/Mem:/ {printf "%.0f", $3/1024}')
avail_mem=$(free -g | awk '/Mem:/ {print $7}')
echo "전체: ${total_mem}Gi, 사용: ${used_mem}Mi, 남음: ${avail_mem}Gi"
echo

# ---- 디스크 ----
echo "[디스크(/)]"
disk_total=$(df -h / | awk 'NR==2 {print $2}')
disk_used=$(df -h / | awk 'NR==2 {print $3}')
disk_percent=$(df -h / | awk 'NR==2 {print $5}')
echo "전체: ${disk_total}, 사용: ${disk_used}, 사용률: ${disk_percent}"
echo

# ---- CPU 상위 프로세스 ----
echo "[상위 CPU 프로세스 5개]"
printf "%-6s %-15s %-6s %-6s\n" "PID" "CMD" "%CPU" "%MEM"
ps axo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
echo

# ---- CPU 사용률 추정 ----
cpu_idle=$(top -bn1 | grep "Cpu(s)" | sed 's/,/ /g' | awk '{for(i=1;i<=NF;i++) if($i ~ /id/) print $(i-1)}')

cpu_usage=$(awk -v idle="$cpu_idle" 'BEGIN {printf "%.0f", 100 - idle}')

echo "[CPU 사용률 추정] 현재: ${cpu_usage}%"