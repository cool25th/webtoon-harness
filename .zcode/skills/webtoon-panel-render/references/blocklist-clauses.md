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
- **적용 조건**: 동일 LOC 토큰을 공유하는 연속·근접(≤10컷) WIDE/MED 컷 및 유리/문 축 포함 컷 전부 — 특히 그룹 내 2번째 이상 등장하는 실내 와이드. 기존 `NOT a repeat of any prior framing` 절은 문장형 반복 금지라 템플릿 수렴 방지에 불충분(실측) — 본 절을 좌표형(배치가 시점을 따른다)으로 병용 주입
- **라우팅 비고**: 렌더 후 zcorr 80+ 잔류쌍은 변별 지표(픽셀 diff·에지 IoU·SSIM)로 진성 중복 여부 재판정 — 진성이면 [RE-RENDER](구도 완전 재지시), 템플릿 기인이면 FLAG+조립 리듬 관찰. 재발주는 지표가 아니라 "구도 완전 재지시" 문구로만 유효(022 실측: 같은 프롬프트 재시도는 지표 불응)

## 변경 이력

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
