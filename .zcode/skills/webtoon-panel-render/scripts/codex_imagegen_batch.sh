#!/usr/bin/env bash
# codex_imagegen_batch.sh — codex exec 이미지 배치 렌더 (동시 5장 웨이브)
#
# 웹툰 하네스 전용. 임의 개수의 이미지 항목을 받아 동시 5장 웨이브로 렌더하고,
# 완료 후 0바이트/손상/md5 중복을 검사한다.
#
# Usage:
#   scripts/codex_imagegen_batch.sh <output_dir> "<image prompt>::<file>.png" [more...]
#   scripts/codex_imagegen_batch.sh --from-file <manifest.txt> <output_dir>
#     - manifest 한 줄 = "<image prompt>::<file>.png" (빈 줄과 # 주석은 무시)
#
# 프로젝트 루트(_workspace/가 있는 디렉토리)에서 실행할 것. output_dir는 그 기준
# 상대경로(예: _workspace/05_panels/ep01).
#
# Env:
#   CODEX_BIN           (기본 codex)
#   RENDER_TIMEOUT_SECS (기본 600) 항목당 타임아웃. 초과 시 해당 항목 실패 처리. (구 CODEX_TIMEOUT_SECS도 인식)
#   CONCURRENCY         (기본 5) 동시 실행 수. 5 초과는 하네스 렌더 동시성 상한(5) 위반으로 거부.
#
# 출력: 사람이 읽는 요약(성공/실패/중복 패널 명시). 종료 코드 0=전 항목 유효, 1=문제 있음.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# 공통부(lib/common.sh)에 넘기는 설정
DEFAULT_TIMEOUT_SECS=600
LEGACY_TIMEOUT_VAR="CODEX_TIMEOUT_SECS"
REASON_FILE_MISSING="파일 미생성(codex가 저장 경로 지시를 무시 — 프롬프트의 './경로로 저장' 강화 후 재시도)"

CONCURRENCY="${CONCURRENCY:-5}"
CODEX_BIN="${CODEX_BIN:-codex}"

init_md5
init_timeout

sq_escape() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

render_fail_reason() { # $1=idx — 실패 사유에 종료 코드를 포함
  printf 'codex 종료 코드 %s(타임아웃 또는 세션 실패)' "${RC[$1]}"
}

# 항목 1개 렌더: codex exec 세션 1회(성공 시 0). 저장 경로·보고 형식은 지시문에 포함.
render_one() { # $1=prompt $2=file $3=log $4=idx
  local prompt file log idx prompt_esc md instruction
  prompt="$1" file="$2" log="$3" idx="$4"
  prompt_esc="$(sq_escape "$prompt")"
  md="$LOG_DIR/$(printf '%03d' "$idx")_last.md"
  if [ "${OUT_DIR#/}" != "$OUT_DIR" ]; then
    save_path="${OUT_DIR}/${file}"
  else
    save_path="./${OUT_DIR}/${file}"
  fi
  instruction="이미지 생성 도구로 '${prompt_esc}' 이미지를 생성하고 ${save_path} 로 저장한다. 성공 시 저장한 파일 경로만 한 줄로 보고."
  (
    cd "$ROOT" || exit 1
    "$CODEX_BIN" exec --sandbox workspace-write --skip-git-repo-check \
      --cd "$ROOT" -o "$md" "$instruction" >"$log" 2>&1
  )
}

parse_items "$@"

command -v "$CODEX_BIN" >/dev/null 2>&1 || { echo "codex CLI 없음: $CODEX_BIN" >&2; exit 2; }

echo "=== codex_imagegen_batch: 총 $TOTAL 항목, 동시 $CONCURRENCY, 타임아웃 ${RENDER_TIMEOUT_SECS}s ==="
run_waves
integrity_check
print_summary_and_exit
