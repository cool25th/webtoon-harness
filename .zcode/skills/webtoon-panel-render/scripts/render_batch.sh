#!/usr/bin/env bash
# render_batch.sh — 렌더 백엔드 디스패처 (codex ↔ Z.ai GLM-Image)
#
# 웹툰 하네스의 유일한 렌더 진입점. 어느 백엔드로 렌더할지 정해 실제 배치 스크립트에
# 인자를 그대로 넘긴다. 스킬·에이전트는 이 스크립트만 호출하면 백엔드를 몰라도 된다.
#
# Usage:
#   scripts/render_batch.sh <output_dir> "<image prompt>::<file>.png" [more...]
#   scripts/render_batch.sh --from-file <manifest.txt> <output_dir>
#
# 백엔드 선택 (env WEBTOON_RENDERER):
#   codex  (기본) codex CLI로 렌더 — codex login 상태 필요
#   zai    Z.ai GLM-Image API로 렌더 — ZAI_API_KEY 필요
#   auto   codex 로그인 상태면 codex, 아니면 ZAI_API_KEY가 있을 때 zai. 둘 다 없으면 오류.
#
# 종료 코드: 선택된 백엔드 스크립트의 종료 코드를 그대로 전달.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDERER="${WEBTOON_RENDERER:-auto}"

codex_available() {
  command -v codex >/dev/null 2>&1 || return 1
  codex login status 2>/dev/null | grep -qi "logged in" || return 1
  return 0
}

zai_available() {
  [ -n "${ZAI_API_KEY:-}" ]
}

case "$RENDERER" in
  codex)
    echo "[render_batch] 백엔드: codex (WEBTOON_RENDERER=codex)"
    exec "$SCRIPT_DIR/codex_imagegen_batch.sh" "$@"
    ;;
  zai)
    echo "[render_batch] 백엔드: zai / GLM-Image (WEBTOON_RENDERER=zai)"
    exec "$SCRIPT_DIR/zai_imagegen_batch.sh" "$@"
    ;;
  auto)
    if codex_available; then
      echo "[render_batch] 백엔드: codex (auto — codex 로그인 감지)"
      exec "$SCRIPT_DIR/codex_imagegen_batch.sh" "$@"
    elif zai_available; then
      echo "[render_batch] 백엔드: zai / GLM-Image (auto — ZAI_API_KEY 감지, codex 미로그인)"
      exec "$SCRIPT_DIR/zai_imagegen_batch.sh" "$@"
    else
      echo "렌더 백엔드를 정할 수 없다. 둘 중 하나를 준비할 것:" >&2
      echo "  1) codex login  (codex CLI 백엔드)" >&2
      echo "  2) export ZAI_API_KEY=...  (Z.ai GLM-Image 백엔드 — https://z.ai/model-api)" >&2
      echo "또는 WEBTOON_RENDERER=codex|zai 로 명시 선택." >&2
      exit 2
    fi
    ;;
  *)
    echo "WEBTOON_RENDERER=$RENDERER 는 유효하지 않다 (codex|zai|auto)" >&2
    exit 2
    ;;
esac
