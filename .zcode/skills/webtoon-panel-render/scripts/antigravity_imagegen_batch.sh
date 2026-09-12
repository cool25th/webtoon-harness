#!/usr/bin/env bash
# antigravity_imagegen_batch.sh — Google Antigravity CLI(agy) 이미지 배치 렌더 (동시 5장 웨이브)
#
# Antigravity CLI의 헤드리스 모드로 임의 개수의 이미지를 렌더한다. Google 계정
# 구독(Gemini/Nano Banana) 쿼터를 소비하며 별도 API 키가 필요 없다(키체인 자동 로그인).
# 완료 후 0바이트/손상/md5 중복을 검사한다.
#
# Usage:
#   scripts/antigravity_imagegen_batch.sh <output_dir> "<image prompt>::<file>.png" [more...]
#   scripts/antigravity_imagegen_batch.sh --from-file <manifest.txt> <output_dir>
#
# 프로젝트 루트(_workspace/가 있는 디렉토리)에서 실행할 것.
#
# Env:
#   AGY_BIN            (기본 agy — PATH에 없으면 ~/.local/bin/agy 자동 사용)
#   AGY_ASPECT         (기본 "portrait 2:3 aspect ratio, tall vertical composition")
#   CONCURRENCY        (기본 5) 동시 실행 수. 5 초과는 거부.
#   AGY_TIMEOUT_SECS   (기본 600) 항목당 타임아웃. 에이전트 실행이므로 여유 있음.
#
# 출력: 사람이 읽는 요약(성공/실패/중복 패널 명시). 종료 코드 0=전 항목 유효, 1=문제 있음.
set -u

CONCURRENCY="${CONCURRENCY:-5}"
AGY_ASPECT="${AGY_ASPECT:-portrait 2:3 aspect ratio, tall vertical composition}"
AGY_TIMEOUT_SECS="${AGY_TIMEOUT_SECS:-600}"

if command -v "${AGY_BIN:-agy}" >/dev/null 2>&1; then
  AGY_BIN="${AGY_BIN:-agy}"
elif [ -x "$HOME/.local/bin/agy" ]; then
  AGY_BIN="$HOME/.local/bin/agy"
else
  echo "agy CLI 없음 — https://antigravity.google/docs/cli/install/ 에서 설치: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
  exit 2
fi

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 2
}

command -v md5 >/dev/null 2>&1 && MD5_CMD="md5 -r" || MD5_CMD="md5sum"

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
  echo "거부: CONCURRENCY=$CONCURRENCY — 하네스 렌더 동시성 상한은 5다. 5 이하로 설정할 것." >&2
  exit 2
fi

mkdir -p "$OUT_DIR" || exit 2
LOG_DIR="$OUT_DIR/.render_logs"
mkdir -p "$LOG_DIR"

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

ROOT="$(pwd)"

render_one() { # $1=prompt $2=file $3=log
  local prompt="$1" file="$2" log="$3"
  {
    echo "--- agy 렌더 시작: $(date '+%H:%M:%S') ---"
    cd "$ROOT" || exit 1
    "$AGY_BIN" --dangerously-skip-permissions -p "Generate an image with your image generation capability. Image prompt: ${prompt}. The image must be ${AGY_ASPECT}. Save it exactly to ./${OUT_DIR}/${file} (create the directory if it does not exist). Report only the saved file path."
    rc=$?
    echo "--- agy 종료 코드: $rc ---"
    exit $rc
  } >"$log" 2>&1
}

RC=()
for ((i=0; i<TOTAL; i++)); do RC[$i]=""; done

echo "=== antigravity_imagegen_batch: 총 $TOTAL 항목, 동시 $CONCURRENCY, 타임아웃 ${AGY_TIMEOUT_SECS}s ==="

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
    log="$LOG_DIR/$(printf '%03d' $((i+1)))_render.log"
    render_one "${PROMPTS[$i]}" "$f" "$log" &
    WAVE_PIDS+=($!)
    WAVE_IDX+=("$i")
    i=$((i + 1))
  done

  (
    sleep "$AGY_TIMEOUT_SECS"
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
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("agy 렌더 실패(타임아웃 또는 에이전트 오류) — 로그 참고")
    i=$((i + 1)); continue
  fi
  if [ ! -f "$target" ]; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("파일 미생성")
    i=$((i + 1)); continue
  fi
  if [ ! -s "$target" ]; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("0바이트")
    i=$((i + 1)); continue
  fi
  if ! file -b "$target" | grep -qi "PNG image data\|JPEG image data"; then
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("이미지 아님(손상)")
    i=$((i + 1)); continue
  fi
  hash=$($MD5_CMD "$target" | awk '{print $1}')
  printf '%s\t%s\n' "$hash" "$f" >> "$HASHFILE"
  OK_NAMES+=("$f")
  i=$((i + 1))
done

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
