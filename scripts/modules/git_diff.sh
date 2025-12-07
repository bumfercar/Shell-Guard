#!/bin/bash

# git_diff.sh - Git diff 추출 및 처리 모듈
# PR의 변경사항을 추출하고 분석에 적합한 형태로 가공

set -e

# 환경 변수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/env.sh"

# ========================================
# 함수: Git diff 추출
# ========================================
# PR의 base 브랜치와 head 브랜치 간의 diff를 추출
# 결과는 DIFF_FILE에 저장됨
extract_diff() {
    log_info "Extracting git diff..."

    # BASE_SHA와 HEAD_SHA가 설정되어 있는지 확인
    if [ -z "$BASE_SHA" ] || [ -z "$HEAD_SHA" ]; then
        log_warning "BASE_SHA or HEAD_SHA not set. Using origin/main...HEAD"
        BASE_REF="origin/main"
        HEAD_REF="HEAD"
    else
        BASE_REF="$BASE_SHA"
        HEAD_REF="$HEAD_SHA"
    fi

    # Unified format으로 diff 추출 (컨텍스트 라인 0개)
    # --unified=0: 변경된 라인만 표시
    # --no-color: 색상 코드 제거
    git diff "${BASE_REF}...${HEAD_REF}" --unified=3 --no-color > "$DIFF_FILE" 2>&1 || {
        log_error "Failed to extract git diff"
        return 1
    }

    # Diff 파일 크기 확인
    local diff_size
    diff_size=$(wc -c < "$DIFF_FILE")
    log_info "Diff size: ${diff_size} bytes"

    # 파일이 비어있는지 확인
    if [ ! -s "$DIFF_FILE" ]; then
        log_warning "No changes detected in this PR"
        echo "No changes detected" > "$DIFF_FILE"
        return 0
    fi

    # 크기 제한 확인
    if [ "$diff_size" -gt "$MAX_DIFF_SIZE" ]; then
        log_warning "Diff size exceeds limit (${MAX_DIFF_SIZE} bytes). Truncating..."
        truncate_diff
    fi

    log_success "Diff extraction completed"
    return 0
}

# ========================================
# 함수: Diff 크기 축소
# ========================================
# Diff가 너무 클 경우 적절히 잘라냄
truncate_diff() {
    local temp_file="${TMP_DIR}/diff_truncated.tmp"

    # 파일별로 변경사항을 추출하고 중요도에 따라 정렬
    # 우선순위: 보안 관련 파일 > 설정 파일 > 소스 코드 > 기타

    head -n "$MAX_DIFF_LINES" "$DIFF_FILE" > "$temp_file"
    echo "" >> "$temp_file"
    echo "... (diff truncated due to size limit) ..." >> "$temp_file"

    mv "$temp_file" "$DIFF_FILE"
    log_info "Diff truncated to $MAX_DIFF_LINES lines"
}

# ========================================
# 함수: 변경된 파일 목록 추출
# ========================================
get_changed_files() {
    log_info "Extracting changed file list..."

    if [ -z "$BASE_SHA" ] || [ -z "$HEAD_SHA" ]; then
        BASE_REF="origin/main"
        HEAD_REF="HEAD"
    else
        BASE_REF="$BASE_SHA"
        HEAD_REF="$HEAD_SHA"
    fi

    # 변경된 파일 목록 추출
    git diff --name-only "${BASE_REF}...${HEAD_REF}" 2>/dev/null || {
        log_error "Failed to get changed files"
        return 1
    }

    return 0
}

# ========================================
# 함수: 파일별 변경 통계
# ========================================
get_diff_stats() {
    log_info "Calculating diff statistics..."

    if [ -z "$BASE_SHA" ] || [ -z "$HEAD_SHA" ]; then
        BASE_REF="origin/main"
        HEAD_REF="HEAD"
    else
        BASE_REF="$BASE_SHA"
        HEAD_REF="$HEAD_SHA"
    fi

    # 파일별 추가/삭제 라인 수 통계
    git diff --stat "${BASE_REF}...${HEAD_REF}" 2>/dev/null || {
        log_error "Failed to get diff stats"
        return 1
    }

    return 0
}

# ========================================
# 함수: 특정 파일의 diff 추출
# ========================================
# 인자: $1 = 파일 경로
get_file_diff() {
    local file_path="$1"

    if [ -z "$file_path" ]; then
        log_error "File path not provided"
        return 1
    fi

    if [ -z "$BASE_SHA" ] || [ -z "$HEAD_SHA" ]; then
        BASE_REF="origin/main"
        HEAD_REF="HEAD"
    else
        BASE_REF="$BASE_SHA"
        HEAD_REF="$HEAD_SHA"
    fi

    # 특정 파일의 diff만 추출
    git diff "${BASE_REF}...${HEAD_REF}" -- "$file_path" 2>/dev/null || {
        log_error "Failed to get diff for file: $file_path"
        return 1
    }

    return 0
}

# ========================================
# 함수: Diff에서 추가된 라인만 추출
# ========================================
# Diff 파일에서 '+' 로 시작하는 라인 (추가된 코드)만 추출
extract_added_lines() {
    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    # '+' 로 시작하는 라인 추출 (단, '+++' 헤더 제외)
    grep '^+[^+]' "$DIFF_FILE" | sed 's/^+//' || true

    return 0
}

# ========================================
# 함수: Diff에서 삭제된 라인만 추출
# ========================================
extract_deleted_lines() {
    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    # '-' 로 시작하는 라인 추출 (단, '---' 헤더 제외)
    grep '^-[^-]' "$DIFF_FILE" | sed 's/^-//' || true

    return 0
}

# ========================================
# 함수: Diff 요약 정보 생성
# ========================================
generate_diff_summary() {
    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    local total_files
    local added_lines
    local deleted_lines

    total_files=$(get_changed_files | wc -l)
    added_lines=$(extract_added_lines | wc -l)
    deleted_lines=$(extract_deleted_lines | wc -l)

    cat <<EOF
**Changed Files:** $total_files
**Added Lines:** +$added_lines
**Deleted Lines:** -$deleted_lines
EOF

    return 0
}

# ========================================
# 메인 실행부 (직접 실행 시)
# ========================================
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # 임시 디렉토리 생성
    create_tmp_dir

    # Diff 추출
    extract_diff

    # 요약 정보 출력
    echo ""
    echo "=== Diff Summary ==="
    generate_diff_summary
    echo ""
    echo "=== Changed Files ==="
    get_changed_files
    echo ""
    echo "=== Diff Statistics ==="
    get_diff_stats

    log_success "Git diff extraction completed successfully"
fi
