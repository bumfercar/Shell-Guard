#!/bin/bash

# github_api.sh - GitHub API 통신 모듈
# PR 댓글 작성, 리뷰 승인/거부 등

set -e

# 환경 변수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/env.sh"

# ========================================
# 함수: PR에 댓글 작성
# ========================================
#인자: $1 = 댓글 내용 (Markdown)
post_pr_comment() {
    local comment_body="$1"

    if [ -z "$comment_body" ]; then
        log_error "Comment body is empty"
        return 1
    fi

    # 필수 환경 변수 확인
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$PR_NUMBER" ]; then
        log_error "Required environment variables not set"
        return 1
    fi

    local api_url="${GITHUB_API_URL}/repos/${REPO_OWNER}/${REPO_NAME}/issues/${PR_NUMBER}/comments"

    # JSON 페이로드 생성
    local json_payload
    json_payload=$(jq -n --arg body "$comment_body" '{body: $body}')

    # API 호출
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        log_success "Comment posted successfully to PR #${PR_NUMBER}"
        return 0
    else
        log_error "Failed to post comment (HTTP $http_code)"
        log_error "Response: $response_body"
        return 1
    fi
}

# ========================================
# 함수: PR 승인
# ========================================
approve_pr() {
    local pr_number="${1:-$PR_NUMBER}"

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$pr_number" ]; then
        log_error "Required environment variables not set"
        return 1
    fi

    local api_url="${GITHUB_API_URL}/repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/reviews"

    # JSON 페이로드 생성
    local json_payload
    json_payload=$(jq -n '{
        body: "✅ Approved by Shell-Guard",
        event: "APPROVE"
    }')

    # API 호출
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        log_success "PR #${pr_number} approved"
        post_pr_comment "✅ **Shell-Guard**: 이 PR이 자동 승인되었습니다."
        return 0
    else
        log_error "Failed to approve PR (HTTP $http_code)"
        return 1
    fi
}

# ========================================
# 함수: PR 변경 요청 (Request Changes)
# ========================================
request_changes() {
    local reason="${1:-보안 또는 스타일 이슈가 발견되었습니다.}"
    local pr_number="${2:-$PR_NUMBER}"

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$pr_number" ]; then
        log_error "Required environment variables not set"
        return 1
    fi

    local api_url="${GITHUB_API_URL}/repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/reviews"

    # JSON 페이로드 생성
    local json_payload
    json_payload=$(jq -n --arg reason "$reason" '{
        body: $reason,
        event: "REQUEST_CHANGES"
    }')

    # API 호출
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        log_success "Changes requested for PR #${pr_number}"
        return 0
    else
        log_error "Failed to request changes (HTTP $http_code)"
        return 1
    fi
}

# ========================================
# 함수: PR 거부 (Comment + Request Changes)
# ========================================
reject_pr() {
    local reason="${1:-이 PR은 Shell-Guard에 의해 거부되었습니다.}"
    local pr_number="${2:-$PR_NUMBER}"

    log_info "Rejecting PR #${pr_number}"

    # 댓글 작성
    post_pr_comment "❌ **Shell-Guard**: $reason"

    # 변경 요청
    request_changes "$reason" "$pr_number"

    return $?
}

# ========================================
# 함수: PR 정보 가져오기
# ========================================
get_pr_info() {
    local pr_number="${1:-$PR_NUMBER}"

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$pr_number" ]; then
        log_error "Required environment variables not set"
        return 1
    fi

    local api_url="${GITHUB_API_URL}/repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}"

    # API 호출
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$api_url"

    return $?
}

# ========================================
# 함수: PR의 최근 댓글 가져오기
# ========================================
get_pr_comments() {
    local pr_number="${1:-$PR_NUMBER}"

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$pr_number" ]; then
        log_error "Required environment variables not set"
        return 1
    fi

    local api_url="${GITHUB_API_URL}/repos/${REPO_OWNER}/${REPO_NAME}/issues/${pr_number}/comments"

    # API 호출
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$api_url"

    return $?
}

# ========================================
# 메인 실행부 (직접 실행 시 - 테스트용)
# ========================================
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # 명령어 인자 처리
    case "${1:-}" in
        approve_pr)
            approve_pr "${2:-}"
            ;;
        reject_pr)
            reject_pr "${2:-}" "${3:-}"
            ;;
        post_comment)
            post_pr_comment "${2:-Test comment}"
            ;;
        get_info)
            get_pr_info "${2:-}"
            ;;
        get_comments)
            get_pr_comments "${2:-}"
            ;;
        *)
            echo "Usage: $0 {approve_pr|reject_pr|post_comment|get_info|get_comments} [args...]"
            exit 1
            ;;
    esac

    exit $?
fi
