#!/bin/bash

# style_checker.sh - 코드 스타일 검사 모듈

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/env.sh"

run_style_check() {
    log_info "Running style check..."

    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    > "$STYLE_RESULT"
    local total=0

    # Trailing whitespace
    local count=$(grep '^+[^+]' "$DIFF_FILE" | grep -E '\s+$' | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo "Issue: Trailing Whitespace (Count: $count)" >> "$STYLE_RESULT"
        total=$((total + count))
    fi

    # TODO/FIXME
    count=$(grep '^+[^+]' "$DIFF_FILE" | grep -E '(TODO|FIXME|XXX|HACK)' | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo "Issue: TODO/FIXME (Count: $count)" >> "$STYLE_RESULT"
        total=$((total + count))
    fi

    echo "TOTAL_STYLE_ISSUES: $total" >> "$STYLE_RESULT"

    if [ $total -gt 0 ]; then
        log_warning "Style check found $total issue(s)"
    else
        log_success "Style check passed"
    fi

    return 0
}

format_style_result_markdown() {
    if [ ! -f "$STYLE_RESULT" ]; then
        echo "✅ **No style issues detected**"
        return 0
    fi

    local total=$(grep "TOTAL_STYLE_ISSUES:" "$STYLE_RESULT" | cut -d: -f2 | tr -d ' ' || echo "0")

    if [ "$total" -eq 0 ]; then
        echo "✅ **No style issues detected**"
        return 0
    fi

    echo "⚠️ **$total style issue(s) detected**"
    echo ""
    grep "^Issue:" "$STYLE_RESULT" | while read -r line; do
        echo "- $line"
    done

    return 0
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    create_tmp_dir
    if [ ! -f "$DIFF_FILE" ]; then
        source "${MODULES_DIR}/git_diff.sh"
        extract_diff
    fi
    run_style_check
    format_style_result_markdown
fi
