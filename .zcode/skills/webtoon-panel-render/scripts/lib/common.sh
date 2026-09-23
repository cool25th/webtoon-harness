#!/usr/bin/env bash
# common.sh — 렌더 배치 스크립트 공통부 (백엔드 스크립트가 source해서 사용)
#
# 호출 스크립트 계약:
#   - source 후 설정: DEFAULT_TIMEOUT_SECS, LEGACY_TIMEOUT_VAR(선택), REASON_RENDER_FAIL(선택),
#     REASON_FILE_MISSING(선택), IMAGE_FORMAT_RE(선택). CONCURRENCY는 기본 5로 읽는다.
#     BACKEND_ID / BACKEND_VERSION(선택) — 누적 원장 메타데이터 기록용(v11).
#   - 정의할 것: render_one() — $1=prompt $2=file $3=log $4=idx, 성공 시 0
#   - 재정의 가능: render_fail_reason($idx) — RC≠0 항목의 사유 문구
#   - 흐름: parse_items "$@" → init_ledger → compute_item_meta → apply_resume
#          → (백엔드 헤더 echo) → run_waves → integrity_check → print_summary_and_exit
#
# 누적 원장(v11): {OUT_DIR}/.render_logs/_ledger.tsv 에 배치마다 # META 행과 항목별
#   시도를 append 한다(실행마다 초기화하지 않는다 — 회차 전체의 유일한 상태 저장소).
#   열: ts / backend / backend_version / filename / attempt / prompt_hash / md5 / status / reason
#   파생 산출물:
#     _batch_summary.tsv  이번 배치의 기계판독 요약(매 배치 새로 씀)
#     {stem}_try{N}.log   시도별 렌더 로그 — 재시도 배치에서 이전 로그를 덮어쓰지 않는다
#   --resume 플래그(parse_items 첫 인자): 원장에서 (filename, prompt_hash)의 최근
#   status=OK인 항목은 렌더를 스킵한다 — "이미 성공한 작업을 다시 실행하지 않는다".
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

# 입력 파싱 + 출력 디렉토리 준비: PROMPTS/FILES/TOTAL/OUT_DIR/LOG_DIR/ROOT/RESUME 구성.
parse_items() { # $@ = [--resume] <output_dir> "<prompt>::<file>"...  또는  [--resume] --from-file <manifest> <output_dir>
  RESUME=0
  if [ "${1:-}" = "--resume" ]; then
    RESUME=1
    shift
    [ $# -ge 1 ] || usage
  fi

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

# 누적 원장 — 배치 META 행 append + 이번 배치 요약 파일 초기화.
init_ledger() {
  LEDGER="$LOG_DIR/_ledger.tsv"
  BATCH_SUMMARY="$LOG_DIR/_batch_summary.tsv"
  BACKEND_ID="${BACKEND_ID:-unknown}"
  BACKEND_VERSION="${BACKEND_VERSION:-unknown}"
  if [ -n "$MANIFEST" ]; then
    _meta_manifest="$MANIFEST"
  else
    _meta_manifest="argv"
  fi
  printf '# META\t%s\tbackend=%s\tversion=%s\tconcurrency=%s\tmanifest=%s\tresume=%s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$BACKEND_ID" "$BACKEND_VERSION" \
    "$CONCURRENCY" "$_meta_manifest" "$RESUME" >> "$LEDGER"
  printf 'filename\tstatus\treason\tmd5\tattempt\n' > "$BATCH_SUMMARY"
}

# 항목별 prompt_hash 산출 + 원장 기준 시도 횟수(attempt) 계산.
# 3회차 이상 진입 시 상한 경고 — "패널당 재렌더 3회 상한"의 스크립트 레벨 강제.
compute_item_meta() {
  PROMPT_HASH=()
  ATTEMPT=()
  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    PROMPT_HASH[$i]="$(printf '%s' "${PROMPTS[$i]}" | $MD5_CMD | awk '{print $1}')"
    if [ -f "$LEDGER" ]; then
      ATTEMPT[$i]="$(awk -F'\t' -v f="${FILES[$i]}" '$4==f {n++} END{print n+1}' "$LEDGER")"
    else
      ATTEMPT[$i]=1
    fi
    if [ "${ATTEMPT[$i]}" -ge 3 ]; then
      echo "[주의] ${FILES[$i]} — 시도 ${ATTEMPT[$i]}회차 진입: 재렌더 상한 3회(제작 규칙 §7) 초과 주의. 신중히 — 미달 시 최선본 유지 원칙." >&2
    fi
    i=$((i + 1))
  done
}

# --resume: 원장에서 (filename, prompt_hash) 최근 status=OK인 항목에 SKIP[i]=1.
apply_resume() {
  SKIP=()
  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    SKIP[$i]=0
    i=$((i + 1))
  done
  [ "$RESUME" = "1" ] || return 0
  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    _st="$(awk -F'\t' -v f="${FILES[$i]}" -v h="${PROMPT_HASH[$i]}" '$4==f && $6==h {s=$8} END{print s}' "$LEDGER" 2>/dev/null)"
    if [ "$_st" = "OK" ]; then
      SKIP[$i]=1
    fi
    i=$((i + 1))
  done
}

# 동시 CONCURRENCY장 웨이브 실행 + 항목당 타임아웃 감시. 결과는 RC[i]에 담는다.
# SKIP 항목은 렌더하지 않고 RC=0로 승계. 로그는 {stem}_try{attempt}.log로 쓴다.
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
    echo "--- wave $wave_no: 항목 $((idx+1))~$end (${count}장 배치) ---"

    WAVE_PIDS=()
    WAVE_IDX=()
    i=$idx
    while [ "$i" -lt "$end" ]; do
      f="${FILES[$i]}"
      if [ "${SKIP[$i]:-0}" = "1" ]; then
        echo "--- skip ${f}: 원장 OK 승계(--resume) — 재렌더 생략 ---"
        RC[$i]=0
        i=$((i + 1))
        continue
      fi
      log="$LOG_DIR/$(stem_for "$f")_try${ATTEMPT[$i]}.log"
      render_one "${PROMPTS[$i]}" "$f" "$log" "$((i+1))" &
      WAVE_PIDS+=($!)
      WAVE_IDX+=("$i")
      i=$((i + 1))
    done

    if [ "${#WAVE_PIDS[@]}" -gt 0 ]; then
      # 타임아웃 감시: 마감 후 생존 프로세스 강제 종료(정상 종료 시 발화 전 제거).
      # stdio를 /dev/null로 격리 — 안 그러면 kill로 죽은 감시자의 sleep 자식이
      # 고아가 되어 상위 커맨드 치환의 stdout 파이프를 붙잡고 10분간 hang한다(실측).
      (
        sleep "$RENDER_TIMEOUT_SECS"
        for p in "${WAVE_PIDS[@]}"; do kill "$p" 2>/dev/null; done
      ) >/dev/null 2>&1 </dev/null &
      WATCHDOG=$!

      w=0
      while [ "$w" -lt "${#WAVE_PIDS[@]}" ]; do
        p="${WAVE_PIDS[$w]}"
        wi="${WAVE_IDX[$w]}"
        wait "$p"
        RC[$wi]=$?
        w=$((w + 1))
      done
      kill "$WATCHDOG" 2>/dev/null
      wait "$WATCHDOG" 2>/dev/null
    fi

    idx=$end
  done
}

render_fail_reason() { # $1=idx → stdout에 사유 문구
  printf '%s' "$REASON_RENDER_FAIL"
}

# 파일명 stem — 로그/메타 이름 규격({stem}_try{N}.log·{stem}_last.md와 동일 규칙)
stem_for() { # $1=file (PROMPTS/FILES 항목) → stdout
  local base="${1##*/}"
  printf '%s' "${base%.*}"
}

# 저장 지시용 경로 — OUT_DIR 절대면 그대로, 상대면 ROOT 기준 절대화(백엔드 지시문 삽입용)
save_path_for() { # $1=file → stdout
  case "$OUT_DIR" in
    /*) printf '%s/%s' "$OUT_DIR" "$1" ;;
    *)  printf '%s/%s/%s' "$ROOT" "$OUT_DIR" "$1" ;;
  esac
}

# 0바이트/손상(포맷)/md5 중복 검사 + 누적 원장·배치 요약 기록.
# 결과: ITEM_STATUS[i]/ITEM_REASON[i]/MD5S[i], 파생 FAIL_NAMES/FAIL_REASONS/OK_NAMES/SKIP_NAMES/DUP_GROUPS.
integrity_check() {
  HASHFILE="$LOG_DIR/_hashes.txt"
  : > "$HASHFILE"

  ITEM_STATUS=()
  ITEM_REASON=()
  MD5S=()

  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    f="${FILES[$i]}"
    target="$OUT_DIR/$f"
    MD5S[$i]="-"
    ITEM_REASON[$i]=""
    if [ "${SKIP[$i]:-0}" = "1" ]; then
      ITEM_STATUS[$i]="SKIP"
      i=$((i + 1)); continue
    fi
    if [ "${RC[$i]}" != "0" ]; then
      ITEM_STATUS[$i]="FAIL"
      ITEM_REASON[$i]="$(render_fail_reason "$i")"
      i=$((i + 1)); continue
    fi
    if [ ! -f "$target" ]; then
      ITEM_STATUS[$i]="FAIL"
      ITEM_REASON[$i]="$REASON_FILE_MISSING"
      i=$((i + 1)); continue
    fi
    if [ ! -s "$target" ]; then
      ITEM_STATUS[$i]="FAIL"
      ITEM_REASON[$i]="0바이트"
      i=$((i + 1)); continue
    fi
    if ! file -b "$target" | grep -qi "$IMAGE_FORMAT_RE"; then
      ITEM_STATUS[$i]="FAIL"
      ITEM_REASON[$i]="이미지 아님(손상)"
      i=$((i + 1)); continue
    fi
    hash=$($MD5_CMD "$target" | awk '{print $1}')
    MD5S[$i]="$hash"
    printf '%s\t%s\n' "$hash" "$f" >> "$HASHFILE"
    ITEM_STATUS[$i]="OK"
    i=$((i + 1))
  done

  DUP_GROUPS=$(cut -f1 "$HASHFILE" | sort | uniq -d)

  # DUP 판정 — 이번 배치에서 동일 md5가 된 항목은 status=DUP로 강등.
  if [ -n "$DUP_GROUPS" ]; then
    while IFS= read -r h; do
      i=0
      while [ "$i" -lt "$TOTAL" ]; do
        if [ "${ITEM_STATUS[$i]}" = "OK" ] && [ "${MD5S[$i]}" = "$h" ]; then
          ITEM_STATUS[$i]="DUP"
          ITEM_REASON[$i]="동일 이미지(md5 $h) — 모두 삭제 후 각각 단독 재렌더"
        fi
        i=$((i + 1))
      done
    done <<< "$DUP_GROUPS"
  fi

  # 누적 원장 append + 이번 배치 요약. SKIP은 새 시도가 아니므로 원장에 추가하지 않는다.
  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    f="${FILES[$i]}"
    st="${ITEM_STATUS[$i]}"
    if [ "$st" != "SKIP" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')" "$BACKEND_ID" "$BACKEND_VERSION" \
        "$f" "${ATTEMPT[$i]}" "${PROMPT_HASH[$i]}" "${MD5S[$i]}" "$st" "${ITEM_REASON[$i]}" >> "$LEDGER"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$st" "${ITEM_REASON[$i]}" "${MD5S[$i]}" "${ATTEMPT[$i]}" >> "$BATCH_SUMMARY"
    i=$((i + 1))
  done

  # 호환용 파생 배열(요약 출력·후속 스크립트용).
  FAIL_NAMES=()
  FAIL_REASONS=()
  OK_NAMES=()
  SKIP_NAMES=()
  i=0
  while [ "$i" -lt "$TOTAL" ]; do
    case "${ITEM_STATUS[$i]}" in
      FAIL) FAIL_NAMES+=("${FILES[$i]}"); FAIL_REASONS+=("${ITEM_REASON[$i]}") ;;
      OK|DUP) OK_NAMES+=("${FILES[$i]}") ;;
      SKIP) SKIP_NAMES+=("${FILES[$i]}") ;;
    esac
    i=$((i + 1))
  done
}

# 사람이 읽는 요약 + 종료 코드(0=전 항목 유효·중복 없음, 1=문제 있음).
print_summary_and_exit() {
  echo ""
  echo "=== 요약 ==="
  echo "총 $TOTAL / 유효 ${#OK_NAMES[@]} / 문제 ${#FAIL_NAMES[@]} / 스킵 ${#SKIP_NAMES[@]}"
  k=0
  while [ "$k" -lt "${#FAIL_NAMES[@]}" ]; do
    echo "[FAIL] ${FAIL_NAMES[$k]} — ${FAIL_REASONS[$k]}"
    k=$((k + 1))
  done
  k=0
  while [ "$k" -lt "${#SKIP_NAMES[@]}" ]; do
    echo "[SKIP] ${SKIP_NAMES[$k]} — 원장 OK 승계(--resume)"
    k=$((k + 1))
  done
  if [ -n "$DUP_GROUPS" ]; then
    while IFS= read -r h; do
      dup_names=$(grep "^$h" "$HASHFILE" | cut -f2 | paste -sd, -)
      echo "[DUP]  $dup_names — 동일 이미지(md5 $h). 모두 삭제 후 각각 단독 재렌더."
    done <<< "$DUP_GROUPS"
  fi
  echo "로그: $LOG_DIR"
  echo "원장: $LEDGER (누적 — 시도 이력·프롬프트 해시·백엔드 버전)"

  if [ "${#FAIL_NAMES[@]}" -eq 0 ] && [ -z "$DUP_GROUPS" ]; then
    echo "1차 무결성 통과 — 이어서 panel_check.py 자동검사 → panel-validator 8축 검증으로."
    exit 0
  fi
  exit 1
}
