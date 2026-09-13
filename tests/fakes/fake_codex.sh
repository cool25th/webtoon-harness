#!/usr/bin/env bash
# fake_codex.sh — codex_imagegen_batch.sh 테스트용 가짜 codex CLI
#
# codex_imagegen_batch.sh는 다음 형태로 호출한다:
#   $CODEX_BIN exec --sandbox workspace-write --skip-git-repo-check --cd <root> -o <md> "<instruction>"
#
# 프롬프트 내 마커 동작은 fake_agy.sh와 동일(MARK_ZERO/JUNK/DUP/FAIL/SLEEP).
set -u

prompt=""
prev=""
for a in "$@"; do
  case "$prev" in
    exec|--sandbox|--skip-git-repo-check|--cd|-o) ;;  # 플래그 값 무시
    *) [ ${#a} -gt ${#prompt} ] && prompt="$a" ;;
  esac
  prev="$a"
done

save=$(printf '%s' "$prompt" | grep -o '[-A-Za-z0-9_가-힣/.]*\.png' | tail -1)
if [ -z "$save" ]; then
  echo "fake_codex: save path not found" >&2
  exit 1
fi
mkdir -p "$(dirname "$save")"

case "$prompt" in
  *MARK_FAIL*) exit 1 ;;
  *MARK_ZERO*) : > "$save"; echo "$save"; exit 0 ;;
  *MARK_JUNK*) printf 'not an image at all' > "$save"; echo "$save"; exit 0 ;;
esac

if [ "${MARK_SLEEP:-}" != "" ]; then
  sleep "$MARK_SLEEP"
fi

fixture="${FAKE_FIXTURE_PNG:?FAKE_FIXTURE_PNG 필요}"
case "$prompt" in
  *MARK_DUP*) cp "$fixture" "$save" ;;
  *)          cp "$fixture" "$save"; printf '%s' "$(basename "$save")" >> "$save" ;;
esac
echo "$save"
