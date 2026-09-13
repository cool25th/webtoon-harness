# 🎬 Webtoon Harness — 웹툰 자동 제작 하네스

> 트렌드 조사부터 세로 스크롤 뷰어 완성까지, 웹툰 한 회차를 **AI 에이전트 팀**이 단계별로 만들어내는 ZCode(GLM) 하네스.

원본 [revfactory/webtoon-harness](https://github.com/revfactory/webtoon-harness)는 Claude Code용으로 작성되었고, 이 저장소는 그를 **ZCode(GLM)에 맞게 전환·최적화한 fork**다. 어디를 어떻게 바꿨는지는 아래 [🔄 Claude Code 버전에서의 변경 사항](#-claude-code-버전에서의-변경-사항) 섹션에 정리했다.

**27개 전문 에이전트**와 **6개 스킬**로 구성되며, 인기 웹툰 트렌드 조사 → 대사 위주·고긴장·매 회차 반전 시나리오 작성 → 캐릭터 레퍼런스 시트 선행 렌더 → 회차당 50+ 패널을 말풍선·한글 대사 **in-image 베이크**로 병렬 렌더 → 생성-검증 루프로 재생성 → 세로 스크롤 뷰어 조립까지 전 과정을 자동화합니다.

![Webtoon Harness 개요](docs/images/01_overview.png)

---

## ✨ 특징

- **27 에이전트 / 4 단계 팀**: 리서치 → 시나리오 → 비주얼 → 조립검수. 각 Phase마다 팀을 재구성하며 운영합니다.
- **GLM 네이티브 오케스트레이션**: Claude Code 전용 팀 기능 없이, ZCode의 서브에이전트 디스패치(Agent 도구)만으로 27개 역할을 운영합니다. 전 구간 GLM으로 실행됩니다.
- **🎨 렌더 백엔드를 codex → Antigravity로 교체**: 원본의 codex 의존을 걷어내고, Google Antigravity CLI(agy)를 기본 렌더 백엔드로 적용했습니다. 별도 API 키·추가 과금 없이 Google 구독 쿼터만으로 패널을 렌더하며, 이미지 내 한글 텍스트 품질도 우수합니다(실측: 한글 말풍선 2장 렌더 성공). codex·Z.ai API는 대안 백엔드로 남겨두었습니다.
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
    ├── webtoon-panel-render/    # 이미지 병렬 렌더 (기본 antigravity, codex/zai 선택 — 번들 배치 스크립트 포함)
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
# 1) 시리즈 컨테이너를 만들고 하네스를 배치 (여러 이야기를 한 곳에서 관리)
git clone https://github.com/cool25th/webtoon-harness.git
mkdir webtoon-series && cp -r webtoon-harness/.zcode webtoon-harness/AGENTS.md webtoon-series/

# 2) 렌더 백엔드 설치·인증 원스톱 (대화형 — antigravity/codex/zai 중 선택)
bash webtoon-series/.zcode/skills/webtoon-panel-render/scripts/setup_backend.sh

# 3) webtoon-series를 워크스페이스로 ZCode 실행
```

새 이야기를 요청하면 오케스트레이터가 `webtoon-series/{스토리 제목}/` 폴더를 자동 생성하고, 그 안의 `_workspace/`와 `RELEASE/ep{NN}/`에 모든 산출물을 저장합니다. 이야기가 늘어나면 폴더만 늘어납니다:

```
webtoon-series/
├── .zcode/  AGENTS.md     ← 하네스 (시리즈 전체 공유)
├── 수능-편지-미스터리/      ← 이야기 1
│   └── _workspace/ … RELEASE/ep001/index.html
└── 야간-편의점/            ← 이야기 2
    └── _workspace/ …
```

그다음 ZCode 세션에서 자연어로 요청합니다:

- `"트렌드 반영해서 웹툰 1화 만들어줘"` — 전체 파이프라인 실행
- `"다음 화 만들어"` — 세계관/스타일/연속성 재사용, 새 회차 생성
- `"이 회차 반전 더 강하게"` — 시나리오팀 부분 재실행
- `"패널 23번 다시 그려"` — 해당 패널만 재렌더 + 재검증

`webtoon-orchestrator` 스킬이 자동으로 트리거되어, 메인 에이전트가 `Agent` 도구로 27개 역할의 서브에이전트를 단계별 스폰·조율합니다.

### ⚡ 빠른 설정 — 설치·인증 원스톱

위 2번 명령(`setup_backend.sh`)이 백엔드별 설치와 인증을 순서대로 안내합니다:

- **antigravity(기본)**: 공식 설치 스크립트가 `agy`를 설치 → 인증 확인용 테스트 호출 1회 실행, 처음이면 Google 브라우저 로그인이 열리고 완료하면 자동 계속
- **codex**: 없으면 npm 전역 설치(`npm install -g @openai/codex`) → `codex login` 브라우저 인증
- **zai**: 키를 붙여넣으면 실호출로 검증 후 `~/.zai_api_key`(권한 600)에 저장 — 렌더 스크립트가 환경변수 없이도 이 파일을 바로 읽고, 셸 프로필 등록도 선택 지원
- 현재 상태만 보려면: `bash .zcode/skills/webtoon-panel-render/scripts/setup_backend.sh --status`

### 요구 사항

- **ZCode** (GLM 기반 에이전트 실행 환경 — 서브에이전트 스폰·스킬 실행)
- **이미지 렌더 백엔드 — 셋 중 하나** (기본: Antigravity. 하네스 번들 배치 스크립트가 동시성 ≤5·타임아웃·무결성 검사를 강제합니다):
  - **Antigravity CLI** (기본) — `curl -fsSL https://antigravity.google/cli/install.sh | bash`. Google 계정 구독 쿼터 사용, 별도 API 키 불필요
  - **codex CLI** (대안, `WEBTOON_RENDERER=codex`) — `codex exec`의 `image_generation` 툴 + `codex login` 필요
  - **Z.ai API 키** (대안, `WEBTOON_RENDERER=zai`) — `export ZAI_API_KEY=...` ([z.ai/model-api](https://z.ai/model-api)에서 발급, GLM-Image 모델 사용)

---

## 🎨 렌더 백엔드: codex 대신 Antigravity 적용

**이 fork는 원본의 codex 렌더를 Antigravity(Google)로 교체해 기본 적용합니다.** codex CLI 재로그인도, 별도 API 키 발급·충전도 없이 Google 구독 쿼터만으로 전 파이프라인이 끝납니다.

| 백엔드 | 준비물 | 특징 |
|--------|--------|------|
| **antigravity** ⭐ **기본 적용** | [Antigravity CLI](https://antigravity.google/docs/cli/install/) 설치 (`curl -fsSL https://antigravity.google/cli/install.sh \| bash`) | Google 계정 구독 쿼터 사용, 별도 키·과금 불필요. 항목당 에이전트 실행이라 느리고(수십 초~수 분) Nano Banana 계열 이미지 생성 — 이미지 내 한글 텍스트 품질이 우수(실측: 한글 말풍선 2장 렌더, 1장 대사 완벽·1장 자모 1개 오차) |
| **codex** (대안) | codex CLI + `codex login` | 원본 하네스의 렌더 방식. 플랜 메시지 한도를 세션 단위로 소모. 쓰려면 `WEBTOON_RENDERER=codex` |
| **zai** (대안) | [Z.ai API 키](https://z.ai/model-api) + `export ZAI_API_KEY=...` | GLM-Image API 직 호출. 이미지 1장당 과금(약 $0.01~0.015/장). 기본 `glm-image` · `1056x1568`(세로 스크롤 패널) |

**선택 규칙**: 사용자 발언("antigravity로 그려" / "codex로 그려" / "GLM·zai로 그려") > `WEBTOON_RENDERER` 환경변수(`antigravity`|`codex`|`zai`|`auto`) > auto(기본값 — agy 설치 여부를 먼저 보고, 없으면 codex 로그인, 없으면 `ZAI_API_KEY`). **한 회차는 한 백엔드로 끝까지** 렌더합니다 — 중간에 바꾸면 작화 스타일이 흔들립니다. 검증 루프(0바이트/손상/md5 중복 → panel-validator 6축)는 백엔드와 무관하게 동일하게 적용됩니다.

### ❓ ZCode 구독(GLM 코딩 플랜)만으로 렌더가 되나요?

**이미지 렌더는 안 됩니다.** 실측으로 확인한 사실입니다:

- ZCode 구독(GLM 코딩 플랜)은 **코딩·텍스트 모델만** 포함합니다. 하네스의 오케스트레이션·시나리오·검증 등 전 단계는 이 구독으로 실행되고, 유료 API 키나 codex 없이 돌아갑니다.
- 이미지 생성 모델(GLM-Image · CogView-4)은 플랜에 포함되지 않고, [Z.ai API 플랫폼](https://docs.z.ai/guides/overview/pricing)의 이미지당 별도 과금($0.01~0.015/장)입니다.
- ZCode CLI가 저장한 구독 인증 토큰은 CLI 내부 전용(암호화 저장)이며, `api.z.ai` 이미지 엔드포인트에 직접 쓰면 `401 token expired or incorrect`가 반환됩니다(대조군인 코딩 엔드포인트에서도 동일 — API 직접 호출 경로가 아님).

따라서 렌더만 위 표의 두 백엔드 중 하나를 준비하면 되고, 파이프라인의 나머지 전부는 ZCode 구독 안에서 처리됩니다.

> 💡 이 저장소의 인포그래픽들은 `codex-image`로 16:9 비율 5장을 동시 병렬 렌더해 제작했습니다.

---

## 🍿 Claude Code에서 실행하기 (듀얼 부팅)

이 하네스는 ZCode(GLM) 기준이지만, **심볼릭 링크 2개**만으로 Claude Code에서도 동일하게 동작합니다. Claude Code는 `.claude/skills/`(스킬 자동 발견)·`.claude/agents/`(역할 정의)·`CLAUDE.md`(지침 파일)를 읽기 때문에, `.zcode/`와 `AGENTS.md`를 가리키게 하면 됩니다.

```bash
cd /path/to/your-project
git clone https://github.com/cool25th/webtoon-harness.git
cp -r webtoon-harness/.zcode webtoon-harness/AGENTS.md .

ln -s .zcode .claude          # Claude Code가 .claude/skills·.claude/agents를 읽도록
ln -s AGENTS.md CLAUDE.md     # Claude Code가 지침을 읽도록
```

- **스킬**: SKILL.md 포맷(`name`/`description` frontmatter)이 두 환경에서 동일해서 그대로 발견됩니다.
- **에이전트**: 오케스트레이터는 서브에이전트에게 `.zcode/agents/<역할>.md`를 **Read**시키는 방식이라 경로 그대로 동작합니다. `.claude/agents/` 링크가 있으면 Claude Code가 추가로 27개 역할을 커스텀 에이전트 타입으로도 등록합니다.
- **도구 이름 차이**: 서브에이전트 스폰 도구는 ZCode에서 `Agent`, Claude Code에서 `Task`지만, 인자(`subagent_type: "general-purpose"`, `run_in_background: true`)와 동작이 같아 스킬 본문 수정은 필요 없습니다 — 오케스트레이터에 두 이름을 병기해 뒀습니다. `TodoWrite`·`SendMessage`는 양쪽에 모두 있습니다.
- **모델**: Claude Code에서 실행하면 전 구간 Claude 모델로, ZCode에서 실행하면 GLM으로 돌아갑니다. 파이프라인·스킬·역할 정의는 동일합니다.
- **제거된 것 확인**: 원본이 쓰던 Claude 전용 팀 기능(`TeamCreate`/`TeamDelete`/`TaskCreate`)과 `model: opus` 지정은 전환 시 걷어냈으므로, Claude Code에서도 별도 되돌리기 없이 실행됩니다.

> ✅ **실측 검증**: 위 레이아웃을 Claude Code 2.1.220 헤드리스(`claude -p`)로 실제 확인했습니다 — `webtoon-orchestrator` 스킬 자동 발견, `Task` 도구로 `general-purpose` 서브에이전트 스폰, 서브에이전트의 `.zcode/agents/<역할>.md` Read 및 보고, 그리고 `.claude/agents/` 링크를 통한 27개 역할의 커스텀 에이전트 타입 등록까지 모두 동작합니다.

---

## 🎯 설계 원칙

- **대사 위주·고긴장·매 회차 반전**: 내레이션을 최소화하고 캐릭터 대사·행동으로 긴장과 정보, 반전을 전달합니다.
- **회차당 50+ 패널**: 세로 스크롤 리듬에 맞춰 비트를 충분히 쪼갭니다.
- **일관성 우선**: 레퍼런스 시트 → 일관성 토큰 → 장소 토큰을 모든 프롬프트에 주입하고, md5 중복·배경 급변·한글 깨짐을 검증 루프로 잡습니다.
- **감사 추적**: 모든 중간 산출물을 `_workspace/`에 보존합니다.

---

## 📝 라이선스

[MIT](LICENSE)
