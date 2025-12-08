#!/bin/bash

echo "=== Shell-Guard 로컬 테스트 ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export GITHUB_TOKEN="test-token"
export GEMINI_API_KEY="${1:-}"
export PR_NUMBER="1"
export REPO_OWNER="test-owner"
export REPO_NAME="test-repo"
export BASE_SHA="HEAD~1"
export HEAD_SHA="HEAD"

if [ -z "$GEMINI_API_KEY" ]; then
    echo "사용법: ./test-local.sh YOUR_GEMINI_API_KEY"
    echo ""
    echo "Gemini API 키 발급: https://aistudio.google.com/app/apikey"
    exit 1
fi

cp "${SCRIPT_DIR}/scripts/config/patterns.txt.example" "${SCRIPT_DIR}/scripts/config/patterns.txt" 2>/dev/null || true

chmod +x "${SCRIPT_DIR}/scripts/main_analyzer.sh"
chmod +x "${SCRIPT_DIR}/scripts/modules/"*.sh

echo "현재 Git 변경사항 분석 중..."
echo ""

bash "${SCRIPT_DIR}/scripts/main_analyzer.sh" 2>&1 | grep -v "Failed to post comment" | grep -v "GITHUB_TOKEN"

if [ -f "/tmp/shell-guard-$$/final_report.md" ]; then
    echo ""
    echo "=== 분석 결과 ==="
    cat "/tmp/shell-guard-$$/final_report.md"
fi
