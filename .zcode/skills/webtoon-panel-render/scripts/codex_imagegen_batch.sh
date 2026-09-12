#!/usr/bin/env bash
# codex_imagegen_batch.sh — codex exec 이미지 배치 렌더 (동시 5장 웨이브)
#
# 웹툰 하네스 전용. 임의 개수의 이미지 항목을 받아 codex 동시 세션 한도(5개)를
# 넘지 않도록 5장씩 웨이브로 렌더하고, 완료 후 0바이트/손상/md5 중복을 검사한다.
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
#   CODEX_TIMEOUT_SECS  (기본 600) 항목당 타임아웃. 초과 시 해당 항목 실패 처리.
#   CONCURRENCY         (기본 5) 동시 실행 수. 5 초과는 전역 한도 위반으로 거부.
#
# 출력: 사람이 읽는 요약(성공/실패/중복 패널 명시). 종료 코드 0=전 항목 유효, 1=문제 있음.
set -u

CONCURRENCY="${CONCURRENCY:-5}"
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_TIMEOUT_SECS="${CODEX_TIMEOUT_SECS:-600}"

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 2
}

[ $# -ge 2 ] || usage

MANIFEST=""
if [ "$1" = "--from-file" ]; then
  [ $# -ge 3 ] || usage
  MANIFEST="$2"
  [ -f "$MANIFEST" ] || { echo "manifest 파일 없음: $MANIFEST" >&2; exit 2; }
  shift 2
fi

OUT_DIR="$1"
shift

case "$OUT_DIR" in
  /*) ;;
  *) OUT_DIR="${OUT_DIR%/}" ;;
esac
[ -n "$OUT_DIR" ] || { echo "output_dir 필요" >&2; exit 2; }

if [ "$CONCURRENCY" -gt 5 ]; then
  echo "거부: CONCURRENCY=$CONCURRENCY — codex 전역 동시 세션 한도는 5다. 5 이하로 설정할 것." >&2
  exit 2
fi

mkdir -p "$OUT_DIR" || exit 2
LOG_DIR="$OUT_DIR/.render_logs"
mkdir -p "$LOG_DIR"

# 항목 수집: PROMPTS[i], FILES[i]
PROMPTS=()
FILES=()
if [ -n "$MANIFEST" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
    esac
    p="${line%::*}"
    f="${line##*::}"
    if [ -z "$p" ] || [ -z "$f" ] || [ "$p" = "$line" ]; then
      echo "manifest 형식 오류(prompt::file): $line" >&2
      exit 2
    fi
    PROMPTS+=("$p")
    FILES+=("$f")
  done < "$MANIFEST"
else
  for raw in "$@"; do
    p="${raw%::*}"
    f="${raw##*::}"
    if [ -z "$p" ] || [ -z "$f" ] || [ "$p" = "$raw" ]; then
      echo "항목 형식 오류(prompt::file): $raw" >&2
      exit 2
    fi
    PROMPTS+=("$p")
    FILES+=("$f")
  done
fi

TOTAL=${#PROMPTS[@]}
[ "$TOTAL" -gt 0 ] || { echo "렌더 항목이 없다" >&2; exit 2; }

command -v "$CODEX_BIN" >/dev/null 2>&1 || { echo "codex CLI 없음: $CODEX_BIN" >&2; exit 2; }

# 작업 디렉토리(프로젝트 루트) 기록 — codex --cd 에 사용
ROOT="$(pwd)"

sq_escape() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

RC=()
for ((i=0; i<TOTAL; i++)); do RC[$i]=""; done

echo "=== codex_imagegen_batch: 총 $TOTAL 항목, 동시 $CONCURRENCY, 타임아웃 ${CODEX_TIMEOUT_SECS}s ==="

idx=0
wave_no=0
while [ "$idx" -lt "$TOTAL" ]; do
  wave_no=$((wave_no + 1))
  end=$((idx + CONCURRENCY))
  [ "$end" -gt "$TOTAL" ] && end=$TOTAL
  count=$((end - idx))
  echo "--- wave $wave_no: 항목 $((idx+1))~$end (${count}장 동시) ---"

  WAVE_PIDS=()
  WAVE_IDX=()
  i=$idx
  while [ "$i" -lt "$end" ]; do
    f="${FILES[$i]}"
    prompt="$(sq_escape "${PROMPTS[$i]}")"
    log="$LOG_DIR/$(printf '%03d' $((i+1)))_render.log"
    md="$LOG_DIR/$(printf '%03d' $((i+1)))_last.md"
    instruction="이미지 생성 도구로 '${prompt}' 이미지를 생성하고 ./${OUT_DIR}/${f} 로 저장한다. 성공 시 저장한 파일 경로만 한 줄로 보고."
    (
      cd "$ROOT" || exit 1
      "$CODEX_BIN" exec --sandbox workspace-write --skip-git-repo-check \
        --cd "$ROOT" -o "$md" "$instruction" >"$log" 2>&1
    ) &
    WAVE_PIDS+=($!)
    WAVE_IDX+=("$i")
    i=$((i + 1))
  done

  # 타임아웃 감시: 마감 후 생존 프로세스 강제 종료(정상 종료 시 발화 전 제거)
  (
    sleep "$CODEX_TIMEOUT_SECS"
    for p in "${WAVE_PIDS[@]}"; do kill "$p" 2>/dev/null; done
  ) &
  WATCHDOG=$!

  w=0
  while [ "$w" -lt "$count" ]; do
    p="${WAVE_PIDS[$w]}"
    wi="${WAVE_IDX[$w]}"
    wait "$p"
    RC[$wi]=$?
    w=$((w + 1))
  done
  kill "$WATCHDOG" 2>/dev/null
  wait "$WATCHDOG" 2>/dev/null

  idx=$end
done

# ---------- 무결성 검사 ----------
if command -v md5 >/dev/null 2>&1; then
  MD5_CMD="md5 -r"
else
  MD5_CMD="md5sum"
fi

FAIL_NAMES=()
FAIL_REASONS=()
OK_NAMES=()
HASHFILE="$LOG_DIR/_hashes.txt"
: > "$HASHFILE"

i=0
while [ "$i" -lt "$TOTAL" ]; do
  f="${FILES[$i]}"
  target="$OUT_DIR/$f"
  if [ "${RC[$i]}" != "0" ]; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("codex 종료 코드 ${RC[$i]}(타임아웃 또는 세션 실패)")
    i=$((i + 1)); continue
  fi
  if [ ! -f "$target" ]; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("파일 미생성(codex가 저장 경로 지시를 무시 — 프롬프트의 './경로로 저장' 강화 후 재시도)")
    i=$((i + 1)); continue
  fi
  if [ ! -s "$target" ]; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("0바이트")
    i=$((i + 1)); continue
  fi
  if ! file -b "$target" | grep -qi "PNG image data"; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("PNG 아님(손상)")
    i=$((i + 1)); continue
  fi
  hash=$($MD5_CMD "$target" | awk '{print $1}')
  printf '%s\t%s\n' "$hash" "$f" >> "$HASHFILE"
  OK_NAMES+=("$f")
  i=$((i + 1))
done

# md5 중복(서로 다른 패널이 동일 이미지 — 크기/헤더 검사로는 못 잡는 사고)
DUP_GROUPS=$(cut -f1 "$HASHFILE" | sort | uniq -d)

echo ""
echo "=== 요약 ==="
echo "총 $TOTAL / 유효 ${#OK_NAMES[@]} / 문제 ${#FAIL_NAMES[@]}"
k=0
while [ "$k" -lt "${#FAIL_NAMES[@]}" ]; do
  echo "[FAIL] ${FAIL_NAMES[$k]} — ${FAIL_REASONS[$k]}"
  k=$((k + 1))
done
if [ -n "$DUP_GROUPS" ]; then
  while IFS= read -r h; do
    dup_names=$(grep "^$h" "$HASHFILE" | cut -f2 | paste -sd, -)
    echo "[DUP]  $dup_names — 동일 이미지(md5 $h). 모두 삭제 후 각각 단독 재렌더."
  done <<< "$DUP_GROUPS"
fi
echo "로그: $LOG_DIR"

if [ "${#FAIL_NAMES[@]}" -eq 0 ] && [ -z "$DUP_GROUPS" ]; then
  echo "1차 무결성 통과 — 이어서 panel-validator 6축 검증으로."
  exit 0
fi
exit 1
