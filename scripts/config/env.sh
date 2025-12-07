#!/bin/bash

# Shell-Guard 환경 변수 및 상수 정의
# 이 파일은 다른 스크립트에서 source 명령으로 로드됨

set -e  # 에러 발생 시 즉시 종료

# ========================================
# GitHub 관련 환경 변수
# ========================================
# GitHub Actions에서 자동으로 주입되는 환경 변수들
# GITHUB_TOKEN: GitHub API 호출용 토큰
# PR_NUMBER: Pull Request 번호
# REPO_OWNER: 저장소 소유자
# REPO_NAME: 저장소 이름
# BASE_SHA: PR의 base 브랜치 SHA
# HEAD_SHA: PR의 head 브랜치 SHA

# GitHub API Base URL
GITHUB_API_URL="https://api.github.com"

# ========================================
# AI API 관련 환경 변수
# ========================================
# GEMINI_API_KEY: Google Gemini API 키 (GitHub Secrets에서 주입)
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
GEMINI_MODEL="gemini-2.0-flash-exp"  # 무료 최신 모델
GEMINI_MAX_TOKENS=2000      # AI 응답 최대 토큰 수

# ========================================
# 분석 설정
# ========================================
# Diff 파일 크기 제한 (bytes)
MAX_DIFF_SIZE=50000  # 50KB

# 코드 한 줄 최대 길이 (스타일 검사)
MAX_LINE_LENGTH=120

# AI 요청 시 포함할 최대 diff 라인 수
MAX_DIFF_LINES=500

# ========================================
# 파일 경로
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
MODULES_DIR="${SCRIPT_DIR}/modules"
PATTERNS_FILE="${CONFIG_DIR}/patterns.txt"

# 임시 파일 경로
TMP_DIR="/tmp/shell-guard-$$"
DIFF_FILE="${TMP_DIR}/changes.diff"
SCAN_RESULT="${TMP_DIR}/scan_result.txt"
STYLE_RESULT="${TMP_DIR}/style_result.txt"
AI_RESULT="${TMP_DIR}/ai_result.txt"
FINAL_REPORT="${TMP_DIR}/final_report.md"

# ========================================
# 색상 코드 (로컬 테스트용)
# ========================================
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# ========================================
# 유틸리티 함수
# ========================================

# 로그 출력 함수
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

# 임시 디렉토리 생성
create_tmp_dir() {
    mkdir -p "$TMP_DIR"
    log_info "Temporary directory created: $TMP_DIR"
}

# 임시 파일 정리
cleanup_tmp_dir() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        log_info "Temporary directory cleaned up"
    fi
}

# 필수 환경 변수 체크
check_required_env() {
    local missing_vars=()

    if [ -z "$GITHUB_TOKEN" ]; then
        missing_vars+=("GITHUB_TOKEN")
    fi

    if [ -z "$PR_NUMBER" ]; then
        missing_vars+=("PR_NUMBER")
    fi

    if [ -z "$REPO_OWNER" ]; then
        missing_vars+=("REPO_OWNER")
    fi

    if [ -z "$REPO_NAME" ]; then
        missing_vars+=("REPO_NAME")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    return 0
}

# 파일 존재 확인
check_file_exists() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        return 1
    fi
    return 0
}

# jq 설치 확인
check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first."
        return 1
    fi
    return 0
}

# curl 설치 확인
check_curl_installed() {
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install it first."
        return 1
    fi
    return 0
}

# Export all functions
export -f log_info log_success log_warning log_error
export -f create_tmp_dir cleanup_tmp_dir
export -f check_required_env check_file_exists
export -f check_jq_installed check_curl_installed
