#!/usr/bin/env bash
# zai_imagegen_batch.sh — Z.ai(GLM) 이미지 배치 렌더 (동시 5장 웨이브)
#
# Z.ai 이미지 생성 API(POST /api/paas/v4/images/generations, glm-image 계열)로
# 임의 개수의 이미지 항목을 렌더한다. API가 URL을 반환하므로 다운로드까지 수행하고,
# 완료 후 0바이트/손상/md5 중복을 검사한다.
#
# Usage:
#   scripts/zai_imagegen_batch.sh <output_dir> "<image prompt>::<file>.png" [more...]
#   scripts/zai_imagegen_batch.sh --from-file <manifest.txt> <output_dir>
#     - manifest 한 줄 = "<image prompt>::<file>.png" (빈 줄과 # 주석은 무시)
#
# 프로젝트 루트(_workspace/가 있는 디렉토리)에서 실행할 것.
#
# Env:
#   ZAI_API_KEY         (필수) Z.ai API 키 — https://z.ai/model-api 에서 발급
#   ZAI_API_BASE        (기본 https://api.z.ai/api/paas/v4)
#   ZAI_IMAGE_MODEL     (기본 glm-image, 대 cogview-4-250304)
#   ZAI_IMAGE_SIZE      (기본 1056x1568 — 세로 스크롤 웹툰 패널용 portrait)
#   ZAI_IMAGE_QUALITY   (기본 미지정=API 기본값; hd|standard)
#   CONCURRENCY         (기본 5) 동시 실행 수. 5 초과는 거부.
#   ZAI_TIMEOUT_SECS    (기본 300) 항목당(생성+다운로드) 타임아웃.
#
# 출력: 사람이 읽는 요약(성공/실패/중복 패널 명시). 종료 코드 0=전 항목 유효, 1=문제 있음.
set -u

CONCURRENCY="${CONCURRENCY:-5}"
ZAI_API_BASE="${ZAI_API_BASE:-https://api.z.ai/api/paas/v4}"
ZAI_IMAGE_MODEL="${ZAI_IMAGE_MODEL:-glm-image}"
ZAI_IMAGE_SIZE="${ZAI_IMAGE_SIZE:-1056x1568}"
ZAI_TIMEOUT_SECS="${ZAI_TIMEOUT_SECS:-300}"

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 2
}

command -v curl >/dev/null 2>&1 || { echo "curl 필요" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 필요" >&2; exit 2; }
command -v md5 >/dev/null 2>&1 && MD5_CMD="md5 -r" || MD5_CMD="md5sum"

# 키 소스: 환경변수 우선, 없으면 ~/.zai_api_key 파일(setup_backend.sh이 저장)
if [ -z "${ZAI_API_KEY:-}" ] && [ -s "$HOME/.zai_api_key" ]; then
  ZAI_API_KEY="$(tr -d '[:space:]' < "$HOME/.zai_api_key")"
fi

if [ -z "${ZAI_API_KEY:-}" ]; then
  echo "거부: ZAI_API_KEY 미설정 — Z.ai API 키를 발급받아 export ZAI_API_KEY=... 로 설정하거나, ~/.zai_api_key 파일로 저장하거나, WEBTOON_RENDERER=codex|antigravity 로 다른 백엔드를 쓸 것." >&2
  exit 2
fi

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

# 항목 1개 렌더: 생성 요청 → URL 파싱 → 다운로드. 성공 시 0.
render_one() { # $1=prompt $2=file $3=log $4=idx
  local prompt="$1" file="$2" log="$3" idx="$4"
  local target="$OUT_DIR/$file"
  local payload url dl_url
  payload=$(python3 -c '
import json, sys
body = {"model": sys.argv[1], "prompt": sys.argv[2], "size": sys.argv[3]}
if len(sys.argv) > 4 and sys.argv[4]:
    body["quality"] = sys.argv[4]
print(json.dumps(body, ensure_ascii=False))
' "$ZAI_IMAGE_MODEL" "$prompt" "$ZAI_IMAGE_SIZE" "${ZAI_IMAGE_QUALITY:-}" 2>>"$log") || {
    echo "[$idx] JSON 인코딩 실패" >>"$log"; return 1
  }
  url=$(curl -fsS --max-time 180 \
    -H "Authorization: Bearer ${ZAI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${ZAI_API_BASE}/images/generations" 2>>"$log" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit("응답이 JSON이 아니다")
if isinstance(d, dict) and "code" in d and "data" not in d:
    sys.exit("API 오류 %s: %s" % (d.get("code"), d.get("message")))
data = d.get("data") or []
if not data or not data[0].get("url"):
    sys.exit("응답에 data[0].url 없음: %s" % json.dumps(d, ensure_ascii=False)[:300])
print(data[0]["url"])
' 2>>"$log") || {
    echo "[$idx] 생성 API 실패: $url" >>"$log"; return 1
  }
  dl_url="$url"
  curl -fsSL --max-time 120 "$dl_url" -o "$target" 2>>"$log" || {
    echo "[$idx] 이미지 다운로드 실패: $dl_url" >>"$log"; return 1
  }
  echo "[$idx] 저장 완료: ./${target}" >>"$log"
}

RC=()
for ((i=0; i<TOTAL; i++)); do RC[$i]=""; done

echo "=== zai_imagegen_batch: 총 $TOTAL 항목, 동시 $CONCURRENCY, 모델 $ZAI_IMAGE_MODEL ${ZAI_IMAGE_SIZE}, 타임아웃 ${ZAI_TIMEOUT_SECS}s ==="

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
    render_one "${PROMPTS[$i]}" "$f" "$log" "$((i+1))" &
    WAVE_PIDS+=($!)
    WAVE_IDX+=("$i")
    i=$((i + 1))
  done

  # 타임아웃 감시: 마감 후 생존 프로세스 강제 종료(정상 종료 시 발화 전 제거)
  (
    sleep "$ZAI_TIMEOUT_SECS"
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
    FAIL_NAMES+=("$f"); FAIL_REASONS+=("렌더 실패(생성 API/다운로드/타임아웃) — 로그 참고")
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
