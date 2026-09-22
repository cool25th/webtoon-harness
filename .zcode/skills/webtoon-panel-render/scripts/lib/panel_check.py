#!/usr/bin/env python3
"""panel_check.py — 패널 렌더 후 1차 자동 검사(형식/크기/매트 BL-07). PIL 의존만.

Usage:
  panel_check.py <image_path>            # 단일 파일
  panel_check.py <dir> [*.png glob]      # 디렉토리 모드 — 정렬된 PNG 전수 검사 + 요약표

Env:
  PANEL_CHECK_SIZE  기대 크기 "WxH" (기본 848x1264 — 백엔드별로 다르면 지정,
                    예: zai 1056x1568 → PANEL_CHECK_SIZE=1056x1568)

Exit (단일 파일 — v10 실측판과 동일 코드 체계):
  0 OK · 2 매트(BL-07) 감지 · 3 크기 불일치 · 4 이미지 아님
Exit (디렉토리): 0 전부 통과 · 1 하나 이상 문제(상세는 표 출력)

V-게이트 4계층의 1계층 — 통과해도 2계층(panel-validator 8축)·3계층(메인 전수
열람)은 생략할 수 없다. 매트는 재렌더로 안 없어지므로(BL-07 실측) [PIL] 라우팅.
"""
import math
import os
import sys

from PIL import Image

def target_size():
    raw = os.environ.get("PANEL_CHECK_SIZE", "848x1264")
    try:
        w, h = raw.lower().split("x", 1)
        return (int(w), int(h))
    except ValueError:
        raise SystemExit(f"PANEL_CHECK_SIZE 형식 오류(WxH): {raw}")

TARGET = target_size()

def check(p):
    """(exit_code, 한줄 리포트) — 코드 체계는 v10 실측판 승계."""
    try:
        im = Image.open(p)
        fmt = im.format
    except Exception:
        return 4, f"FORMAT=unreadable"
    w, h = im.size
    g = im.convert("L")
    bands = {"top": g.crop((0, 0, w, 6)), "bottom": g.crop((0, h - 6, w, h)),
             "left": g.crop((0, 0, 6, h)), "right": g.crop((w - 6, 0, w, h))}
    matte = []
    for name, band in bands.items():
        d = band.tobytes()
        mean = sum(d) / len(d)
        std = math.sqrt(sum((x - mean) ** 2 for x in d) / len(d))
        if mean >= 200 and std < 4:
            matte.append(name)
    ratio_ok = abs(w * 3 - h * 2) <= 2  # 2:3 portrait
    report = (f"FORMAT={fmt} SIZE={w},{h} "
              f"MATTE={','.join(matte) if matte else 'none'} "
              f"RATIO={'2:3' if ratio_ok else 'other'}")
    if matte:
        return 2, report
    if (w, h) != TARGET:
        return 3, report
    return 0, report

def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    if os.path.isdir(path):
        names = sorted(n for n in os.listdir(path)
                       if n.lower().endswith(".png"))
        if not names:
            print(f"검사할 PNG 없음: {path}")
            return 1
        bad = 0
        for n in names:
            code, report = check(os.path.join(path, n))
            verdict = {0: "OK", 2: "MATTE", 3: "SIZE", 4: "NOTIMG"}.get(code, "?")
            print(f"{verdict:6} {n:20} {report}")
            if code != 0:
                bad += 1
        print(f"--- 총 {len(names)} / 통과 {len(names) - bad} / 문제 {bad} "
              f"(기대 크기 {TARGET[0]}x{TARGET[1]}) ---")
        return 0 if bad == 0 else 1
    code, report = check(path)
    print(report)
    return code

if __name__ == "__main__":
    sys.exit(main(sys.argv))
