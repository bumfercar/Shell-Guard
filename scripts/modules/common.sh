#!/usr/bin/env bash
# scripts/modules/common.sh
# 간단 사용 예: source scripts/modules/common.sh ; require_env VAR1 VAR2

set -euo pipefail

log() { echo "[`date -u +"%Y-%m-%dT%H:%M:%SZ"`] $*"; }
err() { echo "[ERROR] $*" >&2; }
info() { echo "[INFO] $*"; }

# 환경 변수 존재 체크
require_env() {
  local miss=0
  for var in "$@"; do
    if [ -z "${!var-}" ]; then
      err "필수 환경변수 $var 이(가) 설정되어 있지 않습니다."
      miss=1
    fi
  done
  if [ "$miss" -ne 0 ]; then
    exit 2
  fi
}

curl_retry() {
  local tries=0
  local max=3
  local wait=1
  local resp
  while true; do
    resp=$(curl -sS -w "%{http_code}" "$@" 2>/dev/null) || true
    http_code="${resp: -3}"
    body="${resp::-3}"
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
      printf "%s" "$body"
      return 0
    fi
    tries=$((tries+1))
    if [ "$tries" -ge "$max" ]; then
      err "curl_retry: 실패, http_code=$http_code"
      printf "%s" "$body"
      return 1
    fi
    sleep "$wait"
    wait=$((wait*2))
  done
}

make_workdir() {
  if [ -n "${WORKDIR-}" ]; then
    mkdir -p "$WORKDIR"
  else
    export WORKDIR="/tmp/shellguard/$(date +%s)"
    mkdir -p "$WORKDIR"
  fi
  export PATCH_DIR="$WORKDIR/patches"
  mkdir -p "$PATCH_DIR"
  export LOG_FILE="$WORKDIR/run.log"
  exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$WORKDIR/error.log" >&2)
}

acquire_lock() {
  local lockfile="/tmp/shellguard_${REPO_FULL_NAME//\//_}_$PR_NUMBER.lock"
  exec 9>"$lockfile"
  if ! flock -n 9; then
    err "다른 프로세스가 이미 이 PR을 처리 중입니다."
    exit 3
  fi
}

# clean up
cleanup() {
  # keep outputs for inspection; optional deletion
  # rm -rf "$WORKDIR"
  :
}

# trap handler
setup_trap() {
  trap 'rc=$?; cleanup; if [ "$rc" -ne 0 ]; then err "비정상 종료(rc=$rc)"; fi; exit $rc' EXIT INT TERM
}