# tests — 렌더 배치 스크립트 회귀 테스트

가짜 백엔드(fake codex·fake agy·fake Z.ai API 서버)로 렌더 배치 스크립트 3종을
실제 호출해 정상/결함 경로를 검증한다.

```bash
bash tests/run_tests.sh        # 전체 시나리오 실행, PASS/FAIL 집계 (실패 시 exit 1)
```

커버 시나리오: 정상 렌더, 웨이브 분할(3/3/1), md5 중복, 0바이트, 손상, 파일 미생성,
타임아웃, 매니페스트 모드, 동시성 상한 거부, zai API 오류, JPEG 수용, 키 없음 거부.

의존: bash 3.2+, python3, file, md5(-r)/md5sum. JPEG 수용 테스트는 sips가 있으면
실제 JPEG 픽스처를 생성해 검증한다(macOS 기본 내장).

스크립트·lib/common.sh를 수정한 뒤에는 반드시 이 테스트를 돌린다.
