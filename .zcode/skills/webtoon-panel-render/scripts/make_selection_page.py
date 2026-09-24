#!/usr/bin/env python3
"""make_selection_page.py — 3테이크 선택 비교 페이지 생성 (v10.3 선택 게이트 표준 도구)

사용법:
  python3 make_selection_page.py --out candidates.html \
      --title "선택 페이지 제목" --note "상단 안내문" \
      --item "panel_001|테이크1|경로.png" --item "panel_001|테이크2|경로.png" ...

--item 형식: 그룹ID|설명|이미지경로  (같은 그룹ID끼리 한 섹션으로 묶임)
이미지는 base64로 인라인 — 단일 HTML 파일로 브라우저에서 바로 열람 가능.
"""
import argparse, base64, html, os, sys
from collections import OrderedDict

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--title', default='선택 페이지')
    ap.add_argument('--note', default='')
    ap.add_argument('--item', action='append', required=True,
                    help='그룹ID|설명|이미지경로')
    args = ap.parse_args()

    groups = OrderedDict()
    for it in args.item:
        parts = it.split('|', 2)
        if len(parts) != 3:
            sys.exit(f'--item 형식 오류: {it}')
        gid, desc, path = parts
        if not os.path.isfile(path):
            sys.exit(f'파일 없음: {path}')
        groups.setdefault(gid, []).append((desc, path))

    cards = []
    for gid, items in groups.items():
        cards.append(f'<h2>(html.escapegid) {html.escape(gid)}</h2>'.replace('(html.escapegid)', ''))
        cards[-1] = f'<h2>{html.escape(gid)}</h2><div class="grid">'
        for desc, path in items:
            b64 = base64.b64encode(open(path, 'rb').read()).decode()
            name = html.escape(os.path.basename(path))
            cards[-1] += (f'<figure><img src="data:image/png;base64,{b64}">'
                          f'<figcaption><b>{html.escape(desc)}</b><br><code>{name}</code></figcaption></figure>')
        cards[-1] += '</div>'

    doc = f"""<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<title>{html.escape(args.title)}</title>
<style>
body{{background:#111114;color:#eee;font-family:system-ui,sans-serif;margin:0;padding:24px}}
h1{{font-size:20px}} h2{{font-size:15px;color:#f0c;margin:28px 0 10px}}
.note{{color:#aaa;font-size:14px;line-height:1.6;white-space:pre-line}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}}
figure{{margin:0}}
img{{width:100%;display:block;border:1px solid #333}}
figcaption{{font-size:12px;color:#bbb;padding:6px 2px;line-height:1.5}}
code{{font-size:11px;color:#777}}
</style></head><body>
<h1>{html.escape(args.title)}</h1>
<p class="note">{html.escape(args.note)}</p>
{''.join(cards)}
</body></html>"""
    open(args.out, 'w').write(doc)
    print(f'selection page: {args.out} ({os.path.getsize(args.out)//1024}KB, {len(args.item)} items, {len(groups)} groups)')

if __name__ == '__main__':
    main()
