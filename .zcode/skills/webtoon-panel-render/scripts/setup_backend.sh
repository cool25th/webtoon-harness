#!/usr/bin/env bash
# setup_backend.sh — 렌더 백엔드 설치·인증 원스톱 부트스트랩 (대화형)
#
# 하네스를 처음 받은 사람이 이 스크립트 하나로 렌더 백엔드를 설치하고 인증까지 마친다.
#
# Usage:
#   bash scripts/setup_backend.sh            # 대화형 메뉴
#   bash scripts/setup_backend.sh --status   # 상태 점검만 (설치·인증 안 함)
#
# 백엔드:
#   antigravity  Google Antigravity CLI(agy) — 기본. 공식 스크립트로 설치 + Google 브라우저 로그인
#   codex        codex CLI — npm 설치 + ChatGPT 브라우저 로그인
#   zai          Z.ai API 키 — 키 입력 → 실호출 검증 → ~/.zai_api_key(600) + 셸 프로필 등록
#
# Env:
#   ZAI_CODING_URL  키 검증용 코딩 엔드포인트 (기본 https://api.z.ai/api/coding/paas/v4/chat/completions)
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# z.ai 엔드포인트 상수 — 렌더 스크립트의 ZAI_API_BASE(이미지)와 함께 이 파일들의 유일한 소스.
ZAI_CODING_URL="${ZAI_CODING_URL:-https://api.z.ai/api/coding/paas/v4/chat/completions}"

# ---------- 공통 헬퍼 ----------
line() { printf '%s\n' "----------------------------------------------------------------"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

agy_bin() {
  if have_cmd agy; then echo "agy"; elif [ -x "$HOME/.local/bin/agy" ]; then echo "$HOME/.local/bin/agy"; else echo ""; fi
}

codex_status_text() {
  have_cmd codex || { echo "미설치"; return; }
  codex login status 2>&1 | grep -qi "logged in" && echo "로그인 됨(로컬 토큰)" || echo "미로그인"
}

zai_key_source() {
  if [ -n "${ZAI_API_KEY:-}" ]; then echo "환경변수"; return; fi
  if [ -s "$HOME/.zai_api_key" ]; then echo "파일(~/.zai_api_key)"; return; fi
  echo "없음"
}

print_status() {
  line
  echo "현재 백엔드 상태"
  line
  local agy; agy="$(agy_bin)"
  if [ -n "$agy" ]; then
    echo "  antigravity : 설치됨 ($agy) — 실렌더 시 Google 로그인 상태로 판정"
  else
    echo "  antigravity : 미설치 (기본 백엔드 — 설치 권장)"
  fi
  echo "  codex       : $(codex_status_text)"
  echo "  zai         : API 키 $(zai_key_source)"
  echo "  → 렌더 자동 선택 순서(auto): antigravity → codex → zai"
  line
}

# ---------- 백엔드별 설치·인증 ----------
setup_antigravity() {
  echo "== antigravity (기본 백엔드) =="
  local agy; agy="$(agy_bin)"
  if [ -z "$agy" ]; then
    echo "공식 설치 스크립트를 실행합니다 (macOS/Linux, ~/.local/bin/agy 설치):"
    curl -fsSL https://antigravity.google/cli/install.sh | bash || { echo "설치 실패 — 수동 설치 안내: https://antigravity.google/docs/cli/install/"; return 1; }
    agy="$(agy_bin)"
    [ -z "$agy" ] && { echo "설치 후에도 agy를 찾지 못했다. 터미널을 재시작하거나 PATH에 ~/.local/bin을 추가하세요."; return 1; }
  else
    echo "이미 설치됨: $agy"
  fi
  echo "인증 확인을 위해 테스트 호출을 1회 실행합니다. 처음이면 브라우저 Google 로그인이 열립니다 — 완료하면 자동으로 계속됩니다."
  local tmp; tmp="$(mktemp -d)"
  if ( cd "$tmp" && "$agy" --dangerously-skip-permissions -p "Reply with exactly: ok" ) >/dev/null 2>&1; then
    echo "인증 확인 완료 ✓ (Google 구독 쿼터로 렌더 가능)"
  else
    echo "테스트 호출 실패 — 브라우저 로그인이 끝났는지 확인 후 이 항목을 다시 실행하세요."
    return 1
  fi
  rm -rf "$tmp"
}

setup_codex() {
  echo "== codex (대안 백엔드) =="
  if ! have_cmd codex; then
    echo "codex CLI가 없습니다. npm 전역 설치를 진행할까요? [Y/n]"
    read -r ans
    case "$ans" in n*|N*) echo "건너뜀 — 수동 설치: https://github.com/openai/codex"; return 1;; esac
    have_cmd npm || { echo "npm이 없습니다 (Node.js 설치 필요)."; return 1; }
    npm install -g @openai/codex || { echo "npm 설치 실패"; return 1; }
  fi
  if codex login status 2>&1 | grep -qi "logged in"; then
    echo "이미 로그인 상태로 표시됩니다. (참고: 서버 측 토큰 폐기 시 첫 렌더에서 401 — 그때 'codex login' 재인증)"
  else
    echo "브라우저 로그인을 진행합니다 (완료하면 자동 복귀):"
    codex login || { echo "로그인 실패"; return 1; }
  fi
  codex login status 2>&1 | head -1
}

setup_zai() {
  echo "== zai / Z.ai GLM-Image (대안 백엔드) =="
  echo "Z.ai API 키를 붙여넣으세요 (https://z.ai/model-api 에서 발급, 이미지당 과금):"
  read -r key
  key="$(printf '%s' "$key" | tr -d '[:space:]')"
  [ -n "$key" ] || { echo "키가 비었다"; return 1; }
  echo "키 검증 중 (코딩 엔드포인트에 5토큰 테스트 호출)..."
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ZAI_CODING_URL" \
    -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
    -d '{"model":"glm-5.2","messages":[{"role":"user","content":"ok"}],"max_tokens":5}')
  if [ "$code" != "200" ]; then
    echo "검증 실패 (HTTP $code) — 키를 확인하세요. 저장하지 않았습니다."
    return 1
  fi
  printf '%s' "$key" > "$HOME/.zai_api_key"
  chmod 600 "$HOME/.zai_api_key"
  echo "저장 완료: ~/.zai_api_key (600) — 렌더 스크립트가 파일에서 바로 읽습니다."
  echo "셸 프로필에도 등록할까요? (새 터미널에서도 ZAI_API_KEY 자동 설정) [Y/n]"
  read -r ans
  case "$ans" in n*|N*) return 0;; esac
  local profile="$HOME/.zshrc"
  case "$(basename "${SHELL:-zsh}")" in bash) profile="$HOME/.bashrc";; fish) profile="$HOME/.config/fish/config.fish";; esac
  if grep -q "ZAI_API_KEY" "$profile" 2>/dev/null; then
    echo "$profile 에 이미 ZAI_API_KEY 항목이 있습니다 — 건너뜀."
  else
    printf '\nexport ZAI_API_KEY="%s"\n' "$key" >> "$profile"
    echo "등록 완료: $profile"
  fi
}

# ---------- 메인 ----------
cd "$(pwd)" || exit 1

if [ "${1:-}" = "--status" ]; then
  print_status
  exit 0
fi

cat <<'BANNER'
=== Webtoon Harness — 렌더 백엔드 설치·인증 ===
BANNER
print_status
cat <<'MENU'
설치·인증할 백엔드를 고르세요:
  1) antigravity  — 기본 백엔드 (권장: 별도 키·과금 없음)
  2) codex        — 대안 (ChatGPT 구독)
  3) zai          — 대안 (Z.ai API 키, 이미지당 과금)
  a) 모두 진단/설치 (1→2→3 순)
  q) 종료
MENU
printf '선택: '
read -r choice
case "$choice" in
  1) setup_antigravity ;;
  2) setup_codex ;;
  3) setup_zai ;;
  a|A)
    setup_antigravity; line
    setup_codex; line
    setup_zai
    ;;
  q|Q) exit 0 ;;
  *) echo "알 수 없는 선택"; exit 2 ;;
esac

print_status
echo ""
echo "완료 후 렌더 스모크 테스트(1장) 예시:"
echo "  .zcode/skills/webtoon-panel-render/scripts/render_batch.sh <출력디렉토리> \"프롬프트::파일명.png\""
echo "참고: 스킬은 ZCode 세션 시작 시 로드되므로, 회차 제작은 이 프로젝트에서 ZCode를 새로 시작하고"
echo "      '웹툰 1화 만들어줘'로 요청하면 됩니다."
