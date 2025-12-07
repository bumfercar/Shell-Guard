#!/bin/bash

# ai_helper.sh - AI 리뷰 모듈
# OpenAI API를 사용하여 diff 분석 및 리뷰 생성

set -e

# 환경 변수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/env.sh"

# ========================================
# 함수: AI 리뷰 실행
# ========================================
run_ai_review() {
    log_info "Running AI review..."

    if [ ! -f "$DIFF_FILE" ]; then
        log_error "Diff file not found: $DIFF_FILE"
        return 1
    fi

    # Gemini API 키 확인
    if [ -z "$GEMINI_API_KEY" ]; then
        log_warning "GEMINI_API_KEY not set. Skipping AI review"
        echo "AI review skipped (API key not configured)" > "$AI_RESULT"
        return 0
    fi

    # jq와 curl 설치 확인
    check_jq_installed || return 1
    check_curl_installed || return 1

    # Diff 내용 읽기
    local diff_content
    diff_content=$(<"$DIFF_FILE")

    # Diff가 너무 큰 경우 축소
    local diff_lines
    diff_lines=$(echo "$diff_content" | wc -l | tr -d ' ')

    if [ "$diff_lines" -gt "$MAX_DIFF_LINES" ]; then
        log_warning "Diff too large ($diff_lines lines). Truncating to $MAX_DIFF_LINES lines"
        diff_content=$(echo "$diff_content" | head -n "$MAX_DIFF_LINES")
        diff_content="${diff_content}"$'\n\n'"... (truncated)"
    fi

    # AI 프롬프트 생성
    local prompt
    prompt=$(generate_ai_prompt "$diff_content")

    # Gemini API 호출
    call_gemini_api "$prompt"

    return $?
}

# ========================================
# 함수: AI 프롬프트 생성
# ========================================
generate_ai_prompt() {
    local diff_content="$1"

    cat <<EOF
You are an expert code reviewer for a GitHub Pull Request analysis system called Shell-Guard.

Analyze the following Git diff and provide a comprehensive review in Korean.

Your review MUST include the following sections:
1. **변경사항 요약**: Brief summary of what changed
2. **비즈니스 로직 영향**: Impact on business logic
3. **잠재적 버그 위험**: Potential bugs or issues
4. **보안 취약점**: Security concerns (if any)
5. **코드 복잡도**: Code complexity analysis
6. **스타일 문제**: Code style issues
7. **개선 제안**: Suggestions for improvement

Keep the response concise and actionable. Focus on important issues only.

Git Diff:
\`\`\`diff
${diff_content}
\`\`\`
EOF
}

# ========================================
# 함수: Gemini API 호출
# ========================================
call_gemini_api() {
    local prompt="$1"

    # Gemini API URL
    #local api_url="https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}"
local api_url="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}"
    # JSON 페이로드 생성
    local json_payload
    json_payload=$(jq -n \
        --arg prompt "$prompt" \
        '{
            contents: [
                {
                    parts: [
                        {
                            text: $prompt
                        }
                    ]
                }
            ],
            generationConfig: {
                temperature: 0.3,
                maxOutputTokens: 2000
            }
        }')

    # API 호출
    local response
    response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)

    local curl_status=$?

    if [ $curl_status -ne 0 ]; then
        log_warning "Gemini API call failed (curl error: $curl_status)"
        echo "AI review skipped: API call error" > "$AI_RESULT"
        return 0
    fi

    # 응답 파싱
    local ai_content
    ai_content=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null || echo "")

    if [ -z "$ai_content" ] || [ "$ai_content" == "null" ]; then
        log_warning "Gemini API returned invalid response"

        # 에러 메시지 확인
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error.message' 2>/dev/null || echo "Unknown error")
        log_warning "API Error: $error_msg"

        echo "AI review skipped: $error_msg" > "$AI_RESULT"
        return 0
    fi

    # 결과 저장
    echo "$ai_content" > "$AI_RESULT"
    log_success "AI review completed successfully"

    return 0
}

# ========================================
# 함수: AI 리뷰 결과를 Markdown으로 변환
# ========================================
format_ai_result_markdown() {
    if [ ! -f "$AI_RESULT" ]; then
        echo "⚠️ **AI 리뷰가 수행되지 않았습니다**"
        return 0
    fi

    local ai_content
    ai_content=$(<"$AI_RESULT")

    if [ -z "$ai_content" ] || [[ "$ai_content" == AI\ review\ * ]]; then
        echo "⚠️ **AI 리뷰를 건너뛰었습니다**"
        echo ""
        echo "**사유:** $ai_content"
        echo ""
        echo "💡 **참고:** Gemini API 키가 올바르게 설정되어 있는지 확인하세요."
        return 0
    fi

    # AI 결과 그대로 출력 (이미 Markdown 형식)
    echo "$ai_content"

    return 0
}

# ========================================
# 함수: 간단한 AI 요약 (작은 diff용)
# ========================================
get_quick_summary() {
    if [ ! -f "$DIFF_FILE" ]; then
        echo "No changes detected"
        return 0
    fi

    local added_lines deleted_lines
    added_lines=$(grep '^+[^+]' "$DIFF_FILE" | wc -l | tr -d ' ')
    deleted_lines=$(grep '^-[^-]' "$DIFF_FILE" | wc -l | tr -d ' ')

    if [ "$added_lines" -eq 0 ] && [ "$deleted_lines" -eq 0 ]; then
        echo "No code changes"
    elif [ "$added_lines" -gt "$deleted_lines" ]; then
        echo "주로 코드 추가 (Added: +$added_lines, Deleted: -$deleted_lines)"
    elif [ "$deleted_lines" -gt "$added_lines" ]; then
        echo "주로 코드 삭제 (Added: +$added_lines, Deleted: -$deleted_lines)"
    else
        echo "코드 추가 및 삭제 (Added: +$added_lines, Deleted: -$deleted_lines)"
    fi

    return 0
}

# ========================================
# 메인 실행부 (직접 실행 시)
# ========================================
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    create_tmp_dir

    if [ ! -f "$DIFF_FILE" ]; then
        source "${MODULES_DIR}/git_diff.sh"
        extract_diff
    fi

    run_ai_review

    echo ""
    echo "=== AI Review Result (Markdown) ==="
    format_ai_result_markdown

    exit 0
fi
