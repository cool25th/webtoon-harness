# Webtoon Harness — ZCode(GLM) 워크스페이스 지침

이 저장소는 **ZCode(GLM)용 웹툰 자동 제작 하네스**다. 이 지침 파일이 로드된 워크스페이스에서 웹툰 제작 요청이 오면 아래 규약을 따른다. Claude Code에서는 `.claude → .zcode`, `CLAUDE.md → AGENTS.md` 심볼릭 링크로 동일하게 동작한다(README "Claude Code에서 실행하기" 참고).

## 진입점

- 웹툰 제작·수정 요청 → `webtoon-orchestrator` 스킬(`.zcode/skills/webtoon-orchestrator/SKILL.md`)을 로드하고 그 워크플로우를 수행한다.
- 27개 역할 정의는 `.zcode/agents/<역할명>.md`에 있다. 서브에이전트 스폰 시 해당 정의를 Read하도록 지시한다.

## 하네스 불변 규약 (역할·스킬 수정 시에도 유지)

1. **모든 텍스트 in-image 베이크** — 말풍선·한글 대사는 이미지 생성 시 함께 그린다. HTML 오버레이·후작업 합성 금지. 부정 프롬프트는 `no text`가 아니라 `no English/gibberish/misspelled text`.
2. **렌더는 번들 디스패처 경유 + 동시성 ≤5** — 렌더는 `.zcode/skills/webtoon-panel-render/scripts/render_batch.sh`로만 수행한다. 백엔드는 antigravity(agy, 권장·별도 키 불필요) / codex(ChatGPT OAuth) / zai(`ZAI_API_KEY`), 선택은 사용자 지정 > `WEBTOON_RENDERER` > auto(agy → codex → zai) 순. **한 회차는 한 백엔드로 끝까지.** panel-artist는 순차 디스패치한다.
3. **레퍼런스 시트 선행** — 패널 렌더 전 `_workspace/04_visual/refs/`를 확정한다(시리즈 자산, 후속 회차 재사용).
4. **생성-검증 루프** — panel-validator 6축 통과 없이 조립으로 넘기지 않는다. 패널당 재생성 최대 3회, 단계별 루프 최대 2회.
5. **감사 추적** — 모든 중간 산출물을 `_workspace/`에 보존한다. 삭제하지 않는다.

## 서브에이전트 운영 규약 (ZCode)

- 스폰 프롬프트는 자기완결적으로: 역할 정의 경로 + 스킬 경로 + 입력 파일 경로 + 임무 + 산출 경로 + 최종 보고 요구.
- 독립 작업은 `run_in_background: true` 병렬, 의존 작업은 순차. `sleep` 폴링 금지.
- 서브에이전트 간 직접 통신 금지 — 산출물 파일 + 오케스트레이터 중계.

## 변경 이력

- 2026-09-12: claude-code용 하네스를 ZCode(GLM)용으로 전환. `.claude/` → `.zcode/`, TeamCreate/TaskCreate 팀 운영 → Agent 도구 서브에이전트 디스패치, `model: opus` 제거, codex 배치 스크립트 번들화(기존 `~/.claude/skills/codex-image` 의존 제거).
- 2026-09-12: 렌더 백엔드 선택 추가 — codex 외에 Z.ai GLM-Image API(`zai_imagegen_batch.sh`) 지원. 진입점은 `render_batch.sh` 디스패처(사용자 지정 > `WEBTOON_RENDERER` > auto). 한 회차는 한 백엔드로 끝까지 렌더.
- 2026-09-12: **antigravity 백엔드 추가**(권장) — Antigravity CLI(agy) 헤드리스로 Google 구독 쿼터만으로 렌더(별도 키·과금 불필요). `antigravity_imagegen_batch.sh` 신설, auto 우선순위 agy → codex → zai. 실측: 2패널 한글 말풍선 렌더 성공(1장 대사 완벽, 1장 자모 1개 오차 → REGEN 루프 권장).
