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
#   RENDER_TIMEOUT_SECS (기본 300) 항목당(생성+다운로드) 타임아웃. (구 ZAI_TIMEOUT_SECS도 인식)
#
# 출력: 사람이 읽는 요약(성공/실패/중복 패널 명시). 종료 코드 0=전 항목 유효, 1=문제 있음.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# 공통부(lib/common.sh)에 넘기는 설정
DEFAULT_TIMEOUT_SECS=300
LEGACY_TIMEOUT_VAR="ZAI_TIMEOUT_SECS"
REASON_RENDER_FAIL="렌더 실패(생성 API/다운로드/타임아웃) — 로그 참고"

CONCURRENCY="${CONCURRENCY:-5}"
ZAI_API_BASE="${ZAI_API_BASE:-https://api.z.ai/api/paas/v4}"
ZAI_IMAGE_MODEL="${ZAI_IMAGE_MODEL:-glm-image}"
ZAI_IMAGE_SIZE="${ZAI_IMAGE_SIZE:-1056x1568}"

command -v curl >/dev/null 2>&1 || { echo "curl 필요" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 필요" >&2; exit 2; }

# 키 소스: 환경변수 우선, 없으면 ~/.zai_api_key 파일(setup_backend.sh이 저장)
if [ -z "${ZAI_API_KEY:-}" ] && [ -s "$HOME/.zai_api_key" ]; then
  ZAI_API_KEY="$(tr -d '[:space:]' < "$HOME/.zai_api_key")"
fi

if [ -z "${ZAI_API_KEY:-}" ]; then
  echo "거부: ZAI_API_KEY 미설정 — Z.ai API 키를 발급받아 export ZAI_API_KEY=... 로 설정하거나, ~/.zai_api_key 파일로 저장하거나, WEBTOON_RENDERER=codex|antigravity 로 다른 백엔드를 쓸 것." >&2
  exit 2
fi

init_md5
init_timeout

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

parse_items "$@"
echo "=== zai_imagegen_batch: 총 $TOTAL 항목, 동시 $CONCURRENCY, 모델 $ZAI_IMAGE_MODEL ${ZAI_IMAGE_SIZE}, 타임아웃 ${RENDER_TIMEOUT_SECS}s ==="
run_waves
integrity_check
print_summary_and_exit
