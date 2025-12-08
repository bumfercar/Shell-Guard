# 🛡️ Shell-Guardddd

GitHub PR 자동 분석 및 보안 스캔 시스템 (Pure Bash)

**어떤 GitHub 레포지토리에서든 사용 가능합니다!**

## ✨ 주요 기능

- 🔐 **보안 스캔**: API 키, 비밀번호, 토큰 등 민감 정보 자동 감지
- 🧹 **코드 스타일 검사**: trailing whitespace, TODO/FIXME 등
- 🤖 **AI 코드 리뷰**: Google Gemini로 자동 리뷰 (무료)
- 💬 **자동 PR 댓글**: 분석 결과를 PR에 자동으로 댓글 작성

---

## 🚀 빠른 시작 (3단계)

### 1️⃣ Gemini API 키 발급 (무료)

1. https://aistudio.google.com/app/apikey 접속
2. **Get API Key** 클릭
3. 키 복사

### 2️⃣ GitHub Actions 워크플로우 추가

**당신의 레포지토리**에 다음 파일 생성:

`.github/workflows/shell-guard.yml`

```yaml
name: Shell-Guard PR Analysis

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout your code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Checkout Shell-Guard
        uses: actions/checkout@v3
        with:
          repository: bumfercar/Shell-Guard
          path: shell-guard

      - name: Setup environment
        run: |
          sudo apt-get update && sudo apt-get install -y jq
          cp shell-guard/scripts/config/patterns.txt.example shell-guard/scripts/config/patterns.txt

      - name: Run Shell-Guard Analysis
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          REPO_OWNER: ${{ github.repository_owner }}
          REPO_NAME: ${{ github.event.repository.name }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          chmod +x shell-guard/scripts/main_analyzer.sh
          chmod +x shell-guard/scripts/modules/*.sh
          bash shell-guard/scripts/main_analyzer.sh
```

### 3️⃣ GitHub Secrets 설정

1. 당신의 레포 → **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret** 클릭
3. 다음 추가:
   - **Name**: `GEMINI_API_KEY`
   - **Value**: (1단계에서 복사한 키)

---

## 🎉 완료!

이제 PR을 생성하면 자동으로:
- ✅ 보안 스캔 실행
- ✅ 코드 스타일 검사
- ✅ AI 리뷰 수행
- ✅ 결과를 PR 댓글로 작성

---

## 📋 댓글 명령어

PR 페이지 하단 댓글창에 다음 명령어 입력:

- `/scan` - 재스캔
- `/ai-review` - AI 리뷰 재실행

**사용 예시:**
1. GitHub PR 페이지 열기
2. 맨 아래 댓글 입력창에 `/scan` 입력
3. "Comment" 버튼 클릭
4. 자동으로 분석 재실행

---

## 🔧 커스터마이징

### 보안 패턴 추가

`shell-guard/scripts/config/patterns.txt.example` 파일을 복사하여 수정:

```bash
# 형식: 패턴명:정규식:설명
MY_SECRET:my_secret_[0-9]+:My custom secret pattern
```

### AI 모델 변경 (선택사항)

기본 모델은 `gemini-flash-latest` (무료)입니다. 다른 모델을 사용하려면:

```yaml
env:
  GEMINI_MODEL: "gemini-1.5-pro"  # 유료 고성능 모델
```

---

## 🐛 문제 해결

### AI 리뷰가 작동하지 않음
- Gemini API 키가 올바르게 설정되었는지 확인
- GitHub Secrets에 `GEMINI_API_KEY`가 있는지 확인

### 보안 스캔 오탐지
- `patterns.txt`에서 해당 패턴 제거 또는 수정

---

## 📄 라이선스

MIT License

---

## 🤝 기여

Issues와 Pull Requests를 환영합니다!

Repository: https://github.com/bumfercar/Shell-Guard
