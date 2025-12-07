#!/bin/bash

##############################################
# 시스템 분석 리포트 생성기
# 작성자: [이름]
# 설명: 시스템 정보를 수집하고 분석 리포트 생성
##############################################

# 색상 정의 (터미널 출력용)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 리포트 파일명 (날짜 포함)
REPORT_FILE="system_report_$(date +%Y%m%d_%H%M%S).txt"

##############################################
# 함수 정의
##############################################

# 헤더 출력 함수
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 섹션 출력 함수
print_section() {
    echo ""
    echo -e "${GREEN}>>> $1${NC}"
    echo "----------------------------------------"
}

# 경고 메시지 출력 함수
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 에러 메시지 출력 함수
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

##############################################
# 메인 리포트 생성
##############################################

# 리포트 시작
{
    echo "======================================"
    echo "    시스템 분석 리포트"
    echo "======================================"
    echo "생성 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "호스트명: $(hostname)"
    echo ""

    # 1. 시스템 기본 정보
    echo "======================================"
    echo "1. 시스템 정보"
    echo "======================================"
    echo "OS: $(uname -s)"
    echo "커널 버전: $(uname -r)"
    echo "아키텍처: $(uname -m)"
    echo "가동 시간: $(uptime -p 2>/dev/null || uptime)"
    echo ""

    # 2. CPU 정보
    echo "======================================"
    echo "2. CPU 정보"
    echo "======================================"
    if [ -f /proc/cpuinfo ]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        CPU_CORES=$(grep -c "processor" /proc/cpuinfo)
        echo "CPU 모델: $CPU_MODEL"
        echo "코어 수: $CPU_CORES"
    else
        echo "CPU 정보를 가져올 수 없습니다."
    fi
    echo ""

    # 3. 메모리 정보
    echo "======================================"
    echo "3. 메모리 사용량"
    echo "======================================"
    free -h 2>/dev/null || echo "메모리 정보를 가져올 수 없습니다."
    echo ""

    # 4. 디스크 사용량
    echo "======================================"
    echo "4. 디스크 사용량"
    echo "======================================"
    df -h | grep -v "tmpfs" | grep -v "loop"
    echo ""

    # 5. 디스크 사용량 경고 (80% 이상)
    echo "======================================"
    echo "5. 디스크 사용량 경고 (80% 이상)"
    echo "======================================"
    DISK_WARNING=0
    while read -r line; do
        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT=$(echo "$line" | awk '{print $6}')
        if [ "$USAGE" -ge 80 ] 2>/dev/null; then
            echo "⚠️  경고: $MOUNT 사용량 ${USAGE}%"
            DISK_WARNING=1
        fi
    done < <(df -h | grep -v "Filesystem" | grep -v "tmpfs" | grep -v "loop")

    if [ $DISK_WARNING -eq 0 ]; then
        echo "✓ 모든 디스크 정상"
    fi
    echo ""

    # 6. 현재 실행 중인 프로세스 TOP 10
    echo "======================================"
    echo "6. CPU 사용률 높은 프로세스 TOP 10"
    echo "======================================"
    ps aux --sort=-%cpu | head -11
    echo ""

    # 7. 메모리 사용률 높은 프로세스 TOP 10
    echo "======================================"
    echo "7. 메모리 사용률 높은 프로세스 TOP 10"
    echo "======================================"
    ps aux --sort=-%mem | head -11
    echo ""

    # 8. 네트워크 정보
    echo "======================================"
    echo "8. 네트워크 인터페이스"
    echo "======================================"
    ip addr 2>/dev/null || ifconfig 2>/dev/null || echo "네트워크 정보를 가져올 수 없습니다."
    echo ""

    # 9. 현재 디렉토리의 큰 파일 찾기 (상위 10개)
    echo "======================================"
    echo "9. 현재 디렉토리 큰 파일 TOP 10"
    echo "======================================"
    du -ah . 2>/dev/null | sort -rh | head -10
    echo ""

    # 10. 사용자 정보
    echo "======================================"
    echo "10. 로그인된 사용자"
    echo "======================================"
    who
    echo ""

    # 리포트 종료
    echo "======================================"
    echo "리포트 생성 완료"
    echo "======================================"

} | tee "$REPORT_FILE"

# 터미널에 결과 요약 출력
print_header "시스템 리포트 생성 완료!"
echo ""
echo -e "${GREEN}✓ 리포트 파일: $REPORT_FILE${NC}"
echo -e "${GREEN}✓ 파일 크기: $(du -h "$REPORT_FILE" | cut -f1)${NC}"
echo ""

# 디스크 경고 체크
print_section "빠른 요약"
CRITICAL_DISK=$(df -h | awk '{print $5}' | grep -o '[0-9]*' | awk '$1 >= 90 {print $1}' | head -1)
if [ -n "$CRITICAL_DISK" ]; then
    print_warning "디스크 사용량이 ${CRITICAL_DISK}% 입니다!"
else
    echo -e "${GREEN}✓ 시스템 상태 정상${NC}"
fi

echo ""
echo "리포트를 확인하려면: cat $REPORT_FILE"
echo ""
