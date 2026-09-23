# Webtoon Harness — ZCode(GLM) 워크스페이스 지침

이 저장소는 **ZCode(GLM)용 웹툰 자동 제작 하네스**다. 이 지침 파일이 로드된 워크스페이스에서 웹툰 제작 요청이 오면 아래 규약을 따른다. Claude Code에서는 `.claude → .zcode`, `CLAUDE.md → AGENTS.md` 심볼릭 링크로 동일하게 동작한다(README "Claude Code에서 실행하기" 참고).

## 스토리 디렉토리 구조

이야기는 `webtoon-series/{스토리}/` 폴더 단위로 저장한다. 하네스(.zcode)는 webtoon-series 루트에서 시리즈 전체를 공유한다.

> **series 워크스페이스의 `.zcode`는 이 저장소를 가리키는 심볼릭 링크다(2026-09-23 전환)** — `webtoon-series/.zcode` → `../webtoon-harness/.zcode`(단일 소스: 사본 드리프트 방지, 서브에이전트 Read·스크립트 실행 실측 통과). 이 레이아웃에서 하네스 수정은 곧 이 저장소의 작업분이 되므로 **세션 종료 전 커밋·푸시로 영구화**한다. 링크가 깨지면 `cd webtoon-series && ln -s ../webtoon-harness/.zcode .zcode`로 복구.

```
webtoon-series/            ← 워크스페이스 (여기서 ZCode 실행)
├── .zcode/  AGENTS.md     ← 하네스 (시리즈 전체 공유)
├── {스토리A}/              ← 이야기별 폴더 (오케스트레이터가 자동 생성)
│   └── _workspace/ … RELEASE/ep{NN}/
└── {스토리B}/
```

- 새 이야기 요청 시 오케스트레이터가 `{스토리}/_workspace/` 구조를 자동 생성한다.
- 모든 산출물 경로는 `webtoon-series/{스토리}/...` 전체 상대경로로 전달한다(스토리 혼입 방지).

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

- 2026-09-23: **하네스 단일 소스 전환(심볼릭 링크)** — series `.zcode` 사본을 폐지하고 이 저장소 `.zcode`로 연결(사본 드리프트 방지 — 블랙리스트·뷰어 템플릿 드리프트 사례 해소). 동시에 중복·하드코딩 정리: zai 코딩 엔드포인트 URL 상수화(`ZAI_CODING_URL`), save_path/stem 헬퍼 공통화, 죽은 버전 폴백 삭제, 테스트 픽스처 빌더·런처 헬퍼 통합(af45a8e·defdfc1).
- 2026-09-12: claude-code용 하네스를 ZCode(GLM)용으로 전환. `.claude/` → `.zcode/`, TeamCreate/TaskCreate 팀 운영 → Agent 도구 서브에이전트 디스패치, `model: opus` 제거, codex 배치 스크립트 번들화(기존 `~/.claude/skills/codex-image` 의존 제거).
- 2026-09-12: 렌더 백엔드 선택 추가 — codex 외에 Z.ai GLM-Image API(`zai_imagegen_batch.sh`) 지원. 진입점은 `render_batch.sh` 디스패처(사용자 지정 > `WEBTOON_RENDERER` > auto). 한 회차는 한 백엔드로 끝까지 렌더.
- 2026-09-12: **antigravity 백엔드 추가**(권장) — Antigravity CLI(agy) 헤드리스로 Google 구독 쿼터만으로 렌더(별도 키·과금 불필요). `antigravity_imagegen_batch.sh` 신설, auto 우선순위 agy → codex → zai. 실측: 2패널 한글 말풍선 렌더 성공(1장 대사 완벽, 1장 자모 1개 오차 → REGEN 루프 권장).
- 2026-09-13: **webtoon-series 멀티 스토리 구조** — 이야기를 `webtoon-series/{스토리}/` 폴더 단위로 저장(오케스트레이터가 신규 이야기 시 자동 생성, 하네스는 시리즈 전체 공유). 스폰 프롬프트·스크립트 인자는 SDIR prefix 전체 경로 필수.
- 2026-09-13: **설치·인증 원스톱 부트스트랩** `setup_backend.sh` 신설 — 백엔드별 설치·로그인·키 검증을 대화형으로 수행, `--status` 진단 모드. zai 키를 `~/.zai_api_key`(600) 파일로도 읽도록 zai 스크립트·디스패처 보강(셸 재시작 없이 인증 적용). 클린 클론 이식성 실측 완료(클론→복사→실렌더 성공).
- 2026-09-13: **렌더 백엔드 공통부 추출** — 3종 배치 스크립트의 복제 로직을 `webtoon-panel-render/scripts/lib/common.sh`로 분리(백엔드 3종 728줄 → 268줄 + 공통 214줄, scripts/ 총 974→728줄). 타임아웃 env를 `RENDER_TIMEOUT_SECS`로 통일(구 `*_TIMEOUT_SECS`도 인식), 이미지 포맷 검사는 PNG|JPEG로 단일화, 동시성 가드 문구 통일. 신구 동작 패리티 72케이스 + agy 실렌더 검증.
- 2026-09-13: **agy 저장 누락 수정** — Antigravity print(텍스트) 모드에서 이미지 생성 후 파일 저장이 누락되는 실측 문제(텍스트 모드 5회 연속 "파일 미생성")를 `--output-format json`으로 회피(json 모드 2/2 성공). 리팩터 검증 중 실렌더 스모크로 발견.
