#!/bin/bash

# style_checker.sh - 코드 스타일 검사 모듈
# trailing whitespace, tab/space 혼용, debug 코드, TODO 등 검사

set -e

# 환경 변수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/env.sh"

# ========================================
# 함수: 스타일 검사 실행
# ========================================
run_style_check() {
    log_info "Running style check..."

    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    > "$STYLE_RESULT"

    local issues_found=0

    # 1. Trailing whitespace 검사
    issues_found=$((issues_found + $(check_trailing_whitespace)))

    # 2. Tab/Space 혼용 검사
    issues_found=$((issues_found + $(check_mixed_indentation)))

    # 3. Debug 코드 검사
    issues_found=$((issues_found + $(check_debug_code)))

    # 4. TODO/FIXME 검사
    issues_found=$((issues_found + $(check_todo_fixme)))

    # 5. 긴 라인 검사
    issues_found=$((issues_found + $(check_long_lines)))

    echo "TOTAL_STYLE_ISSUES: $issues_found" >> "$STYLE_RESULT"

    if [ $issues_found -gt 0 ]; then
        log_warning "Style check found $issues_found issue(s)"
        return 1
    else
        log_success "Style check passed"
        return 0
    fi
}

# ========================================
# 함수: Trailing whitespace 검사
# ========================================
check_trailing_whitespace() {
    local matches
    matches=$(grep '^+[^+]' "$DIFF_FILE" | grep -E '\s+$' || true)

    if [ -n "$matches" ]; then
        local count
        count=$(echo "$matches" | wc -l | tr -d ' ')
        {
            echo "---"
            echo "Issue: Trailing Whitespace"
            echo "Count: $count"
            echo "Lines with trailing whitespace:"
            echo "$matches"
            echo ""
        } >> "$STYLE_RESULT"
        return "$count"
    fi

    return 0
}

# ========================================
# 함수: Tab/Space 혼용 검사
# ========================================
check_mixed_indentation() {
    local matches
    # 한 줄에 tab과 space가 모두 있는 경우 (indent 부분에서)
    matches=$(grep '^+[^+]' "$DIFF_FILE" | grep -E $'^\+[ ]*\t|^\+\t[ ]*' || true)

    if [ -n "$matches" ]; then
        local count
        count=$(echo "$matches" | wc -l | tr -d ' ')
        {
            echo "---"
            echo "Issue: Mixed Tabs and Spaces"
            echo "Count: $count"
            echo "Lines with mixed indentation:"
            echo "$matches"
            echo ""
        } >> "$STYLE_RESULT"
        return "$count"
    fi

    return 0
}

# ========================================
# 함수: Debug 코드 검사
# ========================================
check_debug_code() {
    local debug_patterns=(
        "console\.log"
        "console\.debug"
        "print\("
        "printf\("
        "var_dump"
        "print_r"
        "debugger"
        "System\.out\.println"
        "cout\s*<<"
    )

    local total_matches=""

    for pattern in "${debug_patterns[@]}"; do
        local matches
        matches=$(grep '^+[^+]' "$DIFF_FILE" | grep -E "$pattern" || true)
        if [ -n "$matches" ]; then
            total_matches="${total_matches}${matches}"$'\n'
        fi
    done

    if [ -n "$total_matches" ]; then
        local count
        count=$(echo "$total_matches" | grep -v '^$' | wc -l | tr -d ' ')
        {
            echo "---"
            echo "Issue: Debug Code"
            echo "Count: $count"
            echo "Lines with debug statements:"
            echo "$total_matches"
            echo ""
        } >> "$STYLE_RESULT"
        return "$count"
    fi

    return 0
}

# ========================================
# 함수: TODO/FIXME 검사
# ========================================
check_todo_fixme() {
    local matches
    matches=$(grep '^+[^+]' "$DIFF_FILE" | grep -E '(TODO|FIXME|XXX|HACK)' || true)

    if [ -n "$matches" ]; then
        local count
        count=$(echo "$matches" | wc -l | tr -d ' ')
        {
            echo "---"
            echo "Issue: Unresolved TODO/FIXME"
            echo "Count: $count"
            echo "Lines with TODO/FIXME:"
            echo "$matches"
            echo ""
        } >> "$STYLE_RESULT"
        return "$count"
    fi

    return 0
}

# ========================================
# 함수: 긴 라인 검사
# ========================================
check_long_lines() {
    local matches
    # MAX_LINE_LENGTH보다 긴 라인 검사
    matches=$(grep '^+[^+]' "$DIFF_FILE" | awk -v max="$MAX_LINE_LENGTH" 'length > max' || true)

    if [ -n "$matches" ]; then
        local count
        count=$(echo "$matches" | wc -l | tr -d ' ')
        {
            echo "---"
            echo "Issue: Lines Too Long (>${MAX_LINE_LENGTH} chars)"
            echo "Count: $count"
            echo "Lines exceeding length limit:"
            echo "$matches"
            echo ""
        } >> "$STYLE_RESULT"
        return "$count"
    fi

    return 0
}

# ========================================
# 함수: 스타일 검사 결과를 Markdown으로 변환
# ========================================
format_style_result_markdown() {
    if [ ! -f "$STYLE_RESULT" ]; then
        echo "⚠️ **No style check performed**"
        return 0
    fi

    local total_issues
    total_issues=$(grep "TOTAL_STYLE_ISSUES:" "$STYLE_RESULT" | cut -d: -f2 | tr -d ' ' || echo "0")

    if [ "$total_issues" -eq 0 ]; then
        echo "✅ **No style issues detected**"
        return 0
    fi

    cat <<EOF
⚠️ **$total_issues style issue(s) detected**

EOF

    while IFS= read -r line; do
        if [[ "$line" =~ ^Issue:\ (.+)$ ]]; then
            echo "### 📝 ${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Count:\ (.+)$ ]]; then
            echo "**Found:** ${BASH_REMATCH[1]} occurrence(s)"
            echo ""
        elif [[ "$line" == "---" ]] || [[ "$line" =~ ^TOTAL_STYLE_ISSUES: ]]; then
            continue
        elif [[ "$line" =~ ^Lines.* ]]; then
            echo "<details>"
            echo "<summary>Show details</summary>"
            echo ""
            echo '```'
        elif [ -z "$line" ]; then
            echo '```'
            echo "</details>"
            echo ""
        else
            echo "$line"
        fi
    done < "$STYLE_RESULT"

    return 0
}

# ========================================
# 메인 실행부
# ========================================
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    create_tmp_dir

    if [ ! -f "$DIFF_FILE" ]; then
        source "${MODULES_DIR}/git_diff.sh"
        extract_diff
    fi

    run_style_check

    echo ""
    echo "=== Style Check Result (Markdown) ==="
    format_style_result_markdown

    exit 0
fi
