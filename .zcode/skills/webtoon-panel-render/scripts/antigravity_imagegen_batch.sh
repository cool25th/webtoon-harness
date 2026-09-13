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
#   STYLE_ANCHOR       (선택) 화풍 고정용 참조 이미지 절대경로. 지정 시 매 패널 생성 전에
#                      에이전트가 이 이미지를 먼저 보고 동일 화풍으로 생성한다(스타일 드리프트 억제 — 실측 효과 있음).
#                      절대경로 필수. 예: _workspace/04_visual/refs/style_anchor.png 의 절대경로.
#   CONCURRENCY        (기본 5) 동시 실행 수. 5 초과는 거부.
#   RENDER_TIMEOUT_SECS (기본 600) 항목당 타임아웃. 단, agy print 모드 자체가 5분(300s) 하드 타임아웃이므로
#                      앵커 열람 등 다단계 요청도 5분 안에 끝나도 지시를 간결하게 유지할 것.
#                      (구 AGY_TIMEOUT_SECS도 인식)
#
# 출력: 사람이 읽는 요약(성공/실패/중복 패널 명시). 종료 코드 0=전 항목 유효, 1=문제 있음.
#   (개별 렌더 로그 .render_logs/*_render.log에는 agy의 JSON 출력이 그대로 담긴다 —
#    파일 저장 누락 버그 우회용 --output-format json 모드 때문. 시작/종료 래퍼 라인으로 탐색.)
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# 공통부(lib/common.sh)에 넘기는 설정
DEFAULT_TIMEOUT_SECS=600
LEGACY_TIMEOUT_VAR="AGY_TIMEOUT_SECS"
REASON_RENDER_FAIL="agy 렌더 실패(타임아웃 또는 에이전트 오류) — 로그 참고"

CONCURRENCY="${CONCURRENCY:-5}"
AGY_ASPECT="${AGY_ASPECT:-portrait 2:3 aspect ratio, tall vertical composition}"

if command -v "${AGY_BIN:-agy}" >/dev/null 2>&1; then
  AGY_BIN="${AGY_BIN:-agy}"
elif [ -x "$HOME/.local/bin/agy" ]; then
  AGY_BIN="$HOME/.local/bin/agy"
else
  echo "agy CLI 없음 — https://antigravity.google/docs/cli/install/ 에서 설치: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
  exit 2
fi

init_md5
init_timeout

parse_items "$@"

# 스타일 앵커(화풍 고정용 참조 이미지) — STYLE_ANCHOR env에 절대경로로 지정하면
# 매 패널 생성 전에 에이전트가 이 이미지를 보고 동일 화풍으로 생성한다.
ANCHOR_INSTRUCTION=""
if [ -n "${STYLE_ANCHOR:-}" ]; then
  if [ -f "$STYLE_ANCHOR" ]; then
    ANCHOR_INSTRUCTION="First, use your file/image reading tool on the exact absolute path ${STYLE_ANCHOR} (do NOT search the filesystem, do NOT use find or ls) to view it — it defines the target art style (line weight, coloring, cel shading, rendering). Then generate the image in exactly that art style. "
  else
    echo "경고: STYLE_ANCHOR 파일 없음 — 앵커 없이 렌더한다: $STYLE_ANCHOR" >&2
  fi
fi

# 장면 참조(캐릭터 시트·장소 샘플·직전 승인 패널) — 쉼표 구분 절대경로.
# "reference every time" 원칙: 생성마다 해당 장면의 인물·장소 참조를 주입해
# 신원 이탈·화자 변경·배경 무관 이탈을 억제한다(실측 효과).
SCENE_REFS_INSTRUCTION=""
if [ -n "${SCENE_REFS:-}" ]; then
  IFS=',' read -r -a _refs <<< "$SCENE_REFS"
  _ok=()
  for _r in "${_refs[@]}"; do
    _r="$(printf '%s' "$_r" | tr -d '[:space:]')"
    [ -z "$_r" ] && continue
    if [ -f "$_r" ]; then
      _ok+=("$_r")
    else
      echo "경고: 장면 참조 파일 없음 — 제외한다: $_r" >&2
    fi
  done
  if [ ${#_ok[@]} -gt 0 ]; then
    _list=$(_ok[0])
    for ((_i=1; _i<${#_ok[@]}; _i++)); do _list="$_list, ${_ok[$_i]}"; done
    SCENE_REFS_INSTRUCTION="Also view these exact files with your file/image reading tool (do NOT search the filesystem): ${_list}. They are the reference sheets and location samples for this scene — keep the characters' faces, hairstyles, identifying marks and clothing 100% identical to the references, and keep the location/background consistent with the location sample. Change only pose, camera and story moment. "
  fi
fi

render_one() { # $1=prompt $2=file $3=log ($4=idx는 공통 호출 규약용, 미사용)
  local prompt="$1" file="$2" log="$3"
  {
    echo "--- agy 렌더 시작: $(date '+%H:%M:%S') ---"
    cd "$ROOT" || exit 1
    # --output-format json: 기본 print(텍스트) 모드에서 이미지 생성 후 파일 저장이
    # 누락되는 실측 문제(텍스트 모드 5회 연속 "파일 미생성", json 모드 2회 성공) 회피.
    "$AGY_BIN" --dangerously-skip-permissions --output-format json -p "${ANCHOR_INSTRUCTION}${SCENE_REFS_INSTRUCTION}Generate an image with your image generation capability. Image prompt: ${prompt}. The image must be ${AGY_ASPECT}. Natural human anatomy: exactly two arms and two hands attached to the body, each hand with five fingers; a prop is held only by the hand stated in the image prompt. Save it exactly to ./${OUT_DIR}/${file} (create the directory if it does not exist). Report only the saved file path."
    rc=$?
    echo "--- agy 종료 코드: $rc ---"
    exit $rc
  } >"$log" 2>&1
}

echo "=== antigravity_imagegen_batch: 총 $TOTAL 항목, 동시 $CONCURRENCY, 타임아웃 ${RENDER_TIMEOUT_SECS}s ==="
run_waves
integrity_check
print_summary_and_exit
