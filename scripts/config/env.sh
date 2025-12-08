#!/bin/bash

set -e

GITHUB_API_URL="https://api.github.com"

GEMINI_API_KEY="${GEMINI_API_KEY:-}"
GEMINI_MODEL="gemini-flash-latest"
GEMINI_MAX_TOKENS=2000

MAX_DIFF_SIZE=50000
MAX_LINE_LENGTH=120
MAX_DIFF_LINES=500

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
MODULES_DIR="${SCRIPT_DIR}/modules"
PATTERNS_FILE="${CONFIG_DIR}/patterns.txt"

TMP_DIR="/tmp/shell-guard-$$"
DIFF_FILE="${TMP_DIR}/changes.diff"
SCAN_RESULT="${TMP_DIR}/scan_result.txt"
STYLE_RESULT="${TMP_DIR}/style_result.txt"
AI_RESULT="${TMP_DIR}/ai_result.txt"
FINAL_REPORT="${TMP_DIR}/final_report.md"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

create_tmp_dir() {
    mkdir -p "$TMP_DIR"
    log_info "Temporary directory created: $TMP_DIR"
}

cleanup_tmp_dir() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        log_info "Temporary directory cleaned up"
    fi
}

check_required_env() {
    local missing_vars=()
    [ -z "$GITHUB_TOKEN" ] && missing_vars+=("GITHUB_TOKEN")
    [ -z "$PR_NUMBER" ] && missing_vars+=("PR_NUMBER")
    [ -z "$REPO_OWNER" ] && missing_vars+=("REPO_OWNER")
    [ -z "$REPO_NAME" ] && missing_vars+=("REPO_NAME")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    return 0
}

check_file_exists() {
    if [ ! -f "$1" ]; then
        log_error "File not found: $1"
        return 1
    fi
    return 0
}

check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        return 1
    fi
    return 0
}

check_curl_installed() {
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        return 1
    fi
    return 0
}

export -f log_info log_success log_warning log_error
export -f create_tmp_dir cleanup_tmp_dir
export -f check_required_env check_file_exists
export -f check_jq_installed check_curl_installed
