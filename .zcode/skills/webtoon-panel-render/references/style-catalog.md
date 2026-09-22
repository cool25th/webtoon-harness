# Style Catalog — 그림체(아트 스타일) 지정 시스템

> 신설: 2026-09-19 · 사용자 요청 "그림체를 다양하게 지정할 수 있도록 하는 부분"
> 용도: brief의 `style:` 필드로 회차 그림체를 지정한다. 한 회차 한 스타일 고정(중간 전환 금지 — 화풍 흔들림 방지 기존 규칙 승계).

## 운용 규칙

1. **지정 방법**: brief.md 헤더에 `style: <키>` 기재 (예: `style: watercolor-soft`). 미지정 시 `webtoon-clean`.
2. **프롬프트 적용**: prompt-smith는 조립 공식 ①번(글로벌 스타일 토큰)을 아래 카탈로그의 EN 렌더 토큰 블록으로 **통째로 치환**한다. LOC·캐릭터 EN·레터링 블록은 스타일과 무관하게 그대로.
3. **스타일 앵커 전략**: 스타일 교체 시 `refs/style_anchor.png`만 새 스타일로 1장 재렌더(교체 대상 장면은 자유 — 기존 절차 승계). **캐릭터 ref 시트는 재렌더 금지** — 시트는 신원(얼굴·점·이발·복장)의 SSOT이고 스타일 독립이다. 생성기가 시트 화풍을 따라가려는 경향은 `rendered in the selected art style, identity tokens unchanged` 한 문장으로 제어.
4. **식별 앵커 불변**: 점 위치·이발·복장 색 EN 블록은 전 스타일 공통(Tier S).
5. **모션 매핑**: 뷰어 `body data-style`에 같은 키를 주면 스타일별 모션이 자동 적용(모션 SSOT는 viewer-template.html의 `MOTION_KEYS`).

## 카탈로그 (6종)

### 1. `webtoon-clean` — 클린 웹툰 (디폴트·현행)
- **EN 렌더 토큰**: `modern Korean webtoon illustration, clean uniform thin linework, soft cel shading with gentle airbrushed highlights and glow` (+기존 글로벌 토큰 후속 절 그대로)
- **네거티브 차이**: 기존 표준 그대로
- **톤 적합**: 범용·로맨스·일상·미스터리
- **모션**: 미세 Ken Burns(1.006→1.02·16s 숨쉬듯)

### 2. `watercolor-soft` — 부드러운 수채
- **EN 렌더 토큰**: `soft watercolor webtoon illustration, delicate ink outlines dissolved into gentle watercolor washes, pastel-toned blooming pigments with wet-on-wet bleeding edges, visible cold-press paper texture, airy negative space, muted dreamy palette with soft granulation`
- **추가 네거티브**: `no harsh outlines, no flat cel shading, no digital gradients, no glossy highlights`
- **톤 적합**: 조용한 밤 이야기·감성·힐링 — 밤 편의점 무드와 최적
- **모션**: 드리프트+블러 펄스(번짐 감각)
- **주의**: 대사 베이크는 잉크가 아닌 **붓글씨 톤** 지시(`brush-lettered in soft ink, matching the watercolor style`) — INTEGRATED 판정 기준 동일

### 3. `retro-manga` — 레트로 만화
- **EN 렌더 토큰**: `retro 1990s Japanese manga style webtoon panel, bold confident ink linework with visible pen pressure, halftone screentone shading, strong black-and-white contrast with one muted accent color per scene, dynamic speed lines allowed for motion beats, aged paper tone`
- **추가 네거티브**: `no airbrush, no soft gradients, no pastel washes, no 3D shading`
- **톤 적합**: 액션·추리·타임리프
- **모션**: 슬랫 전환+톤 깜빡임

### 4. `sketch-pencil` — 연필 스케치
- **EN 렌더 토큰**: `rough pencil-sketch webtoon illustration, expressive graphite linework with visible construction strokes, cross-hatched shadows, smudged graphite tones, warm sketchbook paper background showing through, hand-drawn imperfection embraced`
- **추가 네거티브**: `no clean vector lines, no flat color fills, no screentone, no glossy rendering`
- **톤 적합**: 심리 미스터리·불안·내면 서사
- **모션**: 라인 보일(2프레임 지터·살아있는 스케치)
- **주의**: 텍스트 베이크는 연필 필압 톤 — 가독성 위해 굵은 연필 스트로크 지시

### 5. `noir-neon` — 네오누아르
- **EN 렌더 토큰**: `neo-noir webtoon illustration, dramatic chiaroscuro lighting with deep crushed blacks, selective neon accent highlights (cold cyan and warm magenta) rimming the subjects, film grain texture, rain-slick reflective surfaces, high contrast moody atmosphere`
- **추가 네거티브**: `no flat even lighting, no pastel tones, no soft washes, no bright daylight feel`
- **톤 적합**: 밤 장르물·스릴러·도시 미스터리
- **모션**: 네온 글로우 펄스+절제된 플리커

### 6. `pastel-warm` — 파스텔 따뜻
- **EN 렌더 토큰**: `warm pastel webtoon illustration, rounded soft linework, melted pastel color blocking with cotton-soft textures, gentle warm lighting, cozy rounded shapes, storybook tenderness`
- **추가 네거티브**: `no sharp angles, no heavy black shadows, no neon, no harsh contrast`
- **톤 적합**: 로맨스·가족·힐링 개그
- **모션**: 파동 스케일+따뜻한 페이드

## v7 지정 상태

- ep01 v7: **`watercolor-soft`** (사용자 무응답 시 오케스트레이터 추천안 — 시스템 전환 시연·밤 무드 최적)
- 신규 style_anchor: watercolor 톤으로 1장 재렌더 후 기존 경로 교체(구 앵커는 `refs/_backup_v6/` 보존)
