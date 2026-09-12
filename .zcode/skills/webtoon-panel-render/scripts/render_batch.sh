#!/usr/bin/env bash
# render_batch.sh — 렌더 백엔드 디스패처 (antigravity ↔ codex ↔ Z.ai GLM-Image)
#
# 웹툰 하네스의 유일한 렌더 진입점. 어느 백엔드로 렌더할지 정해 실제 배치 스크립트에
# 인자를 그대로 넘긴다. 스킬·에이전트는 이 스크립트만 호출하면 백엔드를 몰라도 된다.
#
# Usage:
#   scripts/render_batch.sh <output_dir> "<image prompt>::<file>.png" [more...]
#   scripts/render_batch.sh --from-file <manifest.txt> <output_dir>
#
# 백엔드 선택 (env WEBTOON_RENDERER):
#   antigravity  Google Antigravity CLI(agy) — Google 계정 구독 쿼터, 별도 키 불필요
#   codex        codex CLI — ChatGPT OAuth 로그인 필요
#   zai          Z.ai GLM-Image API — ZAI_API_KEY 필요
#   auto (기본)  agy 설치됨 → antigravity, 아니면 codex 로그인 → codex, 아니면 ZAI_API_KEY → zai.
#                아무것도 없으면 오류.
#
# 종료 코드: 선택된 백엔드 스크립트의 종료 코드를 그대로 전달.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDERER="${WEBTOON_RENDERER:-auto}"

agy_available() {
  if command -v agy >/dev/null 2>&1; then return 0; fi
  [ -x "$HOME/.local/bin/agy" ] && return 0
  return 1
}

codex_available() {
  command -v codex >/dev/null 2>&1 || return 1
  # codex login status는 결과를 stderr로 출력하므로 2>&1 필수
  codex login status 2>&1 | grep -qi "logged in" || return 1
  return 0
}

zai_available() {
  [ -n "${ZAI_API_KEY:-}" ] && return 0
  [ -s "$HOME/.zai_api_key" ] && return 0
  return 1
}

case "$RENDERER" in
  antigravity)
    agy_available || { echo "agy CLI가 없다 — curl -fsSL https://antigravity.google/cli/install.sh | bash 로 설치할 것." >&2; exit 2; }
    echo "[render_batch] 백엔드: antigravity / agy (WEBTOON_RENDERER=antigravity)"
    exec "$SCRIPT_DIR/antigravity_imagegen_batch.sh" "$@"
    ;;
  codex)
    echo "[render_batch] 백엔드: codex (WEBTOON_RENDERER=codex)"
    exec "$SCRIPT_DIR/codex_imagegen_batch.sh" "$@"
    ;;
  zai)
    echo "[render_batch] 백엔드: zai / GLM-Image (WEBTOON_RENDERER=zai)"
    exec "$SCRIPT_DIR/zai_imagegen_batch.sh" "$@"
    ;;
  auto)
    if agy_available; then
      echo "[render_batch] 백엔드: antigravity / agy (auto — agy 설치 감지)"
      exec "$SCRIPT_DIR/antigravity_imagegen_batch.sh" "$@"
    elif codex_available; then
      echo "[render_batch] 백엔드: codex (auto — codex 로그인 감지)"
      exec "$SCRIPT_DIR/codex_imagegen_batch.sh" "$@"
    elif zai_available; then
      echo "[render_batch] 백엔드: zai / GLM-Image (auto — ZAI_API_KEY 감지)"
      exec "$SCRIPT_DIR/zai_imagegen_batch.sh" "$@"
    else
      echo "렌더 백엔드를 정할 수 없다. 셋 중 하나를 준비할 것:" >&2
      echo "  1) Antigravity CLI 설치 (curl -fsSL https://antigravity.google/cli/install.sh | bash) — 별도 키 불필요" >&2
      echo "  2) codex login                       (codex CLI 백엔드)" >&2
      echo "  3) export ZAI_API_KEY=...            (Z.ai GLM-Image 백엔드 — https://z.ai/model-api, 이미지당 과금)" >&2
      echo "또는 WEBTOON_RENDERER=antigravity|codex|zai 로 명시 선택." >&2
      exit 2
    fi
    ;;
  *)
    echo "WEBTOON_RENDERER=$RENDERER 는 유효하지 않다 (antigravity|codex|zai|auto)" >&2
    exit 2
    ;;
esac
