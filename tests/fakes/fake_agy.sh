#!/usr/bin/env bash
# fake_agy.sh — antigravity_imagegen_batch.sh 테스트용 가짜 Antigravity CLI
#
# 프롬프트 내 마커로 동작을 제어한다:
#   MARK_ZERO  0바이트 파일 생성
#   MARK_JUNK  이미지가 아닌 텍스트 생성
#   MARK_DUP   모든 항목에서 동일 바이트 생성(md5 중복 유도)
#   MARK_FAIL  exit 1 (저장 없이 실패)
#   MARK_SLEEP N초 대기 후 저장(타임아웃 테스트)
#   기본       고유한 유효 PNG 생성(FAKE_FIXTURE_PNG 복사 + 항목별 salt)
set -u

prompt=""
prev=""
for a in "$@"; do
  case "$prev" in -p) prompt="$a";; esac
  prev="$a"
done

save=$(printf '%s' "$prompt" | grep -o 'Save it exactly to [^ ]*' | sed 's/^Save it exactly to //' | head -1)
if [ -z "$save" ]; then
  echo "fake_agy: save path not found" >&2
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
