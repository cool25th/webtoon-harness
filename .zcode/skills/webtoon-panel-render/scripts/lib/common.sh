#!/usr/bin/env bash
# common.sh — 렌더 배치 스크립트 공통부 (백엔드 스크립트가 source해서 사용)
#
# 호출 스크립트 계약:
#   - source 후 설정: DEFAULT_TIMEOUT_SECS, LEGACY_TIMEOUT_VAR(선택), REASON_RENDER_FAIL(선택),
#     REASON_FILE_MISSING(선택), IMAGE_FORMAT_RE(선택). CONCURRENCY는 기본 5로 읽는다.
#   - 정의할 것: render_one() — $1=prompt $2=file $3=log $4=idx, 성공 시 0
#   - 재정의 가능: render_fail_reason($idx) — RC≠0 항목의 사유 문구
#   - 흐름: parse_items "$@" → (백엔드 헤더 echo) → run_waves → integrity_check → print_summary_and_exit
#
# 전제: 호출 스크립트가 set -u 상태. bash 3.2(macOS /bin/bash) 호환.

IMAGE_FORMAT_RE="${IMAGE_FORMAT_RE:-PNG image data\|JPEG image data}"
REASON_RENDER_FAIL="${REASON_RENDER_FAIL:-렌더 실패 — 로그 참고}"
REASON_FILE_MISSING="${REASON_FILE_MISSING:-파일 미생성}"

usage() { # 선두 헤더 주석 블록만 출력(파일 중간의 인라인 주석 제외)
  sed -n '1,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//' | tail -n +2
  exit 2
}

init_md5() {
  if command -v md5 >/dev/null 2>&1; then
    MD5_CMD="md5 -r"
  else
    MD5_CMD="md5sum"
  fi
}

init_timeout() {
  RENDER_TIMEOUT_SECS="${RENDER_TIMEOUT_SECS:-}"
  if [ -z "$RENDER_TIMEOUT_SECS" ] && [ -n "${LEGACY_TIMEOUT_VAR:-}" ]; then
    RENDER_TIMEOUT_SECS="${!LEGACY_TIMEOUT_VAR:-}"
  fi
  RENDER_TIMEOUT_SECS="${RENDER_TIMEOUT_SECS:-$DEFAULT_TIMEOUT_SECS}"
}

# 입력 파싱 + 출력 디렉토리 준비: PROMPTS/FILES/TOTAL/OUT_DIR/LOG_DIR/ROOT 구성.
parse_items() { # $@ = <output_dir> "<prompt>::<file>"...  또는  --from-file <manifest> <output_dir>
  [ $# -ge 2 ] || usage

  MANIFEST=""
  if [ "$1" = "--from-file" ]; then
    [ $# -ge 3 ] || usage
    MANIFEST="$2"
    [ -f "$MANIFEST" ] || { echo "manifest 파일 없음: $MANIFEST" >&2; exit 2; }
    shift 2
  fi

  OUT_DIR="$1"
  shift
  case "$OUT_DIR" in
    /*) ;;
    *) OUT_DIR="${OUT_DIR%/}" ;;
  esac
  [ -n "$OUT_DIR" ] || { echo "output_dir 필요" >&2; exit 2; }

  if [ "$CONCURRENCY" -gt 5 ]; then
    echo "거부: CONCURRENCY=$CONCURRENCY — 하네스 렌더 동시성 상한은 5다. 5 이하로 설정할 것." >&2
    exit 2
  fi

  mkdir -p "$OUT_DIR" || exit 2
  LOG_DIR="$OUT_DIR/.render_logs"
  mkdir -p "$LOG_DIR"

  PROMPTS=()
  FILES=()
  if [ -n "$MANIFEST" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ''|\#*) continue ;;
      esac
      p="${line%::*}"
      f="${line##*::}"
      if [ -z "$p" ] || [ -z "$f" ] || [ "$p" = "$line" ]; then
        echo "manifest 형식 오류(prompt::file): $line" >&2
        exit 2
      fi
      PROMPTS+=("$p")
      FILES+=("$f")
    done < "$MANIFEST"
  else
    for raw in "$@"; do
      p="${raw%::*}"
      f="${raw##*::}"
      if [ -z "$p" ] || [ -z "$f" ] || [ "$p" = "$raw" ]; then
        echo "항목 형식 오류(prompt::file): $raw" >&2
        exit 2
      fi
      PROMPTS+=("$p")
      FILES+=("$f")
    done
  fi

  TOTAL=${#PROMPTS[@]}
  [ "$TOTAL" -gt 0 ] || { echo "렌더 항목이 없다" >&2; exit 2; }

  ROOT="$(pwd)"
}

# 동시 CONCURRENCY장 웨이브 실행 + 항목당 타임아웃 감시. 결과는 RC[i]에 담는다.
run_waves() {
  RC=()
  for ((i=0; i<TOTAL; i++)); do RC[$i]=""; done

  idx=0
  wave_no=0
  while [ "$idx" -lt "$TOTAL" ]; do
    wave_no=$((wave_no + 1))
    end=$((idx + CONCURRENCY))
    [ "$end" -gt "$TOTAL" ] && end=$TOTAL
    count=$((end - idx))
    echo "--- wave $wave_no: 항목 $((idx+1))~$end (${count}장 동시) ---"

    WAVE_PIDS=()
    WAVE_IDX=()
    i=$idx
    while [ "$i" -lt "$end" ]; do
      f="${FILES[$i]}"
      log="$LOG_DIR/$(printf '%03d' $((i+1)))_render.log"
      render_one "${PROMPTS[$i]}" "$f" "$log" "$((i+1))" &
      WAVE_PIDS+=($!)
      WAVE_IDX+=("$i")
      i=$((i + 1))
    done

    # 타임아웃 감시: 마감 후 생존 프로세스 강제 종료(정상 종료 시 발화 전 제거).
    # stdio를 /dev/null로 격리 — 안 그러면 kill로 죽은 감시자의 sleep 자식이
    # 고아가 되어 상위 커맨드 치환의 stdout 파이프를 붙잡고 10분간 hang한다(실측).
    (
      sleep "$RENDER_TIMEOUT_SECS"
      for p in "${WAVE_PIDS[@]}"; do kill "$p" 2>/dev/null; done
    ) >/dev/null 2>&1 </dev/null &
    WATCHDOG=$!

    w=0
    while [ "$w" -lt "$count" ]; do
      p="${WAVE_PIDS[$w]}"
      wi="${WAVE_IDX[$w]}"
      wait "$p"
      RC[$wi]=$?
      w=$((w + 1))
    done
    kill "$WATCHDOG" 2>/dev/null
    wait "$WATCHDOG" 2>/dev/null

    idx=$end
  done
}

render_fail_reason() { # $1=idx → stdout에 사유 문구
  printf '%s' "$REASON_RENDER_FAIL"
}

# 0바이트/손상(포맷)/md5 중복 검사 — FAIL_NAMES/FAIL_REASONS/OK_NAMES/DUP_GROUPS 구성.
integrity_check() {
  FAIL_NAMES=()
  FAIL_REASONS=()
  OK_NAMES=()
  HASHFILE="$LOG_DIR/_hashes.txt"
  : > "$HASHFILE"

  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    f="${FILES[$i]}"
    target="$OUT_DIR/$f"
    if [ "${RC[$i]}" != "0" ]; then
      FAIL_NAMES+=("$f"); FAIL_REASONS+=("$(render_fail_reason "$i")")
      i=$((i + 1)); continue
    fi
    if [ ! -f "$target" ]; then
      FAIL_NAMES+=("$f"); FAIL_REASONS+=("$REASON_FILE_MISSING")
      i=$((i + 1)); continue
    fi
    if [ ! -s "$target" ]; then
      FAIL_NAMES+=("$f"); FAIL_REASONS+=("0바이트")
      i=$((i + 1)); continue
    fi
    if ! file -b "$target" | grep -qi "$IMAGE_FORMAT_RE"; then
      FAIL_NAMES+=("$f"); FAIL_REASONS+=("이미지 아님(손상)")
      i=$((i + 1)); continue
    fi
    hash=$($MD5_CMD "$target" | awk '{print $1}')
    printf '%s\t%s\n' "$hash" "$f" >> "$HASHFILE"
    OK_NAMES+=("$f")
    i=$((i + 1))
  done

  DUP_GROUPS=$(cut -f1 "$HASHFILE" | sort | uniq -d)
}

# 사람이 읽는 요약 + 종료 코드(0=전 항목 유효·중복 없음, 1=문제 있음).
print_summary_and_exit() {
  echo ""
  echo "=== 요약 ==="
  echo "총 $TOTAL / 유효 ${#OK_NAMES[@]} / 문제 ${#FAIL_NAMES[@]}"
  k=0
  while [ "$k" -lt "${#FAIL_NAMES[@]}" ]; do
    echo "[FAIL] ${FAIL_NAMES[$k]} — ${FAIL_REASONS[$k]}"
    k=$((k + 1))
  done
  if [ -n "$DUP_GROUPS" ]; then
    while IFS= read -r h; do
      dup_names=$(grep "^$h" "$HASHFILE" | cut -f2 | paste -sd, -)
      echo "[DUP]  $dup_names — 동일 이미지(md5 $h). 모두 삭제 후 각각 단독 재렌더."
    done <<< "$DUP_GROUPS"
  fi
  echo "로그: $LOG_DIR"

  if [ "${#FAIL_NAMES[@]}" -eq 0 ] && [ -z "$DUP_GROUPS" ]; then
    echo "1차 무결성 통과 — 이어서 panel-validator 7축 검증으로."
    exit 0
  fi
  exit 1
}
