# 🎬 Webtoon Harness — 웹툰 자동 제작 하네스

> 트렌드 조사부터 세로 스크롤 뷰어 완성까지, 웹툰 한 회차를 **AI 에이전트 팀**이 단계별로 만들어내는 ZCode(GLM) 하네스.

원본 [revfactory/webtoon-harness](https://github.com/revfactory/webtoon-harness)는 Claude Code용으로 작성되었고, 이 저장소는 그를 **ZCode(GLM)에 맞게 전환·최적화한 fork**다. 어디를 어떻게 바꿨는지는 아래 [🔄 Claude Code 버전에서의 변경 사항](#-claude-code-버전에서의-변경-사항) 섹션에 정리했다.

**27개 전문 에이전트**와 **6개 스킬**로 구성되며, 인기 웹툰 트렌드 조사 → 대사 위주·고긴장·매 회차 반전 시나리오 작성 → 캐릭터 레퍼런스 시트 선행 렌더 → 회차당 50+ 패널을 말풍선·한글 대사 **in-image 베이크**로 병렬 렌더 → 생성-검증 루프로 재생성 → 세로 스크롤 뷰어 조립까지 전 과정을 자동화합니다.

![Webtoon Harness 개요](docs/images/01_overview.png)

---

## ✨ 특징

- **27 에이전트 / 4 단계 팀**: 리서치 → 시나리오 → 비주얼 → 조립검수. 각 Phase마다 팀을 재구성하며 운영합니다.
- **GLM 네이티브 오케스트레이션**: Claude Code 전용 팀 기능 없이, ZCode의 서브에이전트 디스패치(Agent 도구)만으로 27개 역할을 운영합니다. 전 구간 GLM으로 실행됩니다.
- **레퍼런스 시트 선행 렌더**: 캐릭터 다각도·표정 레퍼런스를 먼저 렌더해 회차 간 외형 일관성의 단일 진실원천(SSOT)을 확보합니다.
- **in-image 말풍선 베이크**: 말풍선과 한글 대사를 이미지 생성 시 함께 그려, 별도 텍스트 오버레이 없이 조립합니다.
- **병렬 렌더 + 생성-검증 루프**: 번들 배치 스크립트로 동시 5장씩 배치 렌더하고, `panel-validator`가 6축 검증 후 기준 미달 패널만 재생성합니다.
- **연속성 관리**: 회차를 넘어 캐릭터 외형·설정·떡밥(복선)을 누적 추적합니다.

---

## 📁 구조

```
.zcode/
├── agents/                      # 27개 전문 에이전트 정의 (서브에이전트가 Read하는 역할 문서)
│   ├── trend-scout.md           # 리서치팀
│   ├── concept-architect.md     # 시나리오팀
│   ├── art-director.md          # 비주얼팀
│   ├── panel-validator.md       # 생성-검증 게이트키퍼
│   ├── episode-compositor.md    # 조립검수팀
│   └── ... (총 27개)
└── skills/                      # 6개 방법론 스킬
    ├── webtoon-orchestrator/    # ⭐ 메인 오케스트레이터 (진입점)
    ├── webtoon-trend-research/  # 트렌드 리서치 방법론
    ├── webtoon-scenario/        # 시나리오·대본 집필
    ├── webtoon-panel-breakdown/ # 패널 분해·스타일/일관성 토큰
    ├── webtoon-panel-render/    # codex 병렬 렌더 (+ 번들 배치 스크립트 scripts/codex_imagegen_batch.sh)
    └── webtoon-assembly/        # 세로 스크롤 조립·검수·패키징
AGENTS.md                        # ZCode 워크스페이스 지침 (하네스 불변 규약)
```

---

## 🔄 Claude Code 버전에서의 변경 사항

원본은 Claude Code의 전용 기능(에이전트 팀)에 의존했고, 이 fork는 ZCode(GLM)에서 동일한 파이프라인이 돌아가도록 **에이전트 운영 계층만** 갈아엎었습니다. 웹툰 제작 방법론 자체(레퍼런스 SSOT, in-image 베이크, 6축 검증-재생성 루프, 연속성 관리)는 그대로 유지됩니다.

| 항목 | Claude Code 버전 (원본) | ZCode(GLM) 버전 (이 저장소) |
|------|------------------------|----------------------------|
| **실행 환경** | Claude Code | ZCode (GLM) |
| **디렉토리 규약** | `.claude/` | `.zcode/` — ZCode가 워크스페이스 스킬을 자동 발견 |
| **에이전트 팀 운영** | `TeamCreate`/`TeamDelete`/`TaskCreate`로 단계별 상시 팀 구성 | `Agent` 도구(`general-purpose`)로 필요한 역할을 그때 스폰하는 **서브에이전트 디스패치** |
| **모델 지정** | 에이전트마다 `model: opus` 명시 | 모델 지정 없음 — 세션 모델(GLM)로 전 구간 실행 |
| **통신 구조** | 팀원 간 `SendMessage` 직접 통신, 비주얼팀 리더가 결과 취합 | **스타 토폴로지**: 서브에이전트는 스폰 프롬프트로 임무를 받고 최종 보고로 회신. 상류 산출물은 파일 경로로 인계되며 메인 에이전트가 중계 |
| **서브에이전트 로딩** | `.claude/agents/*.md`가 커스텀 에이전트 타입으로 자동 등록 | 역할 정의를 일반 문서로 두고, 스폰 프롬프트가 "먼저 Read하라"고 지시 (등록 메커니즘 비의존 — 어느 환경서든 동작) |
| **작업 관리** | `TaskCreate` 작업 보드 + 작업 의존성 | `TodoWrite` 진행 보드 + 오케스트레이터의 순차/병렬 디스패치 규약 |
| **병렬 처리** | 배경 작업 완료 통지 기반 (`sleep` 폴링 금지) | 동일 — 리서치 4인·콘티+레터링 병렬은 `run_in_background`로 유지 |
| **렌더 인프라** | 외부 스킬 `~/.claude/skills/codex-image`의 배치 헬퍼 의존 | **번들 스크립트** `webtoon-panel-render/scripts/codex_imagegen_batch.sh` — 동시성 5 강제(`CONCURRENCY>5` 거부), 항목당 타임아웃 감시, 0바이트/손상/md5 중복 자동 검사 내장 |
| **워크스페이스 지침** | CLAUDE.md | `AGENTS.md` (하네스 불변 규약 + 변경 이력 기록) |
| **이미지 생성 백엔드** | codex CLI (`codex exec image_generation`) | 동일하게 codex CLI 유지 — GLM 최적화는 에이전트 하네스 계층이며, 렌더 품질·비용 구조는 원본과 같다 |

전환의 부수 효과로, 오케스트레이터가 환경 전용 API 없이 범용 도구(Agent 스폰 + 파일 인계 + 보고 회신)만 쓰기 때문에 다른 에이전트 CLI로의 이식성도 원본보다 좋아졌습니다.

---

## 👥 에이전트 팀 (27명, 4팀)

| 팀 | 팀원 | 역할 |
|----|------|------|
| **리서치팀** | trend-scout, platform-ranker, audience-analyst, hook-analyst, trend-synthesizer | 장르 동향·플랫폼 랭킹·독자 반응·후킹/반전 역설계 → 기획 브리프 종합 |
| **시나리오팀** | concept-architect, worldbuilder, character-designer, series-plotter, twist-master, tension-engineer, episode-outliner, dialogue-writer, script-editor | 하이콘셉트·세계관·캐릭터·시리즈 아크·매 회차 반전·긴장 곡선·비트시트·대사 대본·교정 |
| **비주얼팀** | art-director, ref-sheet-artist, panel-director, letterer, prompt-smith, panel-artist-a/b/c, panel-validator | 스타일 바이블·레퍼런스 시트·샷리스트·레터링·프롬프트 합성·패널 렌더·6축 검증 루프 |
| **조립검수팀** | episode-compositor, quality-reviewer, continuity-manager, showrunner | 세로 스크롤 뷰어 조립·QA 검수·연속성 관리·사인오프 패키징 |

### 🔍 리서치팀 — 4명 조사 → 1명 종합

4명의 조사자(트렌드·플랫폼 랭킹·독자 반응·후킹/반전)가 병렬로 조사하고, synthesizer가 하나의 기획 브리프로 종합합니다.

![리서치팀](docs/images/02_research.png)

### ✍️ 시나리오팀 — 컨셉에서 최종 대본까지

하이콘셉트에서 출발해 세계관·캐릭터·시리즈 아크를 거쳐 반전 계획과 긴장 곡선을 병렬 설계하고, 비트시트→대본→최종본으로 수렴합니다. **매 회차 반전**과 **50+ 패널 분량**을 보장합니다.

![시나리오팀](docs/images/03_scenario.png)

### 🎨 비주얼팀 — 레퍼런스 선행 + 생성-검증 루프

아트 디렉터의 스타일 바이블 → 캐릭터 레퍼런스 시트 선행 렌더 → 샷리스트·레터링 → 프롬프트 합성 → 3명의 아티스트가 codex로 동시 5장 병렬 렌더 → panel-validator가 6축 검증·재생성 루프를 돌립니다. 말풍선은 이미지에 함께 그려집니다(in-image 베이크).

![비주얼팀](docs/images/04_visual.png)

### 🧩 조립검수팀 — 조립에서 릴리스까지

말풍선이 베이크된 패널을 세로 스크롤 뷰어로 조립하고, QA 검수·연속성 관리를 거쳐 showrunner가 최종 사인오프 후 RELEASE로 패키징합니다.

![조립검수팀](docs/images/05_assembly.png)

---

## 🔄 워크플로우

```
trend-brief.md
   └→ concept → world → characters → series-arc → {twist-plan, tension-curve}
                                                      └→ beatsheet → script → script_final
script_final + characters
   └→ style-bible(+장소토큰, 말풍선 규약) / character-sheets
        └→ refs/*.png (레퍼런스 시트, 패널 전 선행)
        └→ shotlist(scene_id/location) + lettering(in-image 말풍선 명세)
              └→ prompts(스타일+장소+레퍼런스앵커+말풍선 베이크, scene A/B/C)
                    └→ panel_*.png ⇄ panel-validator 6축 검증-재생성 루프
                          └→ validation.md (전 패널 통과)
panel_*.png(말풍선 포함) → index.html(오버레이 없음) → qa_report → RELEASE/ep{NN}/
```

**6단계 실행:** Phase 0(컨텍스트 확인) → 1(준비) → 2(리서치) → 3(시나리오) → 4(비주얼) → 5(조립·검수) → 6(마무리).

---

## 🚀 사용 방법

이 저장소는 [ZCode](https://z.ai) 하네스입니다. `.zcode/` 디렉토리와 `AGENTS.md`를 작업 프로젝트 루트에 두고 ZCode를 실행하세요.

```bash
# 1) 하네스를 프로젝트에 배치
git clone https://github.com/revfactory/webtoon-harness.git
cp -r webtoon-harness/.zcode webtoon-harness/AGENTS.md /path/to/your-project/

# 2) 해당 프로젝트를 워크스페이스로 ZCode 실행
```

그다음 ZCode 세션에서 자연어로 요청합니다:

- `"트렌드 반영해서 웹툰 1화 만들어줘"` — 전체 파이프라인 실행
- `"다음 화 만들어"` — 세계관/스타일/연속성 재사용, 새 회차 생성
- `"이 회차 반전 더 강하게"` — 시나리오팀 부분 재실행
- `"패널 23번 다시 그려"` — 해당 패널만 재렌더 + 재검증

`webtoon-orchestrator` 스킬이 자동으로 트리거되어, 메인 에이전트가 `Agent` 도구로 27개 역할의 서브에이전트를 단계별 스폰·조율합니다.

### 요구 사항

- **ZCode** (GLM 기반 에이전트 실행 환경 — 서브에이전트 스폰·스킬 실행)
- **codex CLI** (`codex exec`의 `image_generation` 툴) — 패널 이미지 병렬 렌더. ChatGPT OAuth 인증 필요. codex 전역 동시 세션은 **최대 5개**를 지키며, 하네스 번들 배치 스크립트(`.zcode/skills/webtoon-panel-render/scripts/codex_imagegen_batch.sh`)가 이 한도를 강제합니다.

> 💡 이 저장소의 인포그래픽들은 `codex-image`로 16:9 비율 5장을 동시 병렬 렌더해 제작했습니다.

---

## 🎯 설계 원칙

- **대사 위주·고긴장·매 회차 반전**: 내레이션을 최소화하고 캐릭터 대사·행동으로 긴장과 정보, 반전을 전달합니다.
- **회차당 50+ 패널**: 세로 스크롤 리듬에 맞춰 비트를 충분히 쪼갭니다.
- **일관성 우선**: 레퍼런스 시트 → 일관성 토큰 → 장소 토큰을 모든 프롬프트에 주입하고, md5 중복·배경 급변·한글 깨짐을 검증 루프로 잡습니다.
- **감사 추적**: 모든 중간 산출물을 `_workspace/`에 보존합니다.

---

## 📝 라이선스

[MIT](LICENSE)
