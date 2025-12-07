# Shell-Guard

GitHub PR 자동 분석 및 보안 스캔 시스템 (Bash 전용)

## 기능

- PR diff 자동 추출 및 분석
- 민감 정보 스캔 (API 키, 패스워드, 토큰 등)
- 코드 스타일 검사
- AI 기반 코드 리뷰
- GitHub PR 자동 댓글

## 사용법

### 1. GitHub Repository Secrets 설정

- `GITHUB_TOKEN`: 자동 제공됨
- `GEMINI_API_KEY`: Google Gemini API 키 (https://aistudio.google.com/app/apikey)

### 2. 파일 배치

프로젝트를 그대로 GitHub 저장소에 push

### 3. PR 생성

PR 생성 시 자동으로 분석 실행

### 4. 댓글 명령어

- `/scan`: 재스캔
- `/ai-review`: AI 리뷰 재실행
- `/approve`: PR 승인
- `/reject`: PR 거부

## 로컬 테스트

```bash
# 환경 변수 설정
export GITHUB_TOKEN="your_token"
export GEMINI_API_KEY="your_gemini_key"
export PR_NUMBER="1"
export REPO_OWNER="owner"
export REPO_NAME="repo"

# 스크립트 실행
bash scripts/main_analyzer.sh
```

## 디렉토리 구조

```
.github/workflows/    # GitHub Actions
scripts/
  config/            # 설정 파일
  modules/           # 분석 모듈
  main_analyzer.sh   # 메인 스크립트
```

## Clean Test
Testing Shell-Guard with Gemini API

## Final Test

Testing complete Shell-Guard workflow with Gemini AI
