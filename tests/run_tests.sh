#!/usr/bin/env bash
# run_tests.sh — 렌더 배치 스크립트 회귀 테스트 (가짜 백엔드 E2E)
#
# Usage: bash tests/run_tests.sh
# 의존: bash, python3, file, md5(-r)/md5sum, sips(선택 — JPEG 수용 테스트)
#
# 백엔드 3종(codex/zai/antigravity)을 가짜 바이너리·가짜 API로 구동해
# 정상 경로와 결함 경로(중복·0바이트·손상·미생성·타임아웃·가드)를 검증한다.
# 모든 산출물은 임시 디렉토리에 생성되며 종료 시 정리된다.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../.zcode/skills/webtoon-panel-render/scripts"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wh-tests.XXXXXX")"
PASS=0
FAIL=0
ZAI_PORT=""
ZAI_PID=""

cleanup() {
  [ -n "$ZAI_PID" ] && kill "$ZAI_PID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

# ---------- 픽스처 생성 ----------
make_png() { # $1=경로 $2=w $3=h $4=상단 흰 행 수(0=전면 단색) — 픽스처 PNG 단일 빌더
  python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import struct, sys, zlib

def chunk(t, d):
    c = t + d
    return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

out, w, h, white = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
rows = []
for y in range(h):
    px = [255, 255, 255] * w if y < white else [200, 30, 30] * w
    rows.append(b"\x00" + bytes(px))
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(b"".join(rows)))
       + chunk(b"IEND", b""))
open(out, "wb").write(png)
PYEOF
}

make_fixtures() {
  make_png "$WORK/fixture.png" 8 8 0
  make_png "$WORK/matte.png" 20 20 10   # BL-07 매트용 — 상단 10행 순백
  if command -v sips >/dev/null 2>&1; then
    sips -s format jpeg "$WORK/fixture.png" --out "$WORK/fixture.jpeg" >/dev/null 2>&1
  fi
  [ -f "$WORK/fixture.png" ] || { echo "픽스처 생성 실패"; exit 1; }
}

# ---------- 검사 헬퍼 ----------
check() { # $1=시나리오명 $2=기대종료코드 $3=출력 포함 패턴(""=무시) $4=출력 비포함 패턴(""=무시) $5...=명령
  local name="$1" want_rc="$2" want_re="$3" avoid_re="$4"
  shift 4
  local out rc=0
  out=$("$@" 2>&1)
  rc=$?
  local ok=1 detail=""
  [ "$rc" = "$want_rc" ] || { ok=0; detail="exit=$rc(기대 $want_rc)"; }
  if [ -n "$want_re" ] && ! printf '%s' "$out" | grep -qE "$want_re"; then
    ok=0; detail="$detail +패턴미발견[$want_re]"
  fi
  if [ -n "$avoid_re" ] && printf '%s' "$out" | grep -qE "$avoid_re"; then
    ok=0; detail="$detail +금지패턴발견[$avoid_re]"
  fi
  if [ "$ok" = "1" ]; then
    PASS=$((PASS + 1)); echo "PASS  $name"
  else
    FAIL=$((FAIL + 1)); echo "FAIL  $name — $detail"
    printf '%s\n' "$out" | tail -5 | sed 's/^/      | /'
  fi
}

file_exists() { [ -f "$1" ] && [ -s "$1" ]; }

# ---------- 픽스처·서버 기동 ----------
make_fixtures
export FAKE_FIXTURE_PNG="$WORK/fixture.png"

python3 "$HERE/fakes/fake_zai_server.py" 18765 "$WORK/fixture.png" \
  "$([ -f "$WORK/fixture.jpeg" ] && echo "$WORK/fixture.jpeg" || echo "-")" &
ZAI_PID=$!
sleep 1

S="$SCRIPTS"
AGY_F="$HERE/fakes/fake_agy.sh"
CODEX_F="$HERE/fakes/fake_codex.sh"
ZAI_ENV=(ZAI_API_KEY=test-key ZAI_API_BASE=http://127.0.0.1:18765/api/paas/v4)

# agy 백엔드 공통 호출 헬퍼 — 표준 env(CONCURRENCY=5·fake agy) 고정. 특수 env가 필요한
# 시나리오(타임아웃·동시성 변경)는 인라인 env 호출을 유지한다.
run_agy() {
  env CONCURRENCY=5 AGY_BIN="$AGY_F" bash "$S/antigravity_imagegen_batch.sh" "$@"
}

# ---------- antigravity 백엔드 ----------
D="$WORK/t01"; mkdir -p "$D"
check "agy 정상 2장" 0 "총 2 / 유효 2 / 문제 0" "" \
  run_agy \
  "$D/out" "cat::a.png" "dog::b.png"
file_exists "$D/out/a.png" && { PASS=$((PASS+1)); echo "PASS  t01 파일 생성"; } || { FAIL=$((FAIL+1)); echo "FAIL  t01 파일 생성"; }

D="$WORK/t02"; mkdir -p "$D"
check "agy 웨이브 분할 3/3/1" 0 "wave 3: 항목 7~7" "" \
  env CONCURRENCY=3 AGY_BIN="$AGY_F" bash "$S/antigravity_imagegen_batch.sh" \
  "$D/out" "p1::p1.png" "p2::p2.png" "p3::p3.png" "p4::p4.png" "p5::p5.png" "p6::p6.png" "p7::p7.png"

D="$WORK/t03"; mkdir -p "$D"
check "agy md5 중복 감지" 1 "\[DUP\]" "" \
  run_agy \
  "$D/out" "x MARK_DUP::d1.png" "y MARK_DUP::d2.png"

D="$WORK/t04"; mkdir -p "$D"
check "agy 0바이트 감지" 1 "0바이트" "" \
  run_agy \
  "$D/out" "z MARK_ZERO::z.png" "w::w.png"

D="$WORK/t05"; mkdir -p "$D"
check "agy 손상 감지" 1 "이미지 아님" "" \
  run_agy \
  "$D/out" "j MARK_JUNK::j.png" "w::w.png"

D="$WORK/t06"; mkdir -p "$D"
check "agy 파일 미생성 감지" 1 "렌더 실패" "" \
  run_agy \
  "$D/out" "f MARK_FAIL::f.png" "w::w.png"

D="$WORK/t07"; mkdir -p "$D"
check "agy 타임아웃 감지" 1 "렌더 실패" "" \
  env CONCURRENCY=5 AGY_BIN="$AGY_F" MARK_SLEEP=8 RENDER_TIMEOUT_SECS=2 \
  bash "$S/antigravity_imagegen_batch.sh" "$D/out" "s MARK_SLEEP::s.png"

D="$WORK/t08"; mkdir -p "$D"
printf '고양이 MARK_JUNK::m_junk.png\n개::m_ok.png\n' > "$D/manifest.txt"
check "agy 매니페스트 모드" 1 "0바이트|이미지 아님" "" \
  run_agy \
  --from-file "$D/manifest.txt" "$D/out"

D="$WORK/t09"
check "동시성 6 거부" 2 "거부" "" \
  env CONCURRENCY=6 AGY_BIN="$AGY_F" bash "$S/antigravity_imagegen_batch.sh" \
  "$D/out" "p::a.png"

# ---------- codex 백엔드 ----------
D="$WORK/t10"; mkdir -p "$D"
check "codex 정상 2장" 0 "총 2 / 유효 2 / 문제 0" "" \
  env CONCURRENCY=5 CODEX_BIN="$CODEX_F" bash "$S/codex_imagegen_batch.sh" \
  "$D/out" "cat::a.png" "dog::b.png"

D="$WORK/t11"; mkdir -p "$D"
check "codex md5 중복 감지" 1 "\[DUP\]" "" \
  env CONCURRENCY=5 CODEX_BIN="$CODEX_F" bash "$S/codex_imagegen_batch.sh" \
  "$D/out" "x MARK_DUP::d1.png" "y MARK_DUP::d2.png"

# ---------- zai 백엔드 ----------
D="$WORK/t12"; mkdir -p "$D"
check "zai 정상 2장" 0 "총 2 / 유효 2 / 문제 0" "" \
  env "${ZAI_ENV[@]}" CONCURRENCY=5 bash "$S/zai_imagegen_batch.sh" \
  "$D/out" "cat::a.png" "dog::b.png"

D="$WORK/t13"; mkdir -p "$D"
check "zai API 오류 감지" 1 "렌더 실패" "" \
  env "${ZAI_ENV[@]}" CONCURRENCY=5 bash "$S/zai_imagegen_batch.sh" \
  "$D/out" "f MARK_FAILAPI::f.png" "w::w.png"

D="$WORK/t14"; mkdir -p "$D"
check "zai JPEG 수용" 0 "총 1 / 유효 1 / 문제 0" "" \
  env "${ZAI_ENV[@]}" CONCURRENCY=5 bash "$S/zai_imagegen_batch.sh" \
  "$D/out" "j MARK_JPEG::j.png"

TM="$WORK/t15_home"; mkdir -p "$TM"
D="$WORK/t15"; mkdir -p "$D"
check "zai 키 없음 거부" 2 "ZAI_API_KEY 미설정" "" \
  env -u ZAI_API_KEY HOME="$TM" CONCURRENCY=5 bash "$S/zai_imagegen_batch.sh" \
  "$D/out" "p::a.png"

# ---------- v11: 렌더 누적 원장 ----------
D="$WORK/t16"; mkdir -p "$D"
run_agy "$D/out" "alpha::a.png" >/dev/null 2>&1
run_agy "$D/out" "alpha::a.png" >/dev/null 2>&1
_ledger="$D/out/.render_logs/_ledger.tsv"
_metas=$(grep -c '^# META' "$_ledger" 2>/dev/null)
_arows=$(awk -F'\t' '$4=="a.png"' "$_ledger" 2>/dev/null | wc -l | tr -d ' ')
if [ "$_metas" = "2" ] && [ "$_arows" = "2" ]; then PASS=$((PASS+1)); echo "PASS  원장 누적(2배치 META·시도 2행)"; else FAIL=$((FAIL+1)); echo "FAIL  원장 누적 — META=$_metas rows=$_arows"; fi
_att2=$(awk -F'\t' '$4=="a.png" && $5==2' "$_ledger" 2>/dev/null | wc -l | tr -d ' ')
if [ "$_att2" = "1" ]; then PASS=$((PASS+1)); echo "PASS  시도 카운터(attempt=2 기록)"; else FAIL=$((FAIL+1)); echo "FAIL  시도 카운터 — att2=$_att2"; fi
if [ -s "$D/out/.render_logs/a_try1.log" ] && [ -s "$D/out/.render_logs/a_try2.log" ]; then PASS=$((PASS+1)); echo "PASS  try 로그 무충돌(try1·try2 공존)"; else FAIL=$((FAIL+1)); echo "FAIL  try 로그 무충돌"; fi
if grep -q 'backend=antigravity' "$_ledger" && grep -q 'concurrency=5' "$_ledger"; then PASS=$((PASS+1)); echo "PASS  META 행(백엔드·동시성)"; else FAIL=$((FAIL+1)); echo "FAIL  META 행"; fi
if [ -s "$D/out/.render_logs/_batch_summary.tsv" ] && [ "$(wc -l < "$D/out/.render_logs/_batch_summary.tsv" | tr -d ' ')" -ge 2 ]; then PASS=$((PASS+1)); echo "PASS  배치 요약 TSV"; else FAIL=$((FAIL+1)); echo "FAIL  배치 요약 TSV"; fi
_out3=$(run_agy "$D/out" "alpha::a.png" 2>&1)
if printf '%s' "$_out3" | grep -q '시도 3회차'; then PASS=$((PASS+1)); echo "PASS  재렌더 상한 3회 경고"; else FAIL=$((FAIL+1)); echo "FAIL  재렌더 상한 경고"; printf '%s\n' "$_out3" | tail -5 | sed 's/^/      | /'; fi

# ---------- v11: --resume ----------
D="$WORK/t17"; mkdir -p "$D"
run_agy "$D/out" "alpha::a.png" >/dev/null 2>&1
check "resume 동일 프롬프트 스킵" 0 "\[SKIP\] a\.png" "" \
  run_agy \
  --resume "$D/out" "alpha::a.png" "beta::b.png"
_arows=$(awk -F'\t' '$4=="a.png"' "$D/out/.render_logs/_ledger.tsv" 2>/dev/null | wc -l | tr -d ' ')
if [ "$_arows" = "1" ]; then PASS=$((PASS+1)); echo "PASS  resume 스킵은 원장 행 추가 없음"; else FAIL=$((FAIL+1)); echo "FAIL  resume 원장 — a.png rows=$_arows"; fi

D="$WORK/t18"; mkdir -p "$D"
run_agy "$D/out" "alpha::a.png" >/dev/null 2>&1
check "resume 프롬프트 변경 시 재렌더" 0 "유효 1 / 문제 0" "\[SKIP\]" \
  run_agy \
  --resume "$D/out" "alpha-changed::a.png"
_arows=$(awk -F'\t' '$4=="a.png"' "$D/out/.render_logs/_ledger.tsv" 2>/dev/null | wc -l | tr -d ' ')
if [ "$_arows" = "2" ]; then PASS=$((PASS+1)); echo "PASS  프롬프트 해시 변경 → 시도 2행"; else FAIL=$((FAIL+1)); echo "FAIL  프롬프트 해시 — rows=$_arows"; fi

# ---------- v11: panel_check.py (PIL 있는 경우만) ----------
if python3 -c "import PIL" >/dev/null 2>&1; then
  PC="$S/lib/panel_check.py"
  check "panel_check 정상(크기 오버라이드)" 0 "MATTE=none" "" \
    env PANEL_CHECK_SIZE=8x8 python3 "$PC" "$WORK/fixture.png"
  check "panel_check 매트 감지" 2 "MATTE=top" "" \
    python3 "$PC" "$WORK/matte.png"
  check "panel_check 크기 불일치" 3 "SIZE=8,8" "" \
    python3 "$PC" "$WORK/fixture.png"
  mkdir -p "$WORK/dircheck"
  cp "$WORK/fixture.png" "$WORK/dircheck/ok.png"
  cp "$WORK/matte.png" "$WORK/dircheck/bad.png"
  check "panel_check 디렉토리 모드" 1 "문제 1" "" \
    env PANEL_CHECK_SIZE=8x8 python3 "$PC" "$WORK/dircheck"
else
  echo "SKIP  panel_check 시나리오(PIL 미설치)"
fi

# ---------- 정리·결과 ----------
cleanup
echo "----------------------------------------"
echo "결과: PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
