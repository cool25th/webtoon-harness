---
name: webtoon-panel-render
description: "웹툰 패널 이미지를 선택한 렌더 백엔드(codex exec image_generation 또는 Z.ai GLM-Image API)로 동시 5장씩 병렬 렌더링하는 스킬. 패널 렌더 전 캐릭터 다각도 레퍼런스 시트를 먼저 렌더해 일관성 기준을 만들고, 패널 프롬프트 목록(ep{NN}_prompts.md)에 일관성 토큰·레퍼런스 앵커·씬 장소 토큰·in-image 말풍선(한글 대사 포함)을 주입해 배치 생성하며, panel-validator의 생성-검증 루프로 기준 만족까지 재렌더한다. 어느 백엔드든 전역 동시 세션 5개 한도를 지키고 0바이트·손상·md5 중복 PNG를 재시도한다. '패널 렌더링', '웹툰 이미지 생성', '레퍼런스 시트', '패널 이미지 배치 생성', '50장 그리기', 'codex로 패널 그려', 'GLM으로/zai로 패널 그려', 그리고 후속 작업 '패널 다시 그려/재렌더/수정/일부만 다시'에도 반드시 이 스킬을 사용. 단일 단발 이미지나 정밀 마스킹 편집은 이 하네스의 범위가 아니다."
---

# Webtoon Panel Render — 레퍼런스 → 베이크 렌더 → 검증 루프

웹툰 한 회차의 50+ 패널을 선택한 렌더 백엔드로 **동시 5장씩** 빠르게 렌더링하는 스킬. prompt-smith가 만든 패널 프롬프트 목록을 입력으로, 일관성을 지키며 PNG를 양산하고 검증한다.

이 스킬은 자체 번들 배치 스크립트로 렌더를 수행한다 — 외부 스킬·외부 경로 의존이 없다. 렌더 백엔드는 셋 중 하나:

- **antigravity**(기본, 별도 키 불필요) — Google Antigravity CLI(agy)의 헤드리스 에이전트. Google 계정 구독 쿼터 소비, 키체인 자동 로그인. `scripts/antigravity_imagegen_batch.sh`. 설치: `curl -fsSL https://antigravity.google/cli/install.sh | bash`
- **codex**(ChatGPT OAuth 필요) — `scripts/codex_imagegen_batch.sh`
- **zai**(Z.ai GLM-Image API, `ZAI_API_KEY` 필요) — `scripts/zai_imagegen_batch.sh`. 기본 모델 `glm-image`, 기본 크기 `1056x1568`(세로 스크롤 패널). `ZAI_IMAGE_QUALITY=standard`로 고속 모드.
- **선택**: 세 스크립트를 직접 쓰지 말고 디스패처 `scripts/render_batch.sh`를 호출한다. `WEBTOON_RENDERER` 환경변수(`antigravity`|`codex`|`zai`|`auto`, 기본 `auto`)로 백엔드를 고른다 — auto는 agy 설치 → antigravity, codex 로그인 → codex, `ZAI_API_KEY` → zai 순으로 고른다. 사용자가 백엔드를 지정하면 그 값을 쓴다.
- 세 백엔드 스크립트는 인터페이스가 동일하다: 임의 개수 항목을 동시 5장 웨이브 실행, 항목당 타임아웃 감시(공통 env `RENDER_TIMEOUT_SECS`), 완료 후 0바이트/손상(PNG·JPEG 허용)/**md5 중복** 자동 검사·요약 보고. 웨이브·타임아웃·무결성·요약 공통 로직은 `scripts/lib/common.sh`에 있고, 각 백엔드 스크립트는 자기 렌더 함수만 정의한다. 모든 실행은 **누적 원장**(`.render_logs/_ledger.tsv`)에 기록된다 — 백엔드·버전·프롬프트 해시·시도 횟수·md5·상태(아래 "렌더 원장과 무손실 재개" 참조).

핵심 4원칙(EP01 제작 피드백 반영):
1. **레퍼런스 먼저(일관성).** 패널을 그리기 전에 캐릭터 다각도/표정 레퍼런스 시트를 먼저 렌더해 외형 기준(SSOT)을 확정한다. 텍스트 토큰만으로는 매번 다른 얼굴이 나온다.
2. **모든 텍스트 in-image 베이크(후작업 절대 금지).** 말풍선 대사·효과음·화면 UI·환경 문자 등 **모든 텍스트를 이미지 생성 시 작화에 함께 그린다**(HTML 오버레이도, 포토샵 타이핑도, 어떤 후작업 합성도 없다). 그래서 "no text" 부정 프롬프트를 쓰지 않는다. 또한 결과가 **베이크처럼 보여야** 한다 — 텍스트는 작화와 같은 손그림 잉크 톤으로 녹아들어야 하고, 깨끗한 디지털 폰트를 평평하게 얹은 "붙여넣기" 느낌이면 실패(통합 레터링, EP01 P30·P33 피드백).
3. **배경 씬 단위 고정.** 씬별 장소 토큰(LOC_*)을 모든 패널에 주입해 배경 급변(도로→실내 등)을 막는다.
4. **검증-재생성 루프.** panel-validator가 패널을 8축으로 검사하고 미달분을 기준 만족까지 되돌려 재렌더한다.

## 사전 점검 (회차당 1회)

먼저 렌더 백엔드를 정한다. 사용자 지정("antigravity로 그려" / "codex로 그려" / "GLM·zai로 그려") > `WEBTOON_RENDERER` > auto 순으로 따른다.

**antigravity 백엔드일 때:** `agy` 설치 여부만 확인한다(`command -v agy` 또는 `~/.local/bin/agy`). 없으면 `curl -fsSL https://antigravity.google/cli/install.sh | bash` 설치를 안내한다. 첫 실행 시 브라우저 Google 로그인이 필요할 수 있다(이후 Keychain 자동). 항목당 에이전트 실행이라 codex보다 느리고(수십 초~수 분) Google 구독 쿼터를 소비한다. 개별 렌더 로그(`.render_logs/*_render.log`)는 agy의 JSON 출력이 담기지만 시작/종료 래퍼 라인으로 탐색 가능하다. `AGY_ASPECT` env로 화면비 지시를 바꿀 수 있다(기본 세로 2:3).

**스타일 앵커 — 화풍 고정 (antigravity 강력 권장, 실측 효과 있음):** 텍스트 스타일 토큰만으로는 복잡한 장면에서 화풍이 이탈한다(실측: 텍스트 전용은 사실적 렌더링으로 드리프트 + 지시 없는 한국어 대사 자체 생성). 해법은 앵커 레퍼런스 이미지 — 확정된 스타일 샘플 패널(`refs/style_anchor.png`)을 `STYLE_ANCHOR` env에 **절대경로**로 넘기면, 배치 스크립트가 매 패널 생성 전에 에이전트가 앵커를 보고 동일 화풍으로 그리도록 지시를 자동 주입한다.

```bash
STYLE_ANCHOR="$PWD/_workspace/04_visual/refs/style_anchor.png" \
  scripts/render_batch.sh --from-file _workspace/04_visual/ep{NN}_manifest.txt _workspace/05_panels/ep{NN}
```

앵커 운영 규약: ① 본 렌더 전에 스타일 샘플 패널 1장을 먼저 렌더·검증해 확정한다(캐릭터 refs와 함께 SSOT). ② 절대경로 필수 — 상대경로면 에이전트가 파일시스템을 뒤지다 agy의 5분 print 타임아웃에 걸린다. ③ 앵커 파일이 없으면 경고 후 앵커 없이 렌더하므로, 없음이 확인되면 스킵하지 말고 앵커부터 만든다.

**codex 백엔드일 때:**

```bash
codex --version                                # 0.128+ 권장
codex login status                             # "Logged in using ChatGPT" 확인
codex features list | grep image_generation    # stable/true 확인
```

미로그인이면 사용자에게 `codex login` 실행을 요청한다.

**주의 — `codex login status`의 한계**: 이 명령은 로컬 토큰 존재만 확인한다. 서버 측에서 토큰이 폐기됐으면(`token_revoked`) "Logged in"으로 나와도 첫 렌더에서 401로 실패한다(실측). 로그에 `401 Unauthorized ... auth error code: token_revoked`가 보이면 사용자에게 `codex login` 재인증을 요청한다.

**zai 백엔드일 때:** `ZAI_API_KEY` 설정 여부만 확인한다(`[ -n "$ZAI_API_KEY" ]`). 없으면 사용자에게 [Z.ai API 키](https://z.ai/model-api) 발급·`export ZAI_API_KEY=...` 설정을 요청한다. 기본값: 모델 `glm-image`, 크기 `1056x1568`. 요청당 과금이므로 50패널 = 50요청이다.

렌더 도중 멈추지 않도록 시작 전에 확인한다.

**참고 — ZCode 구독 한계**: ZCode 구독(GLM 코딩 플랜)은 코딩·텍스트 모델만 포함하고 이미지 생성을 포함하지 않는다. 구독 토큰으로 이미지 API를 호출하면 401이 반환된다(실측). 따라서 위 둘 중 하나의 인증은 반드시 필요하다.

## 0단계 — 캐릭터 레퍼런스 시트 먼저 렌더 (ref-sheet-artist)

패널보다 먼저, 주요 캐릭터의 **다각도/표정 레퍼런스 시트**를 렌더해 시리즈 외형 기준을 확정한다. 이것이 모든 패널 일관성과 검증의 닻이다.

- 입력: `_workspace/04_visual/character-sheets.md`(불변 토큰), `style-bible.md`(작화 스타일).
- 캐릭터마다 2장 권장:
  - `refs/{IDTAG}_turnaround.png` — 정면/3-4/측면/후면 **전신**, 중립 단색 배경, 균일 조명, 무표정.
  - `refs/{IDTAG}_expressions.png` — 핵심 표정 3~4종 클로즈업.
- 레퍼런스 프롬프트 규약:
  - 글로벌 작화 스타일 토큰 + 캐릭터 불변 토큰 + "character reference sheet, multiple angles (front, 3/4, side, back), full body, neutral grey background, even flat lighting, model sheet".
  - **식별 표식(점/흉터/팔찌 등)을 또렷이**, 좌/우 위치 고정.
  - 레퍼런스만은 **텍스트 없이**: `no text, no labels, no speech bubbles, no watermark`(깨끗한 외형 도감이어야 기준이 된다 — 패널의 in-image 말풍선과 반대).
- 저장: `_workspace/04_visual/refs/`(회차 폴더가 아니라 **시리즈 자산**, 다음 회차 재사용). `refs/INDEX.md`에 캐릭터별 경로+핵심 외형 한 줄+확정 여부 기록.
- 렌더 후 0바이트/손상/md5 중복 확인, 각도 간 동일인 여부 육안 점검. 흔들리면 재렌더(최대 3회). 확정 시 prompt-smith·panel-validator에 INDEX.md 인계.
- **후속 회차**: refs/가 이미 있으면 재렌더하지 않고 재사용한다(시리즈 일관성). 신규 캐릭터만 추가 렌더.

## 입력 — 패널 프롬프트 목록

`_workspace/04_visual/ep{NN}_prompts.md`를 Read한다. 각 패널은 다음 형식이다:

```
### panel_001
- scene_group: A
- scene_id: S2 / location: LOC_CLASSROOM
- prompt: "<글로벌 스타일 + 장소 토큰 + 캐릭터 토큰&레퍼런스 앵커 + 구도/상태색 + in-image 말풍선(한글 대사) + negative(no watermark/English/gibberish)>"
- output: _workspace/05_panels/ep{NN}/panel_001.png
```

렌더 전 출력 디렉토리를 만든다: `mkdir -p _workspace/05_panels/ep{NN}`

## 일관성 토큰 검증 (렌더 전 필수)

패널 간 캐릭터 외형·작화 스타일·배경이 흔들리면 웹툰이 무너진다. codex-image는 시드 고정이 어렵기 때문에 **프롬프트 텍스트의 일관성 토큰 + 확정 레퍼런스 앵커**가 일관성 장치다. 그래서 렌더 직전에 각 프롬프트가 다음을 포함하는지 확인한다:

1. **작화 스타일 토큰** — `style-bible.md`의 고정 스타일 키워드.
2. **등장 캐릭터의 외형 토큰 + 레퍼런스 앵커** — `character-sheets.md`의 고정 키워드 세트 + `refs/{IDTAG}_*.png` 확정 레퍼런스를 외형 기준으로 명시(식별 표식 좌/우 포함).
3. **씬 장소 고정 토큰(LOC_*)** — 같은 scene_id의 모든 패널에 동일한 장소 배경 토큰. 배경 급변 방지의 핵심.
4. **화면비/구도/상태색 지시** — 샷리스트의 앵글·구도·장면 색(평상/되감기/정산 등).
5. **in-image 말풍선/한글 대사** — lettering.md의 말풍선(종류·정확한 한글 원문·위치). 무대사 패널은 제외.

부정 프롬프트는 `no text`가 아니라 `no watermark, no English text, no gibberish/garbled/misspelled text`다(말풍선·한글은 그려야 하므로). 누락·모호하면 prompt-smith에 보강을 요청한다. 일관성 토큰·레퍼런스·장소 토큰 없는 패널은 렌더하지 않는다 — 다시 그리는 비용이 더 크다.

## 핵심 — 동시 5장 배치 렌더링

**렌더 백엔드 동시 세션은 5개를 절대 넘기지 않는다.** codex는 ChatGPT 플랜의 동시 요청 한도 때문에 6개+는 큐잉으로 응답이 들쭉날쭉해지고, zai도 API 속도 제한이 있다. panel-artist가 3명이어도 **세 아티스트의 렌더 동시 실행 총합이 5 이하**가 되도록 오케스트레이터가 렌더 패스를 순차 디스패치한다. 번들 스크립트가 한도를 강제하므로(`CONCURRENCY>5` 거부), 항상 스크립트 경유로 렌더한다.

### 방법 A (권장) — 번들 배치 스크립트 (디스패처 경유)

`render_batch.sh` 디스패처가 백엔드를 골라 임의 개수를 5장씩 자동 배치하고, 각 항목 타임아웃 감시와 완료 후 무결성 검사(0바이트/손상/md5 중복)까지 수행한다. **프로젝트 루트(`_workspace/`가 있는 디렉토리)에서 실행**한다. 한 회차 전체(또는 한 scene 그룹)를 한 번에 넘긴다:

```bash
.zcode/skills/webtoon-panel-render/scripts/render_batch.sh \
  _workspace/05_panels/ep{NN} \
  "<panel_001 프롬프트>::panel_001.png" \
  "<panel_002 프롬프트>::panel_002.png" \
  ... (임의 개수, 내부에서 5개씩 동시 실행)
```

- 한 배치(5장)가 끝나면 다음 배치를 시작하므로 동시 세션이 5를 넘지 않는다. `CONCURRENCY=6` 이상은 거부한다.
- 출력 PNG는 모두 `_workspace/05_panels/ep{NN}/`에 저장되고, 렌더 로그는 `_workspace/05_panels/ep{NN}/.render_logs/`에 남는다.
- 프롬프트가 길면 셸 따옴표 이스케이프가 위험하니 **매니페스트 파일 모드**를 쓴다(한 줄 = `프롬프트::파일명`, `#` 주석 가능):

```bash
.zcode/skills/webtoon-panel-render/scripts/render_batch.sh \
  --from-file _workspace/04_visual/ep{NN}_manifest.txt \
  _workspace/05_panels/ep{NN}
```

- 종료 코드: `0` = 전 항목 유효·중복 없음, `1` = 문제 있음(요약의 [FAIL]/[DUP] 패널만 재렌더한다 — 배치 전체 재실행 금지).
- 스크립트가 무결성까지 검사하므로 방법 A 사용 시 아래 "렌더 후 검증"의 수동 명령은 최종 확인용으로만 필요하다.

### 방법 B — 수동 5장 병렬 (세밀 제어가 필요할 때)

한 메시지에서 **정확히 5개**의 Bash 도구를 `run_in_background: true`로 동시에 띄운다. 출력 파일명이 모두 달라야 한다(같은 경로면 마지막만 남는다):

```bash
codex exec --sandbox workspace-write --skip-git-repo-check \
  --cd <프로젝트 루트 절대경로> \
  -o /tmp/codex-ep{NN}-001.md \
  "이미지 생성 도구로 '<panel_001 프롬프트>' 이미지를 생성하고 ./_workspace/05_panels/ep{NN}/panel_001.png 로 저장. 파일 경로만 한 줄로 보고."
# 같은 패턴으로 panel_002~panel_005를 각각 run_in_background:true 로 동시에. 총 5개.
```

- 5장 완료 통지를 받은 뒤 다음 5장을 띄운다. **`sleep` 폴링 금지** — 백그라운드 완료 통지가 자동으로 온다.
- `--ask-for-approval`을 붙이지 않는다(비대화형이라 즉시 에러 종료).
- git 리포가 아니면 `--skip-git-repo-check`를 빠뜨리지 않는다.
- 이 방법은 무결성 검사가 없으므로 완료 후 아래 "렌더 후 검증"을 반드시 직접 실행한다.

### 분량·소요 시간 기대치

| 패널 수 | 배치(5장) 수 | 예상 렌더 시간 |
|--------|------------|--------------|
| 50장 | 10 웨이브 | 약 26~28분 (웨이브당 ~160초) |
| 60장 | 12 웨이브 | 약 32분 |

실측 기준 5장 동시 wall-clock ~158초. 사용자에게 렌더가 수십 분 걸림을 미리 알린다.

## 렌더 원장과 무손실 재개 (v11)

모든 배치 실행은 `{OUT_DIR}/.render_logs/_ledger.tsv` **누적 원장**에 기록된다(실행마다 초기화되지 않는다 — 회차 전체의 유일한 렌더 상태 저장소).

- **열**: `ts / backend / backend_version / filename / attempt / prompt_hash / md5 / status / reason`. 배치마다 `# META` 행(백엔드·CLI/모델 버전·동시성·매니페스트·resume 여부)이 먼저 찍힌다 — **백엔드·모델 버전이 바뀌면 결함률 비교의 기준점**이 된다(버전이 다른 두 시행의 결함률을 동일 조건으로 비교하지 말 것).
- **시도 로그**: `.render_logs/{stem}_try{N}.log` — 재시도 배치가 이전 시도의 로그를 덮어쓰지 않는다(v10 실측 문제 해소).
- **시도 상한 경고**: 같은 파일의 3회차 시도부터 스크립트가 경고한다 — "패널당 재렌더 3회 상한"(제작 규칙 §7)의 스크립트 레벨 강제. 원장 `attempt` 열로 확인.
- **기계판독 요약**: `_batch_summary.tsv`(filename/status/reason/md5/attempt).
- **상태 머신 대응**: 원장 한 행이 한 시도의 `SUBMITTED → GENERATED → ARTIFACT_VERIFIED` 구간을 담당한다(status=OK는 아티팩트 검증까지 통과). 이후 `VALIDATED`(8축)→`APPROVED`(MD5 핀)→`PACKAGED/RELEASED` 는 validation.md·APPROVED-MD5 핀·RELEASE 원장이 담당한다 — "화면에 결과가 보였다"와 "승인 가능한 파일이 저장됐다"는 다른 상태다.

**무손실 재개 — `--resume`**: 사용량 한도·세션 끊김으로 배치가 중단됐을 때 같은 매니페스트를 `--resume`으로 재실행하면, 원장에서 (filename, prompt_hash)의 최근 status가 OK인 패널은 재렌더하지 않고 승계한다(`[SKIP]` 표시). 프롬프트가 바뀐 패널은 해시가 달라 자동으로 재렌더 대상이 된다.

```bash
.zcode/skills/webtoon-panel-render/scripts/render_batch.sh \
  --resume --from-file _workspace/04_visual/ep{NN}_manifest.txt \
  _workspace/05_panels/ep{NN}
```

주의: resume 스킵은 파일 무결성까지만 승계한다(파일이 삭제됐으면 FAIL로 잡힌다). 내용 품질(8축·V-게이트) 판정에는 영향 없다.

## 렌더 후 검증 (필수)

생성 직후 항상 파일을 확인한다. **1차는 자동 검사 스크립트** `scripts/lib/panel_check.py`(형식·크기·매트 BL-07 전수, PIL 의존만)로 돌린다 — 디렉토리 모드는 정렬된 PNG 전수 검사 후 요약표를 출력한다. 크기 기대값이 848×1264가 아니면 `PANEL_CHECK_SIZE=WxH`로 지정한다(zai 기본 1056x1568 등). codex 세션이 도구 호출에 실패하면 0바이트 PNG가 나올 수 있다.

```bash
python3 .zcode/skills/webtoon-panel-render/scripts/lib/panel_check.py _workspace/05_panels/ep{NN}
```

이어서 최종 확인용 수동 명령:

```bash
ls -la _workspace/05_panels/ep{NN}/*.png
file _workspace/05_panels/ep{NN}/*.png       # 모두 "PNG image data" 인지
find _workspace/05_panels/ep{NN} -name '*.png' -size 0    # 0바이트 목록
# md5 중복 검사 (서로 다른 패널이 동일 이미지로 저장되는 사고 — EP01에서 실제 발생)
md5 -r _workspace/05_panels/ep{NN}/panel_*.png | awk '{print $1}' | sort | uniq -d   # 비면 중복 없음
```

검증 결과 처리:
- **0바이트/손상 PNG** → 그 패널만 다시 렌더한다(배치 전체 재실행 금지).
- **md5 중복 PNG** → 중복된 패널을 삭제하고 그 패널만 단독 재렌더한다(동시 배치에서 드물게 한 패널이 다른 패널 이미지를 받는다). 0바이트도 손상도 아니어서 크기/헤더 검사만으로는 못 잡으니 md5 검사를 반드시 한다.
- **파일이 `~/.codex/generated_images/`에만 있고 작업 폴더에 없음** → 프롬프트의 "./경로로 저장" 지시를 강화해 재시도.
- **누락된 패널 번호** → prompts 목록과 실제 PNG 목록을 대조해 빠진 번호만 렌더한다.
- 모든 패널이 존재·유효·고유하면 1차 무결성 통과. 이어서 아래 **검증-재생성 루프**(panel-validator)로 내용 품질을 거른 뒤 quality-reviewer에게 넘긴다.

## 사후 검증 4계층 (v11 — V-게이트 계층화)

렌더 완료 후 품질 판정은 4개 계층으로 나뉜다. **어떤 계층도 생략 불가** — 하위 계층 통과가 상위 계층을 대신하지 못한다. 자동 검사는 메인의 시각 판정을 "대체"하는 게 아니라 메인이 중요한 판단에 집중하도록 "돕는" 방향으로만 쓴다.

| 계층 | 수행자 | 검사 | 산출 |
|-----|--------|------|------|
| ① 자동 | 스크립트 | `panel_check.py`(형식·크기·매트 BL-07) + 배치 내장 검사(0바이트·손상·md5 중복) | 원장 status |
| ② 서브에이전트 | panel-validator | 8축(C1~C8) 패널별 결함 스캔 + [PIL]/[RE-RENDER] 수리 라우팅 | validation.md 판정표 |
| ③ 메인 | V-게이트 | 컨택트시트(2×2, 4컷 그리드) **전수 시각 열람** — 배경 일관성(플레이트 대비)·역할 확인(복장 식별)·상호작용(손-물건-사람)·화면 좌표 일관성 | validation.md V-게이트 섹션 |
| ④ 불확실 큐 | 메인 | ②③에서 UNCERTAIN 또는 검토자 간 불일치 패널만 재판정(원본 확대 열람) — 무시각 서브에이전트의 OCR/SSIM 오판은 여기서 메인이 뒤집는다 | 최종 판정 |

**판정 스키마 (v11) — VISUAL_PASS / STORY_PASS 2필드 분리**: 패널당 판정은 한 줄이 아니라 두 필드다.
- `VISUAL_PASS` — 캐릭터·배경·텍스트·스타일·기술 무결성 등 눈에 보이는 품질(8축 판정).
- `STORY_PASS` — 이 패널이 서사를 전달하는가: 직전 컷과의 인과 연결(K-1), 무대사 독자 테스트(K-3), 말풍선 읽기 순서, 액션의 원인-결과 가시성.
- 시각적으로 완벽해도 스토리 전달에 실패하면 REGEN/FLAG 대상이고, 그 반대도 성립한다. 둘 중 어느 쪽도 서면으로 못 서면 `UNCERTAIN` — 4계층 큐로 보낸다(자가 확정 금지).

## 검증-재생성 루프 (panel-validator) — 기준 만족까지 재렌더

무결성(위)만으로는 부족하다. codex는 같은 프롬프트에도 엉뚱한 배경·다른 얼굴·깨진 한글을 낸다. 그래서 렌더 직후 **패널 단위로** 8축을 검사하고 미달분을 되돌려 재렌더한다(생성-검증 패턴 — 4계층의 ②계층). 통과 패널만 조립으로 간다.

**8축 검사** (각 패널을 Read로 열어 육안 + 스크립트; 상세 결함 목록은 `references/defect-checklist.md` A1~F3·수리 라우팅 태그 [PIL]/[RE-RENDER] 전수 스캔, 결함 클래스 상시 차단절 원장은 `references/blocklist-clauses.md · style-catalog.md(그림체 6종 지정)`):
1. **C1 캐릭터 일관성** — `refs/{IDTAG}_*.png`와 같은 사람인가(헤어/눈/체형/식별 표식·좌우). 의도된 변형(예: 정산 회색화)은 예외.
2. **C2 배경/장소 연속성** — 배경이 그 패널의 scene_id/location(LOC_*)과 일치하는가. 같은 씬인데 장소 급변(도로→실내)하면 REGEN.
3. **C3 말풍선 & 한글 텍스트(최대 리스크)** — 말풍선 종류가 맞고, **한글이 대본과 정확히 일치(오탈자·뭉개짐·영어/가짜 글자 없음)**하며 가독한가. 무대사 패널에 말풍선 있으면 REGEN. **+ (d) 통합 레터링: 말풍선·텍스트가 작화에 녹아든 손그림 잉크 톤인가 — 깨끗한 디지털 폰트를 평평하게 얹은 "오버레이/붙여넣기" 느낌이면 텍스트가 맞아도 REGEN**(후작업 텍스트로 오해됨). 판별 신호(OVERLAY=REGEN): 기계적으로 균일한 획·완벽 균등 자간·시스템 고딕 룩·과하게 매끈한 가장자리·그림과 분리된 검정 톤. **철자와 분리해 별도 판별하며, 텍스트 보유 패널 100% 전수 + 1차 통과 후 교차 비교 스윕**(한 패널만 디지털 폰트로 튀는지). 패널별 INTEGRATED/OVERLAY를 validation.md 레터링 원장에 기록 — 집계 도장(C3 강함 ✓)만으로 통과 금지. 상세 절차는 `panel-validator` 정의의 "C3(d) 통합 레터링" 섹션.
4. **C4 프롬프트 충실도** — 샷 사이즈/앵글/구도/감정/상태색이 의도대로인가.
5. **C5 대사 흐름** — 앞뒤 패널과 이어 읽어 대화가 자연스러운가.
6. **C6 기술 무결성** — 0바이트/손상/md5 중복 아님, 경로·번호 정확.
7. **C7 스타일 앵커 일치**(앵커 있을 때) — 선 굵기·채색·셰이딩이 `refs/style_anchor.png`와 같은 화풍인가. 사실화 이탈·질감 과잉은 REGEN. **지시 없는 대사 자체 추가도 여기서 잡는다**(실측 위험).
8. **C8 교차 패널 스토리 장치 비교** — 같은 장치(벨·유리·플립 쌍 등)를 쓴 컷들을 묶어 비교 — 장치 상태·구도가 서사 의도(같음은 반전에서 단 한 번 등)와 일치하는가.

**루프**: 패널마다 ACCEPT / REGEN(사유+수정 지시). REGEN → prompt-smith가 그 패널 프롬프트만 보강(배경 급변→장소 토큰 강화, 한글 깨짐→텍스트 따옴표·굵게·짧게, 외형 이탈→레퍼런스 앵커·표식 강조, 구도 어긋남→앵글 명시) → 담당 panel-artist가 그 패널만 재렌더 → 재검사. **prompt-smith는 매니페스트 작성·보강 시 `references/blocklist-clauses.md`(상시 차단절 원장)의 적용 조건에 해당하는 모든 컷에 표준 긍정 절을 상시 주입한다(누락 시 렌더 전 검증에서 반려)**, panel-validator가 신규 결함 클래스를 발견하면 같은 원장에 차단 절을 즉시 등재한다(등재 후 다음 매니페스트부터 전 컷 자동 주입 + 진행 중 매니페스트 소급 주입). **패널당 최대 3회.** 3회 후에도 미달이면 가장 나은 버전을 **ACCEPT-FLAG**(통과+한계 명시)로 마감하고 `ep{NN}_validation.md`에 기록(무한 루프 방지). C3(한글)이 3회 실패하면 "말풍선 모양 유지 + 가장 정확한 텍스트 버전 채택"으로 마감하고 quality-reviewer에 플래그.

출력: `_workspace/04_visual/ep{NN}_validation.md`(패널별 판정 **VISUAL_PASS/STORY_PASS 2필드**·8축 결과·재생성 횟수(원장 attempt와 대조)·플래그·UNCERTAIN 큐 목록).

## 일부만 다시 그리기 (후속 작업)

quality-reviewer가 FIX/REDO로 지정한 패널만 재렌더한다. 전체를 다시 그리지 않는다.

1. qa_report.md에서 REDO 패널 번호와 수정 지시를 읽는다.
2. 해당 패널 프롬프트에 수정 지시를 반영(prompt-smith와 조율)한다.
3. 그 패널들만 5장 이하 배치로 재렌더 → 재검증.
4. 같은 패널을 2회 재렌더 후에도 실패하면 경고와 함께 통과시키고 보고서에 명시한다(무한 루프 방지).

## 안티패턴

- **6장 이상 한 배치** — 큐잉으로 응답 분산↑, 일부 작업 비정상 지연.
- **여러 아티스트가 동시에 각자 5장씩(총 10장+)** — 전역 5 한도 초과. 반드시 순차 디스패치.
- **포그라운드 직렬 실행** — 병렬 효과 상실. 항상 `run_in_background: true`.
- **`sleep`로 완료 대기** — 백그라운드 통지가 자동. 폴링 금지.
- **동일 출력 경로 N개 동시 사용** — 마지막만 남음. 파일명 전부 달라야 함.
- **md5 중복 미검사** — 동시 배치에서 한 패널이 다른 패널 이미지를 받는 사고를 놓친다(EP01 실제 발생). 크기/헤더만 보지 말 것.
- **레퍼런스/장소 토큰 누락 렌더** — 외형·배경이 흔들려 재작업 비용 폭증. 레퍼런스 시트 확정 전, 장소 토큰 주입 전에 패널을 렌더하지 않는다.
- **`no text`로 말풍선 억제** — 이 하네스는 말풍선을 in-image 베이크한다. `no text`를 넣으면 대사가 안 그려진다. 부정은 `no English/gibberish/misspelled text`만.
- **검증 없이 조립으로 직행** — panel-validator 8축 통과 전 패널은 조립에 넘기지 않는다.
- **C3 집계 도장** — 패널별 레터링 개별 판정 없이 "C3 강함 ✓"로 일괄 통과. EP01에서 이렇게 13장의 오버레이-룩이 새어 나갔다. 텍스트 보유 패널은 전수로 INTEGRATED/OVERLAY를 원장에 남긴다.
- **레터링 교차 비교 생략** — 패널을 따로따로만 보면 "한 패널만 디지털 폰트로 튀는" 드리프트를 못 잡는다. 1차 통과 후 텍스트 패널을 모아 나란히 비교한다.

## 비상 수동 폴백 — ChatGPT 웹 (최후 수단)

모든 자동 백엔드(antigravity·codex·zai)가 동시에 막혔을 때만 사용하는 최후 절차다.
사용자가 **chatgpt.com에서 직접** 패널을 생성해 저장하면, 검증과 조립은 자동 경로와
동일하게 진행된다(생성 방법과 무관 — 파일만 있으면 panel-validator 7축 검증 가능).

절차:
1. 해당 패널의 `ep{NN}_prompts.md` 프롬프트를 사용자에게 전달해 복사해 쓰게 한다(스타일 토큰·말풍선 한글 원문 포함).
2. 확정된 `refs/style_anchor.png`를 함께 보여주며 "이 화풍과 동일하게" 지시하도록 안내한다.
3. 생성·다운로드한 이미지를 `_workspace/05_panels/ep{NN}/panel_XXX.png` 경로로 저장하게 한다(파일명·번호 정확히).
4. 저장되면 자동 경로와 동일하게 panel-validator 7축 검증 → 조립으로 진행한다.

주의:
- **브라우저 자동화 금지** — 사람이 직접 웹에서 조작할 때만 허용한다(약관·탐지 문제).
- 화풍 일관성이 자동 경로보다 무너지기 쉬우므로, 수동 패널은 C7(스타일 앵커) 검사를 가장 엄격히 본다.
- zai는 키 잔액만 충전되면 즉시 자동 경로로 복구되는 1차 대안이므로, 수동 폴백은 그마저 막혔을 때 쓴다.

### 자동 경로 복구 확인 (서비스 복구 시 1장 테스트)

자동 백엔드가 복구되면 아래 1장 테스트로 확인 후 정상 경로로 복귀한다 (종료 코드 0 + 유효 PNG가 통과 기준, 실패 사유는 요약·로그에 출력):

```bash
# codex 한도 해제 확인 (매주 리셋 — 실패 시 다음 리셋까지 대기)
WEBTOON_RENDERER=codex bash .zcode/skills/webtoon-panel-render/scripts/render_batch.sh out "simple test circle::v.png"
# zai 충전 확인 (키: export ZAI_API_KEY=... 또는 ~/.zai_api_key)
WEBTOON_RENDERER=zai bash .zcode/skills/webtoon-panel-render/scripts/render_batch.sh out "simple test circle::v.png"
```

복구 이력: 2026-09-15 codex 사용량 한도 도달 → 2026-09-19 20:22 해제 예정. 이 기간 렌더는 antigravity 또는 수동 폴백 사용.

## 비용 주의

- **codex**: 각 호출이 독립 세션 → 토큰·플랜 메시지 한도를 N배 소모한다. 헤비 배치(50장+) 전 `codex login status`로 플랜 잔량을 확인한다.
- **zai**: 이미지 1장당 과금(GLM-Image 기준 약 $0.01~0.03/장). 50패널 = 50요청이므로 시작 전 예상 비용을 사용자에게 알린다.
- 백엔드를 바꾸면 작화 스타일이 미묘하게 달라진다. 한 회차는 처음 시작한 백엔드로 끝까지 렌더한다(중간 전환 금지).

## 출력

- `_workspace/05_panels/ep{NN}/panel_001.png` … `panel_0NN.png` (50+장)
- 렌더 요약(생성/재시도/실패 패널 수)을 최종 보고로 회신한다(오케스트레이터가 episode-compositor에게 중계).

- **그림체 지정(2026-09-19)**: brief `style:` 필드 → 조립 공식 ①번 글로벌 토큰을 `references/style-catalog.md`의 해당 EN 렌더 토큰 블록으로 통째로 치환. 캐릭터 EN·LOC·레터링 블록은 무변경.
