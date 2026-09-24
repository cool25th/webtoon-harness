# Blocklist Clauses — 결함 클래스 상시 차단절 원장

**용도**: 결함 클래스 1회 발견 → 표준 긍정 절 등재 → **다음 매니페스트부터 전 컷 자동 주입**.
결함 차단을 "검증 → 재발견 → 재수리"의 사후 처방 루프에서 "프롬프트 단계 선점"의 사전 예방 루프로
옮기는 파이프라인이다 (2026-09-18, 오케스트레이터 워크플로우 점검 권고 1).

**진단 배경**: ep01 v5에서 계산대 펜꽂이가 019 → 026 → 046으로 3연속 발생(§C-7). 원인은 차단절이
**그 컷의 수리 프롬프트에만** 추가되고, 같은 세션의 이후 매니페스트 전체에 소급·상시 주입되지
않았기 때문이다. 본 원장이 이 주입 누락을 구조적으로 봉쇄한다 — 원장에 등재된 절은 컷 유형만
맞으면 **무조건** 들어간다.

## 운용 규칙 (필수)

1. **prompt-smith 상시 주입 의무** — 매니페스트(또는 프롬프트 목록) 작성 시, 각 컷이 아래 절의
   **적용 조건**에 하나라도 해당하면 그 절을 **표준 문구 그대로**(코드포인트 무변경) 주입한다.
   해당 컷 유형에 적용되는 절이 누락된 매니페스트는 렌더 불가 — 렌더 전 일관성 토큰 검증 단계에서
   원장 대조 후 반려한다.
2. **validator 신규 클래스 등재 의무** — 검증에서 원장에 없는 결함 클래스가 발견·확정되면
   **즉시 이 파일에 항목을 추가**한다. 항목 구성: 결함 코드(BL-xx) + 실측 이력(몇 판·몇 컷) +
   표준 긍정 절(영문 단일 문장) + 적용 조건(해당 장면/컷 유형). "클래스 최초 발견 → 즉시 원장 등재 →
   이후 전 매니페스트 적용"이 표준 절차다. validation.md의 결함 코드 기록(A1~F3·BL-xx)과 연동.
3. **소급 주입** — 같은 세션에서 이미 작성했거나 진행 중인 매니페스트에도 반영한다. 아직 렌더 전인
   컷은 프롬프트에 절을 추가해 매니페스트를 재발행하고, 이미 승인·APPROVED-MD5 핀 등록된 컷은
   동결 대상이므로 건드리지 않는다(재렌더 금지 — 핀 컷 보존이 우선).
4. **긍정형 우선 원칙** — 네거티브(`no pen` 등)는 이행이 불안정하다(ep01 실측: `no pen` 주입 상태에서
   펜꽂이 3연속). 절은 항상 **긍정형으로 상태를 고정**하는 단일 문장으로 쓰고, 네거티브는 보조로만.
5. **문구 변형 통제** — 표준 절을 임의로 바꿔 쓰지 않는다. 축약형·변형이 필요하면 이 원장에
   "변형"으로 등재한 뒤에만 사용한다(아래 각 항목의 "변형(실측 이행형)" 참조).

## 절 원장 (BL-01 ~ BL-09)

### BL-01 계산대 소형 물체 (펜꽂이 클래스)
- **결함 코드**: BL-01 — defect-checklist.md B5 · 수리 라우팅 **[PIL]** 1차 → [RE-RENDER] 편집 1회 실패 시
- **실측 이력**: EP01 1판 3컷 — panel_019·026·046 계산대 펜꽂이/펜형 물체 3연속(§C-7, 전부 계산대 표면)
- **표준 긍정 절(EN, 단일 문장)**: "the checkout counter holds ONLY a barcode register with a completely bare flat surface — no pen cup, no pens, no stationery, no clipboard, no small objects of any kind"
- **변형(실측 이행형)**: "completely bare counter top besides the register, no pen cup, no pens, no stationery, no small objects"(§C-7 권고문구)
- **적용 조건**: 계산대(카운터) 표면이 프레임에 조금이라도 들어오는 모든 컷 — 계산대 ECU·인서트, 문틀 ECU처럼 계산대 모서리가 보이는 컷 포함(LOC_STORE 등 점포 계산대 컷 전체)
- **라우팅 비고**: 국소·평면 결함 — PIL 편집(펜꽂이만 제거·계산대면 복원, 019·046 실측 해소 사례)

### BL-02 벽면 부착물 (벽시계·간판·모니터 클래스)
- **결함 코드**: BL-02 — defect-checklist.md B6 · 수리 라우팅 **[PIL]** 1차
- **실측 이력**: EP01 1판 1컷 — panel_003 우상단 아날로그 벽시계(숫자 다이얼, §11.1 `no clocks` 위반)
- **표준 긍정 절(EN, 단일 문장)**: "the walls are completely bare flat surfaces — no wall clock, no signage, no monitors, no displays, nothing mounted"
- **변형(실측 이행형)**: "bare blank walls, no clock, no display, no digits"
- **적용 조건**: 실내 벽면이 프레임에 들어오는 모든 컷 — 인테리어 전경·중경, ECU/인서트의 배경 벽 포함
- **라우팅 비고**: 평면 결함 — PIL 편집(부착물만 제거·맨벽 복원, 003 실측 해소)

### BL-03 유리 반사 인물형 (유령 반사 클래스)
- **결함 코드**: BL-03 — defect-checklist.md B3 · 수리 라우팅 **[RE-RENDER]** 원칙(반사가 화면 주체일 때) / [PIL] 국소 이물반사
- **실측 이력**: EP01 1판 4컷 — v4 라운드 3컷 연속 유령 반사 + panel_011 반사 2인형(전체·좌우 분할·2배 확대 3회 판독 일관)
- **표준 긍정 절(EN, 단일 문장)**: "the reflection on the glass contains no person, no figure, no silhouette — only faint vertical light streaks"
- **변형(실측 이행형)**: "reflections are vertical light streaks only"(v5 매니페스트 이행형 — 유리 가시 컷 전부 인물형 0 실측)
- **과다 노광 선점 변형**: "any glare on the glass stays as soft abstract vertical light streaks — blown-out highlights never form a person, face, or silhouette"(과노출 하이라이트가 인물형으로 읽히는 사례 선점)
- **적용 조건**: 유리(쇼윈도·자동문·냉장고·아이스크림 동결고 문 등)가 프레임에 들어오는 모든 컷. 반사·노광 모두 세로 빛줄기만 허용
- **라우팅 비고**: 반사가 컷의 주 피사체면 편집이 주체를 흔들어 재렌더(011 사례); 배경 유리의 국소 이물반사는 PIL

### BL-04 명찰·웨어러블 부착물 (명찰 클래스)
- **결함 코드**: BL-04 — defect-checklist.md A8 · 수리 라우팅 **[RE-RENDER]** 레터링 겸발 시 / [PIL] 국소 단독 결함
- **실측 이력**: EP01 1판 1컷 — panel_002 베이지 조끼 왼쪽 가슴 흰색 직사각형 명찰(디지털 폰트 오버레이 레터링 겸발 → 재렌더로 해소)
- **표준 긍정 절(EN, 단일 문장)**: "completely blank vest front — no name tag, no pin, no badge"
- **변형(실측 이행형)**: "plain beige vest with NO name tag, no tag, no badge"(v5 매니페스트 이행형)
- **적용 조건**: 하루(점원 조끼)의 상반신이 가시적인 모든 컷 — 조끼 가슴팍이 보이는 각도 전부
- **라우팅 비고**: 명찰만 단독이면 PIL 국소 제거; 레터링 오버레이와 겸발하면 재렌더(002 사례)

### BL-05 시간 오브젝트 (시계·디지털 표시·숫자 클래스)
- **결함 코드**: BL-05 — defect-checklist.md B7 · 수리 라우팅 **[PIL]** 단일 국소 / [RE-RENDER] 복수·주체화 시
- **실측 이력**: EP01 1판 1컷 — panel_003 벽시계(§11.4 시간 오브젝트 금지 위반, "하늘이 유일한 시계" 원칙). 최종 스캔 벽시계·시계·숫자 0건으로 유지 확정
- **표준 긍정 절(EN, 단일 문장)**: "no clocks, no digital displays, no digits anywhere — the sky is the only clock"
- **적용 조건**: **전 컷** — 세계관 원칙(시간 표시 수단 전면 금지). 승인 스캔 시 "벽시계·시계·숫자 0건" 전수 확인이 기준
- **라우팅 비고**: 단일 국소 시계는 PIL(003); 복수 오브젝트·화면 주체화·원근 결합이면 재렌더

### BL-06 폐기 토큰 긍정 부재 (노트·볼펜·클립보드·반창고 클래스)
- **결함 코드**: BL-06 — defect-checklist.md B8 · 수리 라우팅 **[PIL]** 국소 제거 / [RE-RENDER] 파지 구도 오염 시
- **실측 이력**: EP01 1판 — 펜 계열 2컷(019·026, BL-01과 동일 근원), 클립보드 0건 유지, 반창고는 전반부 구형 캐릭터 정의 혼입 사례(E1b — 후반부 무반창고로 정준 확정)
- **표준 긍정 절(EN, 단일 문장)**: "her hands stay completely empty and her skin stays bare — no notebook, no pen, no clipboard, no band-aid anywhere on the face or hands" (손님 등장 컷은 주어만 교체: "the customer's hands stay completely empty …")
- **적용 조건**: 손·얼굴이 가시적인 모든 컷 + 손님(제3인물) 등장 컷 전체 — 빈 손 원칙 이행 컷
- **라우팅 비고**: 빈 손 상태로 보존 가능하면 PIL; 파지 포즈 자체가 오염되면 재렌더

### BL-07 단일 프레임·분할 금지
- **결함 코드**: BL-07 — defect-checklist.md D3 · 수리 라우팅 **[RE-RENDER]** (프레임 구조는 국소 편집 불가)
- **실측 이력**: 연구 기반 예방 클래스 — EP01 v5 실측 결함 0(전 컷 표준 주입 유지). **EP01 v6 그룹 A 첫 실측 발생: panel_015 백색 매트 이중 테두리(2026-09-19 검증 — 작화가 756×1189로 축소·상하 좌우 순백 매트 36~45px + 작화 내측 흑색 테두리선, 단일 프레임 Tier S 위반 → REGEN)**. **EP01 v7 그룹 A 6컷 재발(2026-09-19 panel-validator 라운드1 — 평탄밴드 std<4 포렌식·앵커/핀/그룹D 6자산 0px 대조): panel_005(46/41/44/44px)·006(47/53/51/51)·008(26/37/2/27 — 3면)·011(40/33/34/34)·014(37/36/35/34)·015(상단 49px만) 순백 매트, 5컷 내측 흑색 테두리선 동반 — 전건 REGEN. 13컷은 매트 0px 유지. 프롬프트 차단절(종래 문구)이 매트 방지에 불충분 → 신규 변형 등재(아래)**. **EP01 v8 그룹 C 1컷 발생(2026-09-20 panel-validator 최종 통합 라운드): panel_048 상단 41px 순백 매트(rows 0-41 mean 254.9·std 0.4·RGB 255,255,255 — 내측 흑선 없음·단일 면) → REGEN(변형2 풀블리드 문구 재주입 지시 — ep01_validation.md §CD-9). 같은 배치 그룹 C·D 17컷 중 1컷만 발생(나머지 0px) — C46 핀 앵커+NOT-a-repeat 최강 주입 컷에서 발화**
- **표준 긍정 절(EN, 단일 문장)**: "one single vertical webtoon panel frame — no split panels, no internal borders dividing the frame"
- **변형(실측 이행형)**: 헤더 "single frame, vertical webtoon panel" + 네거티브 보조 "single frame, one panel only, no split panels"(v5 매니페스트 공통)
- **변형2(v7 신규 — 풀블리드 무매트, 2026-09-19 등재)**: "artwork fills the ENTIRE 848x1264 canvas edge-to-edge — no white border, no matte, no margin, no inner frame line"(v7 그룹 A 6컷 재발 방지 — BL-07 위반 이력 컷·재발 컷에 표준 절과 병용 주입)
- **적용 조건**: 전 컷 — 세로 스크롤 단일 패널 매니페스트 공통 절. **변형2는 BL-07 매트 발생 이력 컷의 재발주·동일 아티스트 세션 후속 컷에 추가 주입**
- **라우팅 비고**: 무조건 재렌더

### BL-08 SFX 폭 (효과음 사이즈 클래스)
- **결함 코드**: BL-08 — defect-checklist.md C4 · 수리 라우팅 **[PIL]** 축소 재배치 1차 → [RE-RENDER] 편집 실패 시
- **실측 이력**: EP01 1판 1컷 — panel_050 SFX 「딩글—」 폭 29.0~34.1%W(스펙 18~22%W 초과, §C2-4) → PIL 축소 재배치 편집으로 19.5~20.8%W 해소(§C2R2-2, diff 국소 2.193% 증명)
- **표준 긍정 절(EN, 단일 문장)**: "the onomatopoeia spans about one fifth of the panel width" (목표 18~22%W)
- **변형(실측 이행형)**: "sized about 18-22% of the panel width"(중형 · 050 재수리 문구)
- **적용 조건**: SFX(효과음)를 보유한 모든 컷 — R4 크기 변주 체계에 따라 목표 백분율 조정: 소형 12~15%/10~12%(약 1/8~1/10), 중형 18~22%(약 1/5). 소형 컷은 목표치를 문구에 명시("about one eighth of the panel width" 등)하고 원장에 변형 등재 후 사용
- **라우팅 비고**: "나머지 100% 동일 유지 + SFX만 축소 재배치" PIL 편집이 1차(050 실측), 편집 실패 시 스펙 문구 강조 재렌더

### BL-09 동일 장소 배경 템플릿 수렴 (구도 패밀리 클래스)
- **결함 코드**: BL-09 — defect-checklist.md E3·E1a 인접 · 수리 라우팅 **[RE-RENDER]**(진성 근접중복 동반 시 — 그룹 A [10,19] 선례) / 단독이면 측정 FLAG + 조립 리듬 관찰
- **실측 이력**: EP01 v7 그룹 B 라운드1 (2026-09-19 panel-validator) — 같은 LOC_STORE 컷들의 렌더가 카메라 토큰과 무관하게 동일 3밴드 배경 템플릿(밝은 천장/어두운 중간띠/바닥)을 반복 출현: ASCII 밀도맵 상단 9행이 panel_010·017·019·021·022·025·049에서 거의 문자 단위 동일. 파생 지표 — phash ≤64(보정 25%) 쌍 85건·zcorr 75~90 밴드 다발([22,49] 89.29·[17,25] 88.73·[22,10] 85.51·[21,22] 85.24·[27,49] 84.84·[26,29] 83.03 등). 재렌더로 지표가 거의 불응(022 4회 시도 90.4→89.29 — 매장 템플릿이 원인이라 주체를 바꿔도 유사도 잔류). 플립 고유성(C46↔C49 유일 반복 장치) 희석: C10 93.3·C19 92.5·C22 89.29·C27 84.8·C21 82.9가 C49 패밀리에 근접(R-a 정신 위협). **그룹 B 판정: 단독 위반 아님(변별 지표 — 픽셀 diff 14~44%·에지 IoU 21~54% — 으로 진성 중복[2.78%/74.6%]과 구분, 전컷 수용+FLAG)**. 그러나 회차 누적 반복 피로·플립 희석 리스크로 클래스 등재
- **실측 이력 갱신(v8)**: EP01 v8 그룹 A 라운드1 (2026-09-20 panel-validator) — **진성 근접중복 2건 발생**: [1,3] zcorr 91.86·phash 4/255·에지IoU 76.2%(003이 001의 와이드 확립 구도 재생산 + SFX만 부가), [17,18] zcorr 84.32·pixdiff 6.81%·에지IoU 76.4%(018이 017 회랑 와이드 재생산, 피겨 bbox 3px 차) — 전건 C4 샷타입 미충족 겸발 REGEN. **근본 원인: 지정된 '근접 승인본 앵커 + NOT-a-repeat' 조합이 동일 계열 WIDE/MED 연속 컷에서 프레이밍 복제를 방지하지 못함** — 방지 변형(아래 v8 변형) 등재
- **실측 이력 갱신(v8 그룹 B)**: EP01 v8 그룹 B 라운드1 (2026-09-20 panel-validator) — **진성 2건 재발**: [21,22] zcorr 0.95·phash 2/63·pixdiff 3.72%·에지IoU 79.2%·국소 z맵 16/18셀 99·**피겨 bbox 1px 차**(022가 021 사선 와이드 재생산 — SL-HIGH·SIDE 통로 풀샷 미충족), [26,28] zcorr 0.94·pixdiff 4.75%·에지IoU 81.0%·**얼굴 bbox 2px 차**(028이 026 측면 CU 동일축 재생산 — 반대축 미충족) — 전건 REGEN. **근본 원인: 그룹 B 매니페스트(00:54 발행)가 그룹 A 검증 완료(01:15) 이전 작성으로 변형2(앵커 격리)가 소급 주입되지 않음** — 022 앵커=직전 021(동일 계열 WIDE)·028 앵커=2컷 앞 026(동일 계열 하루 CU, "different shot family" 표기 오류). 교훈: **변형2 등재 시점 이후 발행 예정 매니페스트 전부에 원장 대조 소급 점검이 의무**(운용 규칙 3의 이행 누락이 실측 재발을 유발)
- **표준 긍정 절(EN, 단일 문장)**: "the background is recomposed from this panel's own camera axis — the counter edge, shelf lines and door position shift with the viewpoint so the fixture layout never repeats a previous panel's framing"
- **변형(실측 이행형)**: (유리/문 축 컷용) "the glass door sits at a NEW frame position and scale in this panel — never centered the same way twice"
- **변형2(v8 신규 — 동일 계열 연속 컷 앵커 격리, 2026-09-20 등재)**: 직전/근접 승인본 앵커가 같은 계열(동일 LOC의 WIDE/MED)이면 **앵커에서 해당 승인본을 제외**하고 "completely different camera axis from panel_XXX: NOT the [직전 컷 구도 요약] view, NOT a repeat of any prior framing"의 **구체 축 부정형**으로 교체 — [1,3]·[17,18] 실측에서 '앵커 + NOT-a-repeat 일반 문구' 병용이 프레이밍 복제를 막지 못했음(앵커 이미지가 우세 지시로 작동)
- 변형3(2026-09-23 등재 — 3플레이트 제약 시리즈 동일축 동일샷타입 쌍, 그_자리는_비워_둬 ep01 그룹 C 실측 기반): 카메라 포지션이 플레이트 3종으로 제한된 시리즈에서 **같은 플레이트 + 같은 샷타입(M 등) 조합의 2번째 이상 컷**은 표준 절 + 앵커 격리만으로 프레이밍 수렴을 못 막음(실측: [29,33] zcorr 0.897·diff 5.25%·IoU 0.810·인물 x-피크 454px 완전 동일 — 두 컷 모두 recomposition guard + plate-only anchor 주입 상태에서 수렴). 이 조합에는 **주체 위치 이동 강제**를 추가한다: "the figure stands at a clearly different frame position and scale than in any previous panel on this plate — shifted horizontally AND in depth, with a different head-height reference line"
- **적용 조건**: 동일 LOC 토큰을 공유하는 연속·근접(≤10컷) WIDE/MED 컷 및 유리/문 축 포함 컷 전부 — 특히 그룹 내 2번째 이상 등장하는 실내 와이드. 기존 `NOT a repeat of any prior framing` 절은 문장형 반복 금지라 템플릿 수렴 방지에 불충분(실측) — 본 절을 좌표형(배치가 시점을 따른다)으로 병용 주입. **변형3은 3플레이트 제약 시리즈의 동일 플레이트+동일 샷타입 2회차 이상 컷에 추가 주입**
- **라우팅 비고**: 렌더 후 zcorr 80+ 잔류쌍은 변별 지표(픽셀 diff·에지 IoU·SSIM)로 진성 중복 여부 재판정 — 진성이면 [RE-RENDER](구도 완전 재지시), 템플릿 기인이면 FLAG+조립 리듬 관찰. 재발주는 지표가 아니라 "구도 완전 재지시" 문구로만 유효(022 실측: 같은 프롬프트 재시도는 지표 불응)

## 변경 이력

- 2026-09-23 교실 시리즈 실측 등재: BL-07·BL-08 이력 갱신(변형2/스펙 문구 주입 상태 발생) + **BL-17 신규(문장부호 완전 베이크)** — 그_자리는_비워_둬 ep01 그룹 B 라운드1 (panel-validator)
- 2026-09-18 최초 수록: BL-01~BL-08 (8클래스, ep01_validation.md 실측 기반 — 오케스트레이터 워크플로우 점검 권고 1 파이프라인화)
- 2026-09-19 BL-07 실측 이력 갱신: ep01 v6 그룹 A panel_015 백색 매트 이중 테두리 — 클래스 첫 실측 발생 (panel-validator, PIL 프레임 포렌식 확정 — 8컷 이상 전폭 균일 밴드 검출로 판정)
- 2026-09-19 BL-07 v7 재발 이력 + 변형2(풀블리드 무매트 문구) 등재: ep01 v7 그룹 A 6컷(005·006·008·011·014·015) 순백 매트 재발 (panel-validator 라운드1 — std<4 평탄밴드·내측 흑선·앵커 0px 대조 판정)
- 2026-09-19 BL-09 최초 수록: 동일 장소 배경 템플릿 수렴 (구도 패밀리 클래스 — ep01 v7 그룹 B 라운드1 실측, panel-validator. ASCII 밀도막 동일성·zcorr 75~90 밴드 다발·재렌더 불응성 근거)
- 2026-09-20 BL-09 v8 진성 2건 이력 + 변형2(동일 계열 연속 컷 앵커 격리·구체 축 부정형) 등재: ep01 v8 그룹 A [1,3]·[17,18] NEARCOPY (panel-validator 라운드1 — 앵커+NOT-a-repeat 일반 문구의 복제 방지 실패 근거)
- 2026-09-20 BL-09 v8 그룹 B 재발 이력 갱신: ep01 v8 그룹 B [21,22]·[26,28] NEARCOPY (panel-validator 라운드1 — 매니페스트 발행 시점이 변형2 등재 이전이라 소급 주입 누락. 그룹 C·D·재발주 매니페스트는 발행 전 원장 대조 의무 명시)
- 2026-09-20 BL-07 v8 그룹 C 이력 등재: ep01 panel_048 상단 41px 순백 매트 (panel-validator 최종 통합 라운드 — 그룹 C·D 17컷 중 유일 발화. §CD-9 변형2 재주입 지시). 동일 라운드 [25,29] zcorr 0.825쌍은 변별 지표(에지IoU 58.4%·피겨 상이)로 진성 기각 — BL-09 템플릿 패밀리 잔류 밴드 기록


## v8 신규 (2026-09-19 — 사용자 v7 피드백 실측 기반)

### BL-10 공간 반전 (좌우 뒤집힘) — 실측: v7 다수 컷
- **표준 긍정 절(실내 전 컷)**: `store coordinate anchor: the automatic glass door on viewer's LEFT, the checkout counter on viewer's RIGHT, the fridge at the back center-right — never mirrored, never reversed`
- 라우팅: [RE-RENDER] · 검증: C8 교차 대조 좌우 반전 = 즉시 REGEN(**Tier S 승격 — FLAG 불가**)

### BL-11 환상 사지·가구 발생 손 — 실측: v7 냉장고 손
- **표준 긍정 절(인물 컷 전부)**: `every hand and arm connects to a visible body or shoulder within the same panel; no hands emerging from furniture, fridges, shelves or from off-frame`
- 라우팅: [RE-RENDER] (얼굴 근접 시 국소 PIL 허용)

### BL-12 SFX 기호 오남용 — 실측: v7 정상 입장 컷 딩글
- **표준 긍정 절**: 「딩글—」는 이상 벨 이벤트 컷(C3·C12·C50)에만 — `normal customer entries show NO sound effect text of any kind, the door simply slides open`
- 라우팅: [PIL](문자 소거) 또는 [RE-RENDER] · 검증: SFX 존재 컷 = 지정 3컷만


## v8.1 신규 (2026-09-20 — 사용자 전수 피드백: 냉장고 속 사람·세 번째 손)

### BL-13 신체-가구 위치 계약 — 실측: v8 023 (손님 몸이 냉장고 개구부에 융합)
- **표준 긍정 절(가구 접근 컷 전부)**: `the person stands fully OUTSIDE the appliance on the floor, body clearly in front of the fridge/shelf, only ONE arm extended reaching in, feet planted on the floor, the body never overlapping the appliance opening`
- 라우팅: [RE-RENDER] · 검증: V-게이트(전수 시각)

### BL-14 팔·손 총량 계약 — 실측: v8 024 (양손 봉투 파지 + 수령 손 혼재 = 3손 인상)
- **표준 긍정 절(주고받기 컷 전부)**: `exactly two arms and two hands in total: the bag held in ONE hand only, the other hand free to receive the item — no third hand, no receiving while both hands hold the bag`
- 라우팅: [RE-RENDER] · 검증: V-게이트

## V-게이트 (전수 시각 검증 절차 — 2026-09-20 신설, 메인 에이전트 전용)

서브 검증(무시각 포렌식)은 의미적 이상(신체-가구 융합·팔 과형성 등)을 잡을 수 없음 — 메인이 직접 전수 열람:
1. **시점**: 그룹 렌더 완료 후·수리 후·출고 전 (각 1회)
2. **방법**: 52컷을 4컷 컨택트시트 13장(PIL 2x2 반해상도 그리드)으로 열람 → 의심 컷만 원본 확대 재확인
3. **체크리스트**: 신체-가구 위치(BL-13)·팔/손 수(BL-14)·인물 수·좌우 좌표·표정·텍스트·소품 — "그림이 이상하면 무조건 기각"
4. **통과**: 의심 0 또는 기각 컷 수리 후 재열람 → 핀
5. **실증**: v8에서 통계 검증 8시간 미포착 결함 2건을 컨택트시트 10분 포착


## v8.2 개정 (2026-09-20 — 사용자 피드백: 좌우 왔다갔다·딩글 근거 부재)

### BL-10 v2 개정 — 매장 기준 → **화면 기준(축선 고정·180도 룰)**
- **구 규칙 폐기**: "매장에서 문이 왼쪽"은 카메라가 뒤돌아보면 화면에서 뒤집힘 — 독자는 매장이 계속 뒤집히는 것으로 느낌(사용자 실측)
- **신 규칙**: `whenever the door, glass storefront or checkout counter is visible in frame, the door and glass ALWAYS appear on the viewer's LEFT side of the frame and the checkout counter ALWAYS on the viewer's RIGHT — the camera NEVER crosses the 180-degree axis line of the store (no reverse-axis compositions, no shots looking from the door area toward the back of the store)` — 카메라 다양성은 앵글(높낮이·거리·기울임)으로만, 방향(축)은 고정
- 라우팅: [RE-RENDER] · 검증: V-게이트 화면 좌표 항목

### BL-15 SFX 원인 가시화 계약 — 실측: 사용자 "소리 안 나는데 딩글"
- **표준 긍정 절(딩글 3컷 전부)**: `the small door-chime bell device is VISIBLY mounted above the sliding door, drawn with sound arcs radiating from it, and the door shown mid-opening (sliding gap with motion streaks) — the sound effect text "딩글—" always co-occurs with this visible cause`
- 원인(벨+열리는 문)·소리(딩글)·반응(하루 반응)이 한 프레임에 공존해야 함 — 근거 없는 텍스트 금지
- 라우팅: [RE-RENDER] · 검증: V-게이트

### V-게이트 체크리스트 개정
기존 항목 + **화면 좌표 일관성(문·유리=화면 좌 / 계산대=화면 우 — 전 컷)** + **SFX 원인 가시성(벨 장치·음선·열리는 문 동반)**

- **BL-11 강화(2026-09-20 v8.3)**: `no hands or arms entering from off-frame — if any hand appears, its arm and shoulder must be visibly connected to the person's body within the same panel` (사용자 실측: 혼자 있는데 갑자기 손)

## 교실 시리즈 변형 (2026-09-22 등재 — 《그 자리는 비워 둬》 신규 시리즈·SDIR 그_자리는_비워_둬)

신규 무대(LOC_CLASSROOM) 적용 변형 — 본 절 등재문구만 해당 시리즈 매니페스트에 주입한다(원 문구와 병행 아님).

### BL-02-CLS 교실 벽면·칠판 (BL-02 교실 변형)
- **표준 긍정 절(EN)**: "the classroom walls are completely bare flat surfaces — no wall clock, no bulletin board, no posters, no framed pictures, no schedules, no displays, nothing mounted; the blackboard is a completely clean empty dark-green surface with no writing, no chalk marks, no numbers, no dates, no diagrams"
- **적용 조건**: 교실 벽면 또는 칠판이 프레임에 조금이라도 들어오는 모든 컷(PLATE_A·B 포함)
- 라우팅: [PIL] 1차(평면 결함)

### BL-01-CLS 책상 표면 (BL-01 교실 변형)
- **표준 긍정 절(EN)**: "every student desktop is a completely bare flat wooden surface — no stationery, no pens, no pencil cases, no books, no notebooks, no papers, no small objects of any kind"
- **적용 조건**: 책상 표면이 가시적인 모든 컷 — 단 스크립트가 명시하는 소품(사각사각 청소 컷 등)이 있으면 해당 소품만 예외로 명시
- 라우팅: [PIL] 1차

### BL-05-CLS 교실 시간 오브젝트 (BL-05 교실 변형)
- **표준 긍정 절(EN)**: "no clocks, no watches, no digital displays, no digits anywhere in the classroom — the sky seen through the windows is the only clock"
- **적용 조건**: 교실 내부 전 컷

### BL-10-CLS 교실 3축 고정 (BL-10 v2 교실 변형 — S-1 플레이트와 결합)
- **PLATE_A 축**: "camera at the front of the classroom looking toward the back: the blackboard and teacher's desk on the viewer's lower LEFT, the back door on the viewer's RIGHT, seat rows in perspective between them; never mirrored, never reversed"
- **PLATE_B 축**: "camera at the back of the classroom looking toward the front: the blackboard at the vanishing point center, the window wall on the viewer's RIGHT, seat backs in the foreground; never mirrored, never reversed"
- **PLATE_C 축**: "camera along the window wall side: the windows and curtains on the viewer's LEFT, the seat-row profile on the viewer's RIGHT, seat 23 in the second row from the window; never mirrored, never reversed"
- **적용 조건**: 교실 내부 전 컷 — 해당 카메라 포지션의 플레이트 절대경로 참조와 세트로 주입
- 라우팅: [RE-RENDER] Tier S (즉시)

### BL-13-CLS 교실 신체-가구 계약 (BL-13 교실 변형)
- **표준 긍정 절(EN)**: "every person sits fully on a chair with their body outside and above the desk — no body parts intersecting or fused with desks or chairs; hands rest on the desktop or lap only"
- **적용 조건**: 착석 인물이 있는 모든 컷(S-23 정좌 컷 포함)
- 라우팅: [RE-RENDER]

### BL-16-CLS 창문 반사·창밖 인물형 (신규 — BL-03 계열 교실 변형)
- **표준 긍정 절(EN)**: "the window glass shows only the sky and faint vertical light streaks — no person, no figure, no silhouette reflected in or standing outside the windows"
- **적용 조건**: 창문이 프레임에 들어오는 모든 컷(단, 반전 이후 컷에서 스크립트가 명시한 창밖 요소만 예외)
- 라우팅: [RE-RENDER] 반사가 주체일 때 / [PIL] 국소

## 교실 시리즈 실측 이력 (2026-09-23 등재 — 《그 자리는 비워 둬》 ep01 그룹 B 라운드1, panel-validator)

- **BL-07 이력 갱신**: panel_013 상단 69px·하단 59px 순백 매트(내측 흑선 없음) — **변형2 풀블리드 문구가 매니페스트에 주입된 상태에서도 발생**. 프롬프트 문구만으로 매트가 완전 예방되지 않음이 이 시리즈에서도 확인 → 렌더 후 panel_check.py MATTE 전수 검사·validator 독립 재측정 게이트 유지 필수.
- **BL-08 이력 갱신**: panel_020 SFX 「사각사각」 잉크 폭 380px=**44.8%W**(연결요소 라벨링·역치 3종 강건) — "spans about one fifth / 18-22% of panel width" 문구 주입 상태에서 약 2.2배 발생. [PIL] 축소 재배치 1차 라우팅. panel_025 「덜컥」 17.7%W는 하한 -0.3pp 경계(FLAG).
- **BL-17 신규 등재 — 문장부호 완전 베이크(말미 마침표 누락 클래스)**
  - **결함 코드**: BL-17 — C3 텍스트 정확 하위 · 수리 라우팅 **[RE-RENDER]**(텍스트 베이크 결함은 편집 불가)
  - **실측 이력**: 그_자리는_비워_둬 ep01 1판 1컷 — panel_015 풍선 2행 「저 자리를, 안 보네」에서 말미 '.' 미베이크(픽셀 근거: 마지막 글리프 x599 종료 후 마침표 위치에 점 블롬 부재 — 풍선 윤곽 호만 존재. 타 13개 풍선의 마침표는 전부 판독 → 인식기 맹점 아닌 실물 누락)
  - **표준 긍정 절(EN, 단일 문장)**: "every quoted dialogue line is baked complete to its final character including the exact trailing punctuation mark — every ellipsis, comma and period of the quoted text appears in the artwork exactly as written, nothing dropped at line ends"
  - **적용 조건**: 대사 컷 전부(특히 2행 분할 풍선 — 행 끝에 오는 '.', '?', '…' 전수)
  - **라우팅 비고**: 검증은 OCR 판독 + 말미부 픽셀 스캔(점 블롬 탐지) 병행 — 본 클래스는 문자 본체는 맞고 부호만 누락되는 경우를 잡는다
- **운용 통지**: 위 3건 발화로 **그룹 C(026~034)·모든 재발주 매니페스트는 발행 전 본 원장 대조 소급 점검 의무**(운용 규칙 3 — BL-07·BL-08은 기주입이므로 게이트 강화, BL-17은 전 대사 컷 신규 주입).

## 교실 시리즈 실측 이력 갱신 (2026-09-23 — 《그 자리는 비워 둬》 ep01 그룹 C 라운드1, panel-validator)

- **BL-09 이력 갱신 + 변형3 등재**: panel_033이 panel_029(PLATE_C M·통로 측면) 프레이밍 재생산 — zcorr 0.897·pixdiff 5.25%·에지IoU 0.810(진성 3역치 전부 충족)·인물 어두운 열 프로파일 피크 x=454px 완전 동일. 두 컷 모두 recomposition guard + plate-only anchor 주입 상태였음 → **3플레이트 제약 시리즈의 동일 플레이트+동일 샷타입 쌍에는 주체 위치 이동 강제(변형3)가 필요** — 위 BL-09 변형3 등재. 재발주는 "구도 완전 재지시"(23번 의자 프레임 내 가독 + 인물 x-위치/스케일 변경)로만 유효.
- **참고(결함 아님 — 플립 쌍 성공 사례 기록)**: 030↔031 플립은 zcorr 0.956·멀리언 6·책상 에지 6 전부 0px 일치·전역 시프트 0·델타 3.08% 단일 인물 블롭(존재 1비트) — "플립 쌍 분리 금지 + 030 앵커 유일 예외" 운용이 의도대로 작동했음을 측정으로 확정. 후속 회차 플립 쌍 설계의 기준값으로 사용 가능.

## 공정 결함 (렌더 외 — 2026-09-23 등재)

### PR-01 비전 모델 환각 좌표로 PIL 수리 금지 (ep01《그 자리는 비워 둬》실측)
- **사고**: panel_020 SFX 폭 수리에서 비전 모델(analyze_image)이 제시한 SFX bbox(좌상단)가 환각이었음 — 실제 SFX는 y910-1087(하단 손 군집 상부). PIL 수리가 원본 유기 콘텐츠를 삭제·합성 인공물(직선 스트로크) 추가. 사후 자체 측정(붙여넣기 영역 스팬)은 자기 확인 루프로 무의미.
- **규칙**: ① **PIL 수리 대상 좌표는 반드시 무시각 포렌식 측정값(validator OCR/라벨링)으로 확정**한다 — 비전 모델이 읽어준 좌표는 수리 발주 근거로 쓸 수 없다. ② PIL 수리 후 검증은 **수리 전 대비 diff 풋프린트가 대상 결함 존에 있는지** 비트레벨 확인 후에만 완료로 인정한다. ③ 반해상도 컨택트시트/크롵 판독의 텍스트 위치 신고도 원해상도 재확인 전에 수리에 쓰지 않는다(006 오판정 교훈과 동일 구조).
- **라우팅 비고**: PIL 1차 실패·대상 좌표 불확실 시 [RE-RENDER]로 즉시 전환(상한 내).

### PR-02 재시도본 매 시도 보존 + BL-08 양방화 (ep01 실측 — 2026-09-23 등재)
- **사고**: panel_020 2회차본(05d15111, 스팬 24.3~25.2%W)이 3회차 렌더 직전 미보존으로 소실 — 최선본 판정 테이블에서 "채택 불가(프로세스 기록)"로 마감. 3회차가 과축소(15.3%W)되며 되돌릴 수 없었음.
- **규칙**: ① **REGEN 재렌더 직전 현재본을 `.render_logs/panel_NNN_attemptK.png`로 복사 보존**한다(매 시도 의무 — "나중에 고르기"가 아니라 "매번 남기기"). ② BL-08 스팬 문구는 양방향으로 쓴다: 표준 긍정 절 개정 — "the sound-effect lettering block spans 18 to 22 percent of the panel width measured edge-to-edge including letter spacing — neither wider nor smaller" (단방 "no wider"가 과축소를 유도한 실측: 44.8 → 33.5 → 24.3 → 15.3%W 진자).
- **비고**: 크기 스펙 프롬프트는 목표 밴드 중앙값보다 약간 높게 제시하는 것이 수렴에 유리(진자 감쇠 없이 2회 내 착지).

## 교실 시리즈 검증 강화 v2 (2026-09-23 등재 — ep01 출고 후 사용자 실측 피드백 5종)

**사용자 피드백 원문 요지**: ①의자 배치가 너무 촘촘하다 ②배치가 사다리꼴이 되었다가 한다(컷 간 불일치) ③사람들 앉아 있는 모습이 이상하다 ④스토리가 왔다 갔다 한다 ⑤대화 씬이 어색하다.
**근본 구조 인식**: ①②의 근원은 **패널이 아니라 S-1 플레이트**다 — 패널은 SCENE_REFS로 플레이트 그리드를 상속받으므로, 그리드 결함은 플레이트 게이트에서 먼저 차단해야 한다(플레이트 우선 게이트, 아래 BL-18/19 참조).

### BL-18 좌석 그리드 기하 계약 (사다리꼴·비틀림 방지) — 실측: 사용자 "사다리 꼴 배치가 되었다가"
- **표준 긍정 절(EN, 단일 문장 — 교실 좌석이 프레임에 조금이라도 보이는 모든 컷 주입)**: "the student desks form a strict rectangular grid of exactly 4 columns by 6 rows — every column runs exactly parallel to the side walls with zero sideways stagger or ladder-like offset between consecutive rows, every row runs exactly perpendicular to the side walls, and all desks are identical in size with uniform spacing"
- **측정 기준(validator 무시각)**: 책상 상판 에지 검출(허프/래칫) → ①열 직선 기울기 상호 편차 **≤3°** ②같은 열 내 인접 책상의 횡방향 오프셋 **≤책상 폭 15%**(초과=사다리꼴) ③플레이트 기준 격자 대비 패널 격자 상관.
- **적용 조건**: 좌석 그리드가 보이는 W/M 컷 전부 + **S-1 플레이트 렌더 시 필수(플레이트 우선 게이트)**.
- **라우팅**: 패널에서 발견 시 [RE-RENDER]·플레이트에서 발견 시 **플레이트 재렌더 후 패널 발주**(패널만 고쳐도 상속으로 재발).

### BL-19 좌석 밀도·통로 계약 (촘촘함 방지) — 실측: 사용자 "의자 배치가 너무 촘촘하고"
- **표준 긍정 절(EN, 단일 문장 — BL-18과 세트로 주입)**: "the seating is generously spaced with clear readable floor gaps on all four sides of every desk, the two inner aisles between the column pairs and the wall-side walking gaps are each clearly open at least sixty percent of a desk width, and no desk or chair touches or overlaps its neighbor"
- **측정 기준**: ①인접 책상 간 바닥 노출 간격 ≥ 책상 폭 25%(전경 기준) ②통로 폭 ≥ 책상 폭 60% ③프레임 하단 1/3에서 좌석·책상 점유 면적 ≤70% ④의자-책상 물림·접촉 0건.
- **적용 조건**: BL-18 동일 + 플레이트. **주의**: 4열×6행=24석 설정은 캐논(23번 자리 좌표)이므로 석수를 줄이지 않고 **간격·통로로 해결**한다.
- **라우팅**: 플레이트 → 플레이트 재렌더 / 패널 → [RE-RENDER].

### BL-20 착석 포즈 계약 — 실측: 사용자 "앉아 있는 모습이 조금 이상하고"
- **표준 긍정 절(EN, 단일 문장 — 착석 인물이 있는 모든 컷 주입)**: "every seated person sits with hips fully on the chair seat, back upright against the backrest, exactly two feet flat on the floor, thighs and shins meeting at a natural right angle, shoulders level clearly above the desk-height line, and body proportions consistent with the desk and chair scale"
- **측정/판정**: ①골반-좌면 접촉(떠 있는 허벅지·무릎 걸침 금지) ②허벅지-정강이 각 90°±25° ③발 2개 접지 ④어깨선 ≥ 책상 상판 ⑤신체:의자 스케일 일치(등받이 폭 ≈ 어깨 폭 ±20%) ⑥BL-13/14(2팔 2손·가구 밖) 승계.
- **판정 주체**: 무시각은 ⑤⑥만 — ①~④는 **V-게이트 시각 판정**(측정 불가축 명시).
- **라우팅**: [RE-RENDER](포즈=구도 클래스 — PIL 불가).

### BL-21 대화 스테이징 계약 — 실측: 사용자 "대화 씬도 어색한 부분이 많아"
- **표준 긍정 절(EN, 단일 문장 — 2인 이상 대화 컷 주입)**: "in every conversation panel the speaker's eyeline points directly at the listener's actual position in the frame, the listener shows a readable reaction (gaze direction or expression) in the same panel or the immediately following panel, and the balloon sits closest to its own speaker with its tail not crossing the other character's face"
- **측정/판정**: ①화자 시선 연장선이 청자 머리 영역 도달(시선축 편차 ≤15°) ②교대 2라운드 이상 대화에서 각 전환 시 반응 동반 ③오프패널 발화 꼬리 방향 = 화자 실위치(기존 lettering 규약 승계) ④같은 대화 블록 내 화자-청자 좌우 위치 뒤바뀜 0(180° 룰 — BL-10 v2 승계).
- **판정 주체**: 콘티 게이트(샷리스트 단계 — 시선·반응 비트 배치 확인) + V-게이트(렌더 후 시각).
- **라우팅**: 콘티 단계 위반 → panel-director 재지시 / 렌더 후 → [RE-RENDER].

### N-축 서사 진행 단조성 (콘티·대본 게이트 — 렌더 외) — 실측: 사용자 "스토리도 왔다 갔다 하고 있어"
- **정의**: 회차를 신 상태 테이블(장소·시간·등장인·각자 아는 것)로 쪼개고 **컷마다 상태 변화를 강제**한다.
- **규칙 4조**:
  1. **정보 되감기 금지**: 이미 확정된 사실을 미지처럼 재질문·재탐색하는 컷 0건 허용.
  2. **질문-차단 사이클 ≤2회**: 같은 의문을 묻고 막히는 반복은 회차당 2회 이하(3회차부터는 질문의 '내용'이 바뀌어야 함).
  3. **장면 재방문 신정보 의무**: 같은 (장소×인물조합) 재방문 시 이전 방문 대비 새 정보·새 상태 동반.
  4. **청크 목표 단일**: 각 청크(10/10/10/4)는 1개의 서사 목표만 갖는다 — 청크 내 목표 전환·회귀 금지.
- **측정 시점**: episode-outliner 비트시트 → script-editor 교정 시 N-축 자가검증 표 부기, 오케스트레이터가 스폰 프롬프트로 요구.
- **판정**: 위반 컷 → 대본 수정(재렌더 아님 — 상류 피드백).

### V-게이트 체크리스트 개정 (교실 시리즈 — 기존 항목 + 4항목 추가)
기존(좌표·SFX·신체·인원·텍스트·소품) + **⑪좌석 그리드 직교성·사다리꼴 여부** + **⑫통로·간격 가독(촘촘함)** + **⑬착석 포즈 자연성(골반·각도·발·스케일)** + **⑭대화 시선쌍·반응 비트**.

### 소급 적용 규칙
- **ep01 핀 컷은 동결**(재렌더 금지 원칙 승계) — 다만 사용자가 원하면 국소 수리 후보만 별도 제시(플레이트 상속 결함은 전면 재렌더 비용 경고 필수).
- **ep02 발주 전 필수 절차**: ①PLATE_A/B/C를 BL-18/19 기준으로 재게이트 — 불통과 시 **플레이트부터 재렌더**(간격 강화 문구) 후 패널 착수 ②샷리스트 단계 BL-21·N-축 콘티 게이트 ③모든 매니페스트에 BL-18~21 긍정 절 자동 주입(본 원장 운용 규칙 1).

## 교실 시리즈 검증 강화 v2.1 (2026-09-23 2차 — ep01 독자 실측 추가 3종)

**피드백 원문 요지**: ①책상에 아이들이 까득 안 앉았는데 "자리가 없다"고 나온다 ②벽쪽에서 사람 없이 손만 나온다 ③아이들이 칠판 쪽에 앉았다가 반대쪽에 앉는다.

### BL-22 시각-서사 인원 밀도 정합 (군집 컷 점유율) — 실측: ep01 panel_001(15~20% vs 대사 '자리 없음')·011·016
- **결함 구조**: 대사·설정이 만석/군집을 요구해도 **렌더러가 빈 플레이트 참조를 우선해 좌석을 비워 둔다** (SCENE_REFS 우선 원칙의 역효과 — 참조가 "빈 교실"이면 텍스트의 "꽉 찬"이 무시됨). 프롬프트에 "packed crowd"를 써도 점유율 15~25%로 렌더 실측.
- **표준 긍정 절(EN, 단일 문장 — 군집/만석 컷 주입)**: "the seat grid is visibly populated — at least 80 percent of the 24 desks each show a seated generic student in plain uniform seen from behind or softly out of focus, with only the marked empty seat (and any story-specified empty seats) left vacant"
- **구조 해법(플레이트 우선)**: 군집 컷은 빈 플레이트 대신 **만석 플레이트(PLATE_*_FULL — 24석 전부 착석 제네릭 학생)**를 S-1에서 사전 렌더해 SCENE_REFS로 주입한다. 참조가 이미 찬 교실이면 점유율이 유지된다(신원 없는 제네릭이라 캐릭터 일관성 축과 무충돌). 만석 플레이트는 BL-18/19(그리드·간격)·BL-20(착석 포즈) 게이트를 통과해야 합격.
- **측정 기준**: V-게이트 시각 측정 — 대사가 만석/자리 없음을 주장하는 컷의 점유율 **≥80%**, 군집 배경 컷(수업·군집 이동) **≥60%**. 무시각 측정 불가축 명시.
- **라우팅**: 미달 시 [RE-RENDER] + 만석 플레이트 참조로 교체.

### BL-11-CLS 유령 손 강화 (교실 군집 변형) — 실측: ep01 panel_020 좌하단(연결 몸 없는 손)
- **실측**: "복수의 손" 컷에서 손이 벽/공간에서 직접 나옴 — 반해상도 컨택트시트 V-게이트와 무시각 검증(BL-13/14 측정 불가 선언)이 모두 놓침.
- **표준 긍정 절(EN, 단일 문장 — 손 군집 컷 주입)**: "every visible hand emerges from a sleeved forearm connected to a seated student's shoulder within the same panel — hands never sprout from walls, desks edges, or empty air, and each hand-owner is at least partially visible (head or shoulders) near the hand"
- **검증 강화**: 손 군집 컷은 **원해상도(반해상도 컨택트시트 아님) V-게이트 필수** — 컨택트시트는 결함 스크리닝용이고 손-소유자 연결 판정은 full-res 열람에서만 유효(실측).
- **라우팅**: [RE-RENDER].

### BL-23 착석 방향·위치 컷 간 고정 — 실측: 사용자 "칠판 쪽으로 앉았다가 반대쪽으로"
- **결함 구조**: 착석 인물의 '바라보는 방향'과 '앉은 열 위치'가 컷 간 뒤집혀 보임. 원인 후보 2 — ①축이 다른 플레이트(A축=정면 향한 등, B축=전경 등)의 정상 차이를 독자가 뒤집힘으로 오인 ②실제로 착석 방향/열 위치가 컷 간 불일치. ep01 표본 검사(001·011·016·020·021)에서는 축 준수 확인 — 다만 **독자 오인 방지도 게이트 목표**에 포함한다.
- **표준 긍정 절(EN, 단일 문장 — 착석 인물 컷 주입)**: "every seated student always faces the front blackboard wall of the classroom, and occupied seat columns keep the same physical positions across all panels (window-side column nearest the windows in every PLATE_C shot, seat grid inherited unchanged from the reference plate)"
- **측정 기준**: V-게이트 — ①착석 인물 시선·신체 방향 = 전방(칠판 벽) 방향, 카메라 향한 얼굴 금지(후면 샷 제외) ②같은 회차 내 착석 열 배치 고정 ③**독자 혼동 완화**: 축 전환이 있는 연속 컷에는 정지 신호(샷 타입 변화·거터) 수반 확인.
- **라우팅**: 실제 불일치 [RE-RENDER] / 연출 문제는 샷리스트 단계 panel-directer 재지시.

### V-게이트 체크리스트 개정 (v2.1 — 기존 + 2항목)
**⑮군집 점유율(대사 정합)** + **⑯손-소유자 연결(원해상드 전용 축 — 손 컷은 full-res 열람)**.

### PR-03 플레이트 게이트 체크리스트 전 항목 의무화 (v10.2 사이클 실측 — 2026-09-23 등재)
- **사고**: FULL 플레이트 v2 V-게이트에서 점유율·공석·손·포즈만 확인하고 **BL-18 그리드 기하(사다리꼴)·행 분포(전 행 착석)를 점검하지 않아** 결함 플레이트가 핀되고 6컷 재렌더로 상속 — 독자 실측 "첫 사진부터 사다리꼴·뒤쪽 편중 착석"으로 재발견.
- **규칙**: 플레이트(EMPTY/FULL 모두) 게이트는 **BL-18·19·20·22·23(+축·손·텍스트) 전 항목을 빠짐없이 실행**한 뒤에만 핀한다 — 부분 점검 핀 금지. 게이트 질문 목록이 원장 항목과 1:1 대응해야 한다.
- **문구 교훈**: "정렬(aligned)" 같은 추상 지시는 실효 낮음 — **행 기준 묘사**("every desk sits EXACTLY behind the desk in front of it, zero sideways offset") + **원근 수렴 명시** + **분포 명시**("every row from the nearest front row to the back row")로 쓴다(v3 프롬프트 채택).

### BL-08 비고 (2026-09-23 — antigravity 1.2.9 SFX 픽셀 타겟 불수렴 실측)
- ep01 020 「사각사각」 스팬: 명시 픽셀 타겟(153~187px) **7회 연속 미수렴**(44.8→33.5→25.2→15.3→22.2→22.5→28.7%W 진자·역퇴행 포함) — 백엔드 고정축 한계로 확정. PIL 사후 리사이즈는 PR-01로 폐쇄.
- **후속 회차 지침**: SFX는 ①평면 단색 배경 위에 배치해 사후 리사이즈 검토 가능하게 하거나 ②2음절 이내 짧은 SFX로 설계하거나 ③스펙 밴드를 넓게 잡고 FLAG 허용 범위로 관리한다. 4음절+복잡 배경 조합은 피한다.

### PR-04 그리드 기하·행 분포의 자동 게이트 무효 선언 + 후보 선택 절차 (ep01 v10.2 3차 실측 — 2026-09-23 등재)
- **실측**: FULL 플레이트/패널의 사다리꼴·뒤편중 착석에 대해 ①비전 모델이 "완벽한 직선" 환각 판정 2회 ②BL-22 점유율 산법(전체 navy 비율)이 행별 편중을 못 잡음(전경 공석+후열 밀집을 "178%"로 오판) ③프롬프트 재렌더 룰렛 2사이클 실패 — 동일 결함 3회 사용자 신고.
- **규칙**: ① **그리드 기하·행 분포의 최종 판정자는 사용자**다 — 자동 게이트(비전·레일 피팅)는 스크리닝일 뿐 핀 근거가 아니다. ② BL-22 측정은 **행별 3분할(전경 1/3·중경·후경) navy 비율**로 재정의 — 전경 1/3이 군집 컷에서 공석이면 점유율 계약 실패(전체 합계 무관). ③ **FULL 플레이트 채택 절차**: 프롬프트 변형 4~5종 후보 다발 렌더 → 라벨 컨택트시트 → **사용자 선택** → 선택본만 핀·패널 상속. 패널도 동일(사용자 확인 전 재봉인 금지).

### BL-22 확장 — 패턴 스테이징 계약 (ep01 012 실측 — 2026-09-23 등재)
- **실측**: 「다들, 저 통로는 안 지나가네」 대사 컷이 '대부분 착석' 상태만 보여줌 — 회피 패턴의 시각 증거 부재(사용자 지적).
- **규칙**: 대사가 주장하는 **시각 패턴**(회피·우역·혼잡·정지 등 행동 양상)은 프레임 안에 **명시적 증거**로 스테이징된다 — 상태(앉아 있음 등)만으로는 불충분. 패턴 대조조(예: 걷는 통로 vs 빈 통로)가 한 프레임에 함께 보여야 한다.
- **표준 절(예시 — 012형)**: "in the CENTER aisle three generic students walk away from the camera in a loose line, while the window-side aisle at the RIGHT is completely empty of walkers from front to back — the walking flow conspicuously avoids that aisle"
- **판정**: V-게이트 — 대사 패턴 요소가 프레임에서 식별 가능한지(무시각 불가축 — 시각 판정).

### BL-23 비고 — 보케·아웃포커스 군집에도 방향 계약 적용 (ep01 001 DOF 실측 — 2026-09-23)
- **실측**: DOF 포커싱 컷에서 흐릿한 배경 군집이 문(카메라) 쪽을 향해 좌정 + 최전경 학생이 의자에 반대로 착석 — "흐려서 방향 판정 면제"가 성립하지 않음(리본·어깨선·무릎 방향이 방향을 노출).
- **규칙**: 아웃포커스 군집에도 BL-23 착석 방향(전방 칠판 고정)을 그대로 적용한다. 문가 카메라 구도에서는 "seen from the door the crowd shows backs and backs of heads — no student faces the door" 절을 상시 주입.

### BL-19 비고 — 공석 절은 "사람 없음"이지 "가구 없음"이 아니다 (ep01 012 v2 실측 — 2026-09-23)
- **실측**: "창가 통로 완전 공석" 지시가 창가 열 책상 삭제로 렌더됨 — 통로가 넓은 빈 바닥처럼 읽힘(사용자 지적 "책상들이 없어졌어").
- **규칙**: 공석·비어 있음 계약에는 반드시 "empty of PEOPLE — all desks remain in place and occupied/unoccupied as specified" 병기. 통로 판독은 양쪽 책상 열이 존재해야 성립한다.
