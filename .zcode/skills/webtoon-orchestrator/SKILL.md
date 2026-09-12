---
name: webtoon-orchestrator
description: "웹툰 제작 에이전트 팀(27명)을 조율하는 메인 오케스트레이터. 인기 웹툰 트렌드 조사 → 대사 위주·고긴장·매 회차 반전 시나리오 작성 → 캐릭터 다각도 레퍼런스 시트를 먼저 렌더 → 회차당 50+ 패널을 말풍선·한글 대사 in-image 베이크로 동시 5장 병렬 렌더(백엔드: codex 또는 Z.ai GLM-Image 선택) → panel-validator 생성-검증 루프로 기준 만족까지 재생성 → 세로 스크롤 뷰어 조립까지 전 과정을 단계별 서브에이전트 디스패치로 운영한다. 트리거: '웹툰 만들어/제작', '웹툰 한 화/회차 만들어', '웹툰 시나리오부터 이미지까지', '웹툰 에피소드 제작', '웹툰 하네스 실행'. 후속 작업: '다음 화 만들어', '이 회차 다시/수정/보완', '반전 더 강하게', '패널 다시 그려', '특정 단계만 다시 실행', '이전 결과 기반 개선' 등에도 반드시 이 스킬을 사용. 단순 웹툰 추천/감상은 직접 응답."
---

# Webtoon Orchestrator — 웹툰 제작 팀 조율 (ZCode/GLM)

웹툰 한 회차를 트렌드 조사부터 완성 뷰어까지 만들어내는 통합 오케스트레이터. 27개 전문 에이전트를 **4개 단계별 팀**으로 순차 운영한다.

## 실행 모드: 메인 오케스트레이션 (서브에이전트 디스패치)

메인 에이전트(너)가 지휘자다. 팀원은 서브에이전트 스폰 도구(ZCode에서는 `Agent`, Claude Code에서는 `Task` — 인자와 동작 동일)로 띄우는 **서브에이전트**(`subagent_type: "general-purpose"`, 백그라운드는 `run_in_background: true`)다. 세션에 상시 팀이 존재하지 않고, 각 단계에서 필요한 역할을 그때 스폰해 산출물을 받고 정리한다. 이전 단계의 산출물은 `_workspace/`에 남으므로 다음 서브에이전트가 Read로 이어받는다.

**스폰 프롬프트 표준형** (모든 서브에이전트에 적용):

```
당신은 <역할명>이다. 먼저 아래 두 파일을 Read하고 정의·방법론을 그대로 따른다:
1. 역할 정의: .zcode/agents/<역할명>.md
2. 방법론 스킬: .zcode/skills/<스킬명>/SKILL.md

회차: ep{NN}
입력(먼저 Read): <상류 산출물 파일 경로들>
임무: <이번에 맡길 구체 작업>
산출: <출력 파일 경로>
완료 후 최종 메시지에 결과 요약(성공/실패, 파일 경로, 후속 권고)을 반드시 보고한다.
```

**디스패치 규약:**

- **병렬**: 서로 의존 없는 작업은 `run_in_background: true`로 동시 스폰한다. 완료 통지가 자동으로 오므로 **`sleep` 폴링 금지**. 통지를 모두 받으면 다음 단계로 진행한다.
- **순차**: 의존 있는 작업은 상류 완료 통지를 받은 뒤 스폰하고, 스폰 프롬프트에 상류 산출물 경로를 명시한다.
- **작업 보드**: `TodoWrite`로 현재 Phase와 진행 중인 서브에이전트 작업을 추적한다(작업 완료마다 갱신).
- **중계**: 서브에이전트끼리 직접 통신하지 않는다. 동료에게 전달할 내용은 보고에 담기고, 네가 다음 스폰 프롬프트에 넣어 중계한다. 백그라운드 서브에이전트에 후속 지시(REGEN 재렌더 등)가 필요하면 `SendMessage`를 쓴다.
- **렌더 동시성**: 렌더 백엔드 동시 세션 ≤5는 번들 스크립트 `.zcode/skills/webtoon-panel-render/scripts/render_batch.sh`가 강제한다. **panel-artist-a/b/c를 동시에 띄우지 않는다** — 반드시 한 명씩 순차 디스패치하고, 완료 보고를 받고 다음을 띄운다. 소량(1~5장) REGEN은 서브에이전트 없이 네가 직접 스크립트를 실행해도 된다.
- **렌더 백엔드**: antigravity(agy, Google 구독·별도 키 불필요 — 권장) / codex(ChatGPT OAuth) / zai(Z.ai GLM-Image, `ZAI_API_KEY`). 사용자 지정 > `WEBTOON_RENDERER` > auto(agy 설치 → codex 로그인 → ZAI_API_KEY 순)로 정한다. **한 회차는 한 백엔드로 끝까지** 렌더한다 — 중간 전환하면 작화 스타일이 흔들린다.
- **모델**: 별도 지정 없음 — 세션 모델(GLM)로 전 구간 실행한다.

## 에이전트 구성 (27명, 4팀)

| 팀 | 팀원 | 역할 | 스킬 | 주요 출력 |
|----|------|------|------|----------|
| **리서치팀** | trend-scout | 장르/트로프 동향 | webtoon-trend-research | 01_research/trend-scout.md |
| | platform-ranker | 플랫폼 랭킹·연재구조 | webtoon-trend-research | 01_research/platform-ranker.md |
| | audience-analyst | 독자층·이탈·몰입 | webtoon-trend-research | 01_research/audience-analyst.md |
| | hook-analyst | 후킹/반전 메커니즘 역설계 | webtoon-trend-research | 01_research/hook-analyst.md |
| | trend-synthesizer | 종합 기획 브리프 | webtoon-trend-research | 01_research/trend-brief.md |
| **시나리오팀** | concept-architect | 하이콘셉트/로그라인 | webtoon-scenario | 02_story/concept.md |
| | worldbuilder | 세계관·규칙 | webtoon-scenario | 02_story/world.md |
| | character-designer | 캐스트(외형+성격+아크) | webtoon-scenario | 02_story/characters.md |
| | series-plotter | 시리즈 아크·회차 맵 | webtoon-scenario | 02_story/series-arc.md |
| | twist-master | 매 회차 반전 설계 | webtoon-scenario | 02_story/twist-plan.md |
| | tension-engineer | 긴장 곡선·클리프행어 | webtoon-scenario | 02_story/tension-curve.md |
| | episode-outliner | 회차 비트시트(50+ 패널) | webtoon-scenario | 03_episode/ep{NN}_beatsheet.md |
| | dialogue-writer | 대사 위주 대본 | webtoon-scenario | 03_episode/ep{NN}_script.md |
| | script-editor | 교정·반전 명료성 | webtoon-scenario | 03_episode/ep{NN}_script_final.md |
| **비주얼팀** | art-director | 스타일 바이블·일관성 토큰·장소 토큰·말풍선 규약 | webtoon-panel-breakdown | 04_visual/style-bible.md, character-sheets.md |
| | ref-sheet-artist | 캐릭터 다각도/표정 레퍼런스 시트(패널 전 선행) | webtoon-panel-render | 04_visual/refs/*.png, refs/INDEX.md |
| | panel-director | 50+ 패널 샷리스트(scene_id/location) | webtoon-panel-breakdown | 04_visual/ep{NN}_shotlist.md |
| | letterer | in-image 말풍선/대사 베이크 명세 | webtoon-assembly | 04_visual/ep{NN}_lettering.md |
| | prompt-smith | 패널별 이미지 생성 프롬프트(베이크+장소+레퍼런스) | webtoon-panel-render | 04_visual/ep{NN}_prompts.md |
| | panel-artist-a | scene 그룹 A 렌더 | webtoon-panel-render | 05_panels/ep{NN}/panel_*.png |
| | panel-artist-b | scene 그룹 B 렌더 | webtoon-panel-render | 05_panels/ep{NN}/panel_*.png |
| | panel-artist-c | scene 그룹 C 렌더 | webtoon-panel-render | 05_panels/ep{NN}/panel_*.png |
| | panel-validator | 패널 6축 검증·재생성 루프 게이트 | webtoon-panel-render | 04_visual/ep{NN}_validation.md |
| **조립검수팀** | episode-compositor | 세로 스크롤 뷰어 조립 | webtoon-assembly | 06_assembly/ep{NN}/index.html |
| | quality-reviewer | QA 검수 | webtoon-assembly | 06_assembly/ep{NN}/qa_report.md |
| | continuity-manager | 회차 간 연속성 | webtoon-assembly | 06_assembly/continuity.md |
| | showrunner | 총괄·사인오프·패키징 | webtoon-assembly | RELEASE/ep{NN}/ |

## 워크플로우

### Phase 0: 컨텍스트 확인 (후속 작업 판별)

`_workspace/` 존재 여부와 사용자 요청으로 실행 모드를 정한다.

1. `_workspace/` 미존재 → **초기 실행**. Phase 1로.
2. `_workspace/` 존재 + "다음 화" 요청 → **새 회차 실행**. {NN}을 증가시키고, 02_story·style-bible·character-sheets·**refs/(레퍼런스 시트)**·continuity.md는 재사용(Read, 재렌더 금지 — 시리즈 일관성), 03_episode 이후만 새로 생성.
3. `_workspace/` 존재 + "이 회차의 OO만 다시" 요청 → **부분 재실행**. 해당 단계 역할만 재스폰하고, 그 산출물만 덮어쓴다. 하위 단계(예: 대본 수정 시 샷리스트→렌더→조립)는 영향받는 만큼만 재실행.
4. `_workspace/` 존재 + 새 기획 입력 → **새 기획 실행**. 기존 `_workspace/`를 `_workspace_{YYYYMMDD_HHMMSS}/`로 이동 후 Phase 1.

부분/새회차 재실행 시 이전 산출물 경로를 스폰 프롬프트에 포함해 "Read 후 개선점만 반영"을 지시한다.

### Phase 1: 준비

1. 사용자 입력 분석 — 회차 번호 {NN}, 장르 방향(있으면), 제약(수위·길이·톤).
2. `_workspace/00_input/brief.md`에 입력·회차 번호·제약을 기록.
3. 작업 디렉토리 보장: `mkdir -p _workspace/{00_input,01_research,02_story,03_episode,04_visual,05_panels,06_assembly,RELEASE}`.
4. **렌더 백엔드 사전 점검**(렌더가 포함되는 실행일 때): 백엔드를 정한다 — 사용자 지정("antigravity로"/"codex로"/"GLM·zai로") > `WEBTOON_RENDERER` > auto(agy 설치 → codex 로그인 → `ZAI_API_KEY`). antigravity면 `agy` 설치 확인(없으면 `curl -fsSL https://antigravity.google/cli/install.sh | bash` 안내, 첫 실행 시 Google 로그인). codex면 `codex --version`·`codex login status`(출력이 stderr) 확인 후 미로그인 시 재인증 요청. zai면 `ZAI_API_KEY` 확인 후 없으면 발급 안내. zai는 이미지 1장당 과금임을 미리 안내.

### Phase 2: 트렌드 리서치 (리서치팀)

1. 조사자 4명(trend-scout, platform-ranker, audience-analyst, hook-analyst)을 `run_in_background: true`로 **동시 스폰**. 각 스폰 프롬프트에 brief.md 경로와 자기 산출 경로(`01_research/<역할>.md`)를 명시.
2. 4개 완료 통지를 모두 받으면, trend-synthesizer를 스폰해 4개 산출물 경로를 전달 → 종합 `01_research/trend-brief.md`.
3. synthesizer 보고에 보강 요청이 있으면(불완전한 조사) 해당 조사자만 재스폰 → synthesizer 재스폰(최대 1회 반복).

### Phase 3: 시나리오 (시나리오팀)

파이프라인 의존에 따라 순차 스폰하되, 분기점에서 병렬화한다.

1. concept-architect → 완료 후 worldbuilder(concept.md 경로 전달) → 완료 후 character-designer(world.md 경로 전달).
2. character-designer 완료 후 series-plotter → 완료 후 **twist-master와 tension-engineer를 background 병렬 스폰**(series-arc 경로를 둘 다 전달).
3. 둘 다 완료되면 episode-outliner(twist-plan·tension-curve 경로 전달) → dialogue-writer(beatsheet·characters 경로 전달) → script-editor(script·twist-plan 경로 전달).
4. **매 회차 반전 보장**: twist-master의 twist-plan에 회차별 반전을 명시하고, script-editor가 script_final에서 반전이 명료하게 전달되는지 검수. 검수 보고에 반전 명료성 이슈가 있으면 twist-master/letterer 재스폰으로 반영.
5. **50+ 패널 분량 확보**: episode-outliner 스폰 프롬프트에 "비트를 충분히 쪼개 50패널 이상"을 명시. 보고된 비트/패널 수가 50 미만이면 재스폰해 추가 분할.
6. 최종 산출: `02_story/*`, `03_episode/ep{NN}_script_final.md`.

### Phase 4: 비주얼 프로덕션 (비주얼팀)

**렌더 동시성 ≤ 5 엄수 — 배치 스크립트가 강제하고, 아티스트는 순차 디스패치. 정한 백엔드(codex/zai)로 끝까지 렌더한다.**

1. art-director 스폰(script_final·characters 경로 전달) → `style-bible.md`(작화·**장소 토큰 LOC_***·**말풍선 시각 규약** 포함) + `character-sheets.md`(일관성 토큰+레퍼런스 사양).
2. **레퍼런스 시트 먼저(일관성 SSOT)**: ref-sheet-artist 스폰(character-sheets·style-bible 경로 전달) → 주요 캐릭터 다각도/표정 레퍼런스를 배치 스크립트로 렌더(동시 ≤5) → `04_visual/refs/` 확정 + INDEX.md. **후속 회차는 refs/가 이미 있으면 스킵하고 기존 INDEX.md를 재사용.** 패널 렌더는 레퍼런스 확정 후 시작.
3. **콘티+레터링 병렬**: panel-director와 letterer를 background 병렬 스폰. panel-director → `ep{NN}_shotlist.md`(50+ 패널, scene_id/location), letterer → `ep{NN}_lettering.md`(in-image 말풍선 베이크 명세, 한글 짧게).
4. **프롬프트 합성**: prompt-smith 스폰(style-bible·character-sheets·refs/INDEX.md·shotlist·lettering 경로 전달) → `ep{NN}_prompts.md`(스타일+장소토큰+캐릭터토큰&레퍼런스앵커+말풍선 베이크, scene 그룹 A/B/C 분배). **`no text` 금지(말풍선을 그려야 함)**, 부정은 `no English/gibberish/misspelled text`.
5. **렌더링 (순차 디스패치)**: panel-artist-a 스폰(그룹 A 패널 번호 목록 전달) → 아티스트가 배치 스크립트로 자기 그룹을 5장 웨이브 렌더 → 완료 보고 수신 → panel-artist-b → 완료 → panel-artist-c. 스크립트가 1차 무결성(0바이트/손상/md5 중복)을 검사하므로, 실패·중복 패널은 보고를 받아 즉시 재렌더 지시(해당 패널만, 1~5장이라면 네가 직접 스크립트 실행).
6. **검증-재생성 루프 (핵심)**: 각 아티스트 완료 보고가 올 때마다 panel-validator를 스폰해 6축(C1 캐릭터/레퍼런스, C2 배경·장소 연속성, C3 말풍선·한글 텍스트+통합 레터링, C4 프롬프트 충실도, C5 대사 흐름, C6 무결성·md5중복) 검증 → ACCEPT/REGEN 판정을 validation.md에 누적. REGEN 패널은 prompt-smith에게 보강을 시키거나(재스폰) validator의 수정 지시를 그대로 전달하고, 담당 그룹 패널만 재렌더 → validator 재스폰으로 재검증. **패널당 최대 3회**, 초과 시 ACCEPT-FLAG(통과+한계 기록).
7. 전 패널 통과 시 `04_visual/ep{NN}_validation.md` 완성. 산출물: `04_visual/*`, `05_panels/ep{NN}/panel_*.png`(검증 통과본).

### Phase 5: 조립 · 검수 (조립검수팀)

1. episode-compositor 스폰(검증 통과 패널 목록 전달) → (말풍선이 이미 베이크된) 패널 PNG를 **오버레이 없이** 세로 스크롤 `index.html`로 조립(간격·리듬만 설계).
2. quality-reviewer 스폰(index.html·validation.md 경로 전달) → panel-validator의 ACCEPT-FLAG를 먼저 파악하고, 회차 전체로 패널 수 50+, **레퍼런스 외형 일관성**, **배경 연속성**, **베이크 한글 텍스트 정확/가독**, **대사 흐름**, **반전 전달**, 손상/중복 이미지를 검수 → PASS/FIX/REDO 판정.
3. FIX/REDO 패널 → 지시를 중계해 루프 재투입(prompt-smith 보강+panel-artist/직접 재렌더 → panel-validator 재검증, 또는 해당 역할 재스폰). 최대 2회 루프. 반전이 안 드러나면 시나리오팀(twist-master/script-editor) 또는 letterer 재스폰으로 피드백.
4. continuity-manager 스폰 → `continuity.md` 갱신(회차 간 외형/설정/떡밥).
5. showrunner 스폰(qa_report·continuity 경로 전달) → 사인오프 후 `RELEASE/ep{NN}/`에 최종 패키징 + 다음 회차 시드(클리프행어 이어받기) 제안.

### Phase 6: 마무리

1. `_workspace/` 전체 보존(중간 산출물 = 감사 추적).
2. 사용자에게 결과 요약: 회차 제목·로그라인·반전 한 줄·패널 수·뷰어 경로(`RELEASE/ep{NN}/index.html`)·다음 회차 시드.
3. 피드백 요청: "반전 강도/대사 톤/작화 일관성에서 고치고 싶은 부분이 있나요?"

## 데이터 흐름

```
trend-brief.md
   └→ concept → world → characters → series-arc → {twist-plan, tension-curve}
                                                       └→ beatsheet → script → script_final
script_final + characters
   └→ style-bible(+장소토큰 LOC_*, 말풍선 규약)/character-sheets
        └→ refs/*.png (레퍼런스 시트, 패널 전 선행)
        └→ shotlist(scene_id/location) + lettering(in-image 말풍선 명세)
              └→ prompts(스타일+장소+레퍼런스앵커+말풍선 베이크, scene A/B/C)
                    └→ panel_*.png ⇄ panel-validator 6축 검증-재생성 루프
                          └→ validation.md (전 패널 통과)
panel_*.png(말풍선 포함) → index.html(오버레이 없음) → qa_report → RELEASE/ep{NN}/
```

## 에러 핸들링

| 상황 | 전략 |
|------|------|
| 서브에이전트 실패/비정상 종료 | 완료 통지 미수신 또는 비정상 보고 시, 같은 스폰 프롬프트에 "이전 시도가 실패했다"를 덧붙여 재스폰. 산출물 파일이 일부 있으면 경로를 알려 부분 재사용 유도 |
| 서브에이전트가 임무를 이탈한 보고 반환 | 스폰 프롬프트에 임무·산출 경로를 더 구체적으로 명시하고 재스폰. 2회 반복되면 해당 작업을 더 작은 단위로 쪼개 스폰 |
| codex 렌더 0바이트/손상 | 배치 스크립트 요약의 FAIL 패널만 재렌더(배치 전체 금지). 2회 실패 시 경고 후 통과, 보고서 명시 |
| codex 401 token_revoked(로그인 상태로 렌더 전면 실패) | `codex login status`는 로컬 토큰만 확인하므로 "Logged in"으로 나온다 — 사용자에게 `codex login` 재인증을 요청하고, 재인증 후 FAIL 패널만 재렌더 |
| zai 렌더 실패(API 오류·content filter·다운로드 실패) | 동일하게 FAIL 패널만 재렌더. content filter 반복 차단 패널은 프롬프트에서 수위 높은 표현을 완곡화해 재시도, 그래도 실패하면 ACCEPT-FLAG 대신 해당 패널 대사·연출 조정을 letterer/prompt-smith에 요청 |
| zai 요청 한도(429) 감지 | CONCURRENCY를 2~3으로 낮춰 재실행(스크립트의 CONCURRENCY env). 실패 패널만 남은 배치로 |
| 백엔드 중간 전환 요청 | 한 회차 안에서는 거절 — 작화 일관성이 무너진다. 다음 회차부터 전환하도록 안내 |
| 패널 md5 중복(서로 다른 패널이 동일 이미지) | 스크립트가 DUP으로 감지 → 중복 패널 삭제 후 각각 단독 재렌더(EP01 실제 발생) |
| 배경 급변(도로→실내 등) | panel-validator C2 REGEN → prompt-smith가 장소 토큰(LOC_*) 강화 후 그 패널만 재렌더 |
| 한글 말풍선 깨짐/오탈자 | panel-validator C3 REGEN → 텍스트 짧게·따옴표·굵게로 보강 재렌더. 3회 실패 시 가장 정확한 버전 ACCEPT-FLAG + 보고서 명시 |
| 캐릭터 외형 이탈 | panel-validator C1 REGEN → 레퍼런스 앵커·식별 표식 강조 후 재렌더 |
| codex 전체가 느림(450초+) | 플랜 한도 의심 → `codex login status` 확인, 배치 스크립트 재실행 시 남은 패널만 |
| 패널 50개 미만 | episode-outliner/panel-director 재스폰으로 비트 추가 분할 |
| 반전 불명확(QA REDO) | twist-master/script-editor 또는 letterer 재스폰으로 피드백 후 재작업 |
| 데이터 충돌 | 출처 병기, 삭제 금지 |
| 무한 재작업 | 패널당 재생성 최대 3회, 단계별 재작업 루프 최대 2회. 초과 시 현 상태로 진행하고 한계를 보고 |

## 테스트 시나리오

### 정상 흐름
1. 사용자: "트렌드 반영해서 웹툰 1화 만들어줘."
2. Phase 1: brief 기록, `_workspace/` 생성, 렌더 백엔드(codex/zai) 확인.
3. Phase 2: 조사자 4명 병렬 스폰 → synthesizer → trend-brief.md.
4. Phase 3: 시나리오 파이프라인 순차+병렬 스폰 → script_final.md (반전 1개+, 50+ 패널 분량).
5. Phase 4: art-director → 레퍼런스 시트 선행 → 콘티·레터링 병렬 → prompts → panel-artist-a/b/c 순차 디스패치(각 5장 웨이브, 스크립트가 무결성 검사) → panel-validator 6축 검증-재생성 루프로 전 패널 통과 → validation.md.
6. Phase 5: compositor → quality-reviewer PASS → continuity 갱신 → showrunner 사인오프 → RELEASE/ep01/.
7. 결과: `RELEASE/ep01/index.html` 세로 스크롤 웹툰(말풍선 포함) + 다음 화 시드.

### 에러 흐름 (배경 급변 + 한글 깨짐 재생성)
1. Phase 4 렌더 후 panel_023의 배경이 같은 씬(도로)인데 실내로 나오고, panel_031의 말풍선 한글이 깨짐.
2. panel-validator 보고: C2(023)·C3(031) REGEN → validation.md에 사유·수정 지시 기록.
3. prompt-smith 재스폰(또는 validator 지시 중계): 023에 장소 토큰(LOC_*) 강화, 031에 텍스트 따옴표·굵게·짧게 보강 → 2장만 배치 스크립트로 재렌더.
4. panel-validator 재스폰: 023 ACCEPT, 031은 3회까지도 일부 글자 흔들림 → 가장 정확한 버전 ACCEPT-FLAG + 보고서 명시.
5. 전 패널 통과 후 조립 진행, qa_report·RELEASE 노트에 플래그 패널 한계 명시.

## 후속 작업 가이드

- "다음 화" → Phase 0 case 2(새 회차). 세계관/스타일/연속성 재사용, 03_episode 이후만 신규.
- "반전 더 강하게" → 시나리오 부분 재실행(twist-master, script-editor 재스폰) → 영향 하위 단계 재실행.
- "패널 N번 다시" → prompt-smith 보강 + 배치 스크립트로 해당 패널 재렌더 + panel-validator 재검증 → 재조립.
- 같은 유형 피드백 2회+ 반복 시 해당 스킬/에이전트 정의 개선을 제안(하네스 진화). 변경은 AGENTS.md 변경 이력에 기록.
