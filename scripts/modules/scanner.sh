#!/bin/bash

# scanner.sh - 보안 스캔 모듈
# patterns.txt에 정의된 패턴으로 민감 정보 검색

set -e

# 환경 변수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/env.sh"

# ========================================
# 함수: 보안 스캔 실행
# ========================================
# patterns.txt의 정규식 패턴으로 diff 파일을 스캔
# 결과는 SCAN_RESULT 파일에 저장
run_security_scan() {
    log_info "Running security scan..."

    # 필수 파일 확인
    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    if [ ! -f "$PATTERNS_FILE" ]; then
        log_error "Patterns file not found: $PATTERNS_FILE"
        return 1
    fi

    # 결과 파일 초기화
    > "$SCAN_RESULT"

    local issues_found=0

    # patterns.txt를 한 줄씩 읽어서 검사
    while IFS=: read -r pattern_name pattern_regex description; do
        # 주석이나 빈 줄 무시
        if [[ "$pattern_name" =~ ^#.*$ ]] || [ -z "$pattern_name" ]; then
            continue
        fi

        # Diff 파일에서 추가된 라인만 검사 ('+' 로 시작하는 라인)
        local matches
        matches=$(grep '^+[^+]' "$DIFF_FILE" | grep -E "$pattern_regex" || true)

        if [ -n "$matches" ]; then
            issues_found=$((issues_found + 1))

            # 결과 파일에 기록
            {
                echo "---"
                echo "Pattern: $pattern_name"
                echo "Description: $description"
                echo "Matches:"
                echo "$matches"
                echo ""
            } >> "$SCAN_RESULT"

            log_warning "Security issue detected: $pattern_name"
        fi
    done < "$PATTERNS_FILE"

    # 스캔 결과 요약
    if [ $issues_found -gt 0 ]; then
        log_error "Security scan found $issues_found issue(s)"
        echo "TOTAL_ISSUES: $issues_found" >> "$SCAN_RESULT"
        return 2  # 보안 이슈 발견 시 특별한 반환 코드
    else
        log_success "Security scan completed - No issues found"
        echo "TOTAL_ISSUES: 0" >> "$SCAN_RESULT"
        return 0
    fi
}

# ========================================
# 함수: 스캔 결과를 Markdown 형식으로 변환
# ========================================
format_scan_result_markdown() {
    if [ ! -f "$SCAN_RESULT" ]; then
        echo "⚠️ **No security scan performed**"
        return 0
    fi

    local total_issues
    total_issues=$(grep "TOTAL_ISSUES:" "$SCAN_RESULT" | cut -d: -f2 | tr -d ' ' || echo "0")

    if [ "$total_issues" -eq 0 ]; then
        echo "✅ **No security issues detected**"
        return 0
    fi

    # Markdown 형식으로 출력
    cat <<EOF
🚨 **$total_issues security issue(s) detected**

This PR contains potentially sensitive information that should not be committed:

EOF

    # 각 이슈를 Markdown 리스트로 변환
    local in_matches=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^Pattern:\ (.+)$ ]]; then
            echo "### 🔴 ${BASH_REMATCH[1]}"
            in_matches=0
        elif [[ "$line" =~ ^Description:\ (.+)$ ]]; then
            echo "**${BASH_REMATCH[1]}**"
            echo ""
            in_matches=0
        elif [[ "$line" == "Matches:" ]]; then
            echo "**Found in:**"
            echo '```'
            in_matches=1
        elif [ "$line" == "---" ]; then
            if [ $in_matches -eq 1 ]; then
                echo '```'
                echo ""
                in_matches=0
            fi
        elif [[ "$line" =~ ^TOTAL_ISSUES: ]]; then
            continue
        else
            echo "$line"
        fi
    done < "$SCAN_RESULT"

    if [ $in_matches -eq 1 ]; then
        echo '```'
    fi

    cat <<EOF

---
**⚠️ Action Required:**
- Remove all sensitive information before merging
- Use environment variables or secret management systems
- Never commit credentials, API keys, or private keys to version control
EOF

    return 0
}

# ========================================
# 함수: 특정 파일에 대한 보안 스캔
# ========================================
# 인자: $1 = 파일 경로
scan_file() {
    local file_path="$1"

    if [ -z "$file_path" ]; then
        log_error "File path not provided"
        return 1
    fi

    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        return 1
    fi

    if [ ! -f "$PATTERNS_FILE" ]; then
        log_error "Patterns file not found: $PATTERNS_FILE"
        return 1
    fi

    log_info "Scanning file: $file_path"

    local issues_found=0

    # patterns.txt를 한 줄씩 읽어서 검사
    while IFS=: read -r pattern_name pattern_regex description; do
        # 주석이나 빈 줄 무시
        if [[ "$pattern_name" =~ ^#.*$ ]] || [ -z "$pattern_name" ]; then
            continue
        fi

        # 파일 내용 검사
        local matches
        matches=$(grep -E "$pattern_regex" "$file_path" || true)

        if [ -n "$matches" ]; then
            issues_found=$((issues_found + 1))
            log_warning "Security issue in $file_path: $pattern_name"
            echo "  - $description"
        fi
    done < "$PATTERNS_FILE"

    if [ $issues_found -gt 0 ]; then
        log_error "Found $issues_found security issue(s) in $file_path"
        return 1
    else
        log_success "No security issues in $file_path"
        return 0
    fi
}

# ========================================
# 함수: 커스텀 패턴 추가
# ========================================
# 인자: $1 = 패턴명, $2 = 정규식, $3 = 설명
add_custom_pattern() {
    local pattern_name="$1"
    local pattern_regex="$2"
    local description="$3"

    if [ -z "$pattern_name" ] || [ -z "$pattern_regex" ] || [ -z "$description" ]; then
        log_error "Invalid arguments for add_custom_pattern"
        return 1
    fi

    # patterns.txt에 추가
    echo "${pattern_name}:${pattern_regex}:${description}" >> "$PATTERNS_FILE"
    log_success "Custom pattern added: $pattern_name"

    return 0
}

# ========================================
# 함수: 고위험 패턴만 스캔
# ========================================
# AWS, GitHub, Private Key 등 고위험 패턴만 검사
scan_high_risk_only() {
    log_info "Running high-risk security scan..."

    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    # 고위험 패턴 목록
    local high_risk_patterns=(
        "AWS_ACCESS_KEY"
        "AWS_SECRET_KEY"
        "GITHUB_TOKEN"
        "RSA_PRIVATE_KEY"
        "OPENSSH_PRIVATE_KEY"
        "PASSWORD_ASSIGNMENT"
    )

    local issues_found=0

    for pattern_name in "${high_risk_patterns[@]}"; do
        # patterns.txt에서 해당 패턴 찾기
        local pattern_line
        pattern_line=$(grep "^${pattern_name}:" "$PATTERNS_FILE" || true)

        if [ -z "$pattern_line" ]; then
            continue
        fi

        local pattern_regex
        local description
        pattern_regex=$(echo "$pattern_line" | cut -d: -f2)
        description=$(echo "$pattern_line" | cut -d: -f3-)

        # 검사 수행
        local matches
        matches=$(grep '^+[^+]' "$DIFF_FILE" | grep -E "$pattern_regex" || true)

        if [ -n "$matches" ]; then
            issues_found=$((issues_found + 1))
            log_error "HIGH RISK: $pattern_name - $description"
        fi
    done

    if [ $issues_found -gt 0 ]; then
        log_error "Found $issues_found high-risk security issue(s)"
        return 1
    else
        log_success "No high-risk security issues found"
        return 0
    fi
}

# ========================================
# 메인 실행부 (직접 실행 시)
# ========================================
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # 임시 디렉토리 생성
    create_tmp_dir

    # Diff 파일이 없으면 먼저 생성
    if [ ! -f "$DIFF_FILE" ]; then
        source "${MODULES_DIR}/git_diff.sh"
        extract_diff
    fi

    # 보안 스캔 실행
    run_security_scan
    scan_status=$?

    echo ""
    echo "=== Security Scan Result (Markdown) ==="
    format_scan_result_markdown

    if [ $scan_status -eq 2 ]; then
        log_error "Security issues detected - PR should not be merged"
        exit 1
    else
        log_success "Security scan completed successfully"
        exit 0
    fi
fi
