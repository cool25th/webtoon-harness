#!/usr/bin/env python3
"""make_storybook.py — 스토리북 HTML 생성 (v10.3 스토리북 게이트 표준 도구)

사용법:
  python3 make_storybook.py --script ep{NN}_script_final.md --out storybook.html \
      [--title "..."] [--logline "..."] [--images dir] [--panel-prefix panel_] \
      [--benchmarks bench.json] [--changed "4,5,9"] [--max-width 360] \
      [--feedback http://127.0.0.1:8765/api/feedback] [--episode ep01]

기능: 컷 카드(이미지+장면+대사+컷메타+태그) · 벤치마크 칩 · 수정 컷 배지 · 이미지 경량화 ·
클릭 지적 UI(POST /api/feedback — v10.4 클릭 지적 게이트)
"""
import argparse, base64, html, io, json, re, sys, os

FEEDBACK_JS = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
          'feedback_snippet.html'), encoding='utf-8').read()

def parse_script(path):
    text = open(path, encoding='utf-8').read()
    cuts = []
    blocks = re.split(r'(?m)^### (C\d+)\s*—\s*(.+)$', text)
    for k in range(1, len(blocks) - 2, 3):
        num, title, body = blocks[k].strip(), blocks[k + 1].strip(), blocks[k + 2]
        body = body.split('\n## ')[0].split('\n---\n')[0]
        def grab(label):
            m = re.search(r'-\s*\*\*' + label + r'\*\*:\s*(.+)', body)
            return m.group(1).strip() if m else ''
        dialog = []
        dm = re.search(r'-\s*\*\*대사\*\*:\s*\n((?:\s+-\s+.+\n?)+)', body)
        if dm:
            for dl in dm.group(1).splitlines():
                mm = re.match(r'\s*-\s*\S\s+(\S+)\s+「(.+)」', dl)
                if mm:
                    dialog.append((mm.group(1), mm.group(2)))
        cuts.append(dict(num=num, title=title, scene=grab('장면'), meta=grab('컷메타'),
                         dialog=dialog, tags=grab('태그')))
    return cuts

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--script', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--title', default='스토리북')
    ap.add_argument('--logline', default='')
    ap.add_argument('--images', default=None)
    ap.add_argument('--panel-prefix', default='panel_')
    ap.add_argument('--benchmarks', default=None)
    ap.add_argument('--changed', default='')
    ap.add_argument('--max-width', type=int, default=None)
    ap.add_argument('--feedback', default=None)
    ap.add_argument('--story-file', default=None, help='맨 위에 표시할 스토리 요약 마크다운 파일')
    ap.add_argument('--cast', action='append', default=[], help='이름|설명|이미지경로 — 최상단 캐릭터 셋')
    ap.add_argument('--episode', default='ep01')
    args = ap.parse_args()

    cuts = parse_script(args.script)
    if not cuts:
        sys.exit('컷을 파싱하지 못했습니다 — 스크립트 형식 확인')
    changed = {int(x) for x in args.changed.split(',') if x.strip().isdigit()}
    bench = {'story': [], 'cuts': {}}
    if args.benchmarks:
        raw = json.load(open(args.benchmarks, encoding='utf-8'))
        ranges = {}
        for key, items in raw.get('cuts', {}).items():
            m = re.match(r'C(\d+)-C(\d+)$', key)
            if m:
                for n in range(int(m.group(1)), int(m.group(2)) + 1):
                    ranges['C%d' % n] = items
            else:
                ranges[key] = items
        bench = {'story': raw.get('story', []), 'cuts': ranges}

    cast_html = ''
    if args.cast:
        cc = ''
        for item in args.cast:
            pp = item.split('|', 2)
            if len(pp) != 3 or not os.path.isfile(pp[2]):
                continue
            im = PILImage.open(pp[2]).convert('RGB')
            if args.max_width and im.width > args.max_width:
                im = im.resize((args.max_width, int(im.height * args.max_width / im.width)))
            buf = io.BytesIO(); im.save(buf, 'JPEG', quality=78)
            b64 = base64.b64encode(buf.getvalue()).decode()
            cc += ('<figure class="castcard"><img src="data:image/jpeg;base64,%s">'
                   '<figcaption><b>%s</b><br>%s</figcaption></figure>' % (
                   b64, html.escape(pp[0]), html.escape(pp[1])))
        if cc:
            cast_html = ('<div class="castsec"><div class="benchhead">등장 캐릭터 — 캐릭터 셋</div>'
                         '<div class="castgrid">%s</div></div>' % cc)
    story_html = ''
    if args.story_file:
        raw = open(args.story_file, encoding='utf-8').read()
        parts = []
        for line in raw.splitlines():
            if line.startswith('## '):
                parts.append('<div class="sh2">%s</div>' % html.escape(line[3:].strip()))
            elif line.startswith('- **'):
                m = re.match(r'- \*\*(.+?)\*\*\s*—\s*(.*)', line)
                if m: parts.append('<div class="sli"><b>%s</b> — %s</div>' % (html.escape(m.group(1)), html.escape(m.group(2))))
                else: parts.append('<div class="sli">%s</div>' % html.escape(line[2:]))
            elif line.strip():
                parts.append('<p class="sp">%s</p>' % html.escape(line.strip()))
        story_html = ('<details class="fold" open><summary>1화 스토리 — 전체 요약</summary>'
                      '<div class="storysec">%s</div></details>' % ''.join(parts))
    story_bench = ''
    if bench['story']:
        rows = ''.join('<div class="benchrow"><b>%s</b> — %s: %s</div>' % (
            html.escape(b['work']), html.escape(b['similar']), html.escape(b.get('note', '')))
            for b in bench['story'])
        story_bench = ('<details class="fold"><summary>유사 인기 웹툰 벤치마크</summary>'
                      '<div class="benchstory">%s</div></details>' % rows)

    tone = {'W': ('와이드', '#7c5cbf'), 'M': ('미디엄', '#2f7fbf'),
            'C': ('클로즈업', '#bf7c2f'), 'E': ('익스트림', '#bf2f4f')}
    cards = ['<details class="act" open><summary>ACT 1 — 입장과 규칙 (C1~C10)</summary><div class="actbody">']
    for c in cuts:
        n = int(c['num'][1:])
        meta_parts = [p.strip() for p in c['meta'].split('·')] if c['meta'] else []
        shot = meta_parts[0] if meta_parts else ''
        badge, color = tone.get(shot[:1].upper(), (shot or '컷', '#666'))
        tension = next((p for p in meta_parts if '긴장' in p), '')
        img_html = ''
        if args.images:
            for ext in ('.png', '.jpg'):
                p = os.path.join(args.images, '%s%03d%s' % (args.panel_prefix, n, ext))
                if os.path.isfile(p):
                    im = PILImage.open(p).convert('RGB')
                    if args.max_width and im.width > args.max_width:
                        im = im.resize((args.max_width, int(im.height * args.max_width / im.width)))
                    buf = io.BytesIO(); im.save(buf, 'JPEG', quality=78)
                    b64 = base64.b64encode(buf.getvalue()).decode()
                    stale = ' <span class="stale">구판</span>' if n in changed else ''
                    cls = 'imgnum stalebg' if n in changed else 'imgnum'
                    img_html = ('<div class="imgwrap"><img src="data:image/jpeg;base64,%s">'
                                '<div class="%s">%02d%s</div></div>' % (b64, cls, n, stale))
                    break
        if not img_html:
            img_html = ('<div class="imgwrap noimg"><div class="imgnum">%02d</div>'
                        '<div class="noimgtxt">이미지 없음</div></div>' % n)
        dlg = ''.join(
            '<div class="bubble"><span class="spk">%s</span>%s</div>' % (html.escape(s), html.escape(t))
            for s, t in c['dialog']) or '<div class="silent">무대사 — 그림이 말한다</div>'
        v2 = '<span class="v2badge">v2 수정</span>' if n in changed else ''
        bl = bench['cuts'].get(c['num'], [])
        bench_chip = ''
        if bl:
            chips = ''.join('<span class="bchip"><b>%s</b> %s</span>' % (html.escape(b['work']), html.escape(b['similar'])) for b in bl)
            bench_chip = '<div class="bench">벤치마크 %s</div>' % chips
        cards.append("""
<section class="cut">
  %s
  <div class="txt">
    <div class="head"><span class="num">C%02d</span>
      <span class="badge" style="background:%s">%s</span>
      %s %s
      <span class="cuttitle">%s</span></div>
    <p class="scene">%s</p>
    <div class="dialog">%s</div>
    <div class="tags">%s</div>
    %s
  </div>
</section>""" % (img_html, n, color, html.escape(badge),
                 '<span class="tension">%s</span>' % html.escape(tension) if tension else '',
                 v2, html.escape(c['title']), html.escape(c['scene']), dlg,
                 html.escape(c['tags']), bench_chip))
        if n == 10:
            cards.append('</div></details><details class="act"><summary>ACT 2 — 관찰과 실험 (C11~C20)</summary><div class="actbody">')
        if n == 20:
            cards.append('</div></details><details class="act"><summary>ACT 3 — 노을과 목격 (C21~C30)</summary><div class="actbody">')
        if n == 30:
            cards.append('</div></details><details class="act"><summary>엔딩 — 무예고 절단 (C31~C34)</summary><div class="actbody">')

    cards.append('</div></details>')

    doc = """<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<title>__TITLE__</title>
<style>
*{box-sizing:border-box}
body{background:#141419;color:#e8e6e1;font-family:system-ui,'Apple SD Gothic Neo',sans-serif;margin:0;padding:26px 18px}
.wrap{max-width:880px;margin:0 auto}
h1{font-size:24px;margin:0 0 8px}
.logline{color:#a9a6a0;font-size:14.5px;line-height:1.7;margin-bottom:18px;border-left:3px solid #b0567a;padding-left:12px}
.count{display:inline-block;background:#b0567a;color:#fff;padding:4px 12px;border-radius:14px;font-size:12.5px;font-weight:700;margin-bottom:22px}
.cut{display:flex;gap:18px;background:#1d1d24;border:1px solid #2c2c36;border-radius:14px;padding:14px;margin-bottom:14px;align-items:flex-start}
.imgwrap{position:relative;flex:0 0 200px}
.imgwrap img,.imgwrap.noimg{width:200px;border-radius:10px;display:block;border:1px solid #34343f}
.imgwrap.noimg{height:298px;background:#242430;display:flex;align-items:center;justify-content:center}
.noimgtxt{color:#555;font-size:12px}
.imgnum{position:absolute;top:8px;left:8px;background:#b0567a;color:#fff;font-weight:800;font-size:14px;padding:2px 9px;border-radius:8px}
.stalebg{background:#2f7fbf}
.stale{font-size:9px;font-weight:600}
.txt{flex:1;min-width:0}
.head{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:7px}
.num{font-size:17px;font-weight:800;color:#b0567a}
.badge{color:#fff;font-size:11px;font-weight:700;padding:2px 9px;border-radius:10px}
.tension{color:#8fd3ff;font-size:11px}
.v2badge{background:#2f7fbf;color:#fff;font-size:10.5px;font-weight:800;padding:2px 8px;border-radius:9px}
.cuttitle{font-weight:700;font-size:15.5px}
.scene{font-size:14px;line-height:1.7;color:#c9c6c0;margin:0 0 10px}
.dialog{display:flex;flex-direction:column;gap:7px;margin-bottom:9px}
.bubble{background:#fff;color:#1a1a1f;border-radius:4px 16px 16px 16px;padding:9px 14px;font-size:15px;font-weight:600;max-width:92%;line-height:1.5}
.spk{display:block;font-size:11px;font-weight:800;color:#b0567a;margin-bottom:2px}
.silent{color:#6a6875;font-size:12.5px;font-style:italic}
.tags{font-size:11.5px;color:#8a87a0;border-top:1px dashed #34343f;padding-top:7px;margin-top:2px}
.bench{margin-top:8px;font-size:11.5px}
.bchip{display:inline-block;background:#20283f;color:#8fd3ff;border:1px solid #2f4f7f;border-radius:10px;padding:2px 9px;margin:2px 4px 2px 0}
.bchip b{color:#cfe4ff}
.storysec{background:#221c2e;border:1px solid #4a3a5f;border-radius:14px;padding:16px 18px;margin-bottom:14px}
.sh2{font-weight:800;color:#c9a3ff;font-size:14px;margin:10px 0 6px}
.sh2:first-child{margin-top:0}
.sli{font-size:13.5px;color:#d5d2cc;line-height:1.75}
.sp{font-size:13.5px;color:#d5d2cc;line-height:1.75;margin:0 0 8px}
.castsec{background:#1a2030;border:1px solid #2f4f7f;border-radius:14px;padding:16px 18px;margin-bottom:14px}
.castgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:14px}
.castcard{margin:0}
.castcard img{width:100%;border-radius:10px;display:block;border:1px solid #34343f}
.castcard figcaption{font-size:12px;color:#c9c6c0;padding:6px 2px;line-height:1.5}
.castcard b{color:#fff;font-size:14px}
details.fold,details.act{background:#1d1d24;border:1px solid #2c2c36;border-radius:14px;margin-bottom:14px;overflow:hidden}
details.fold summary,details.act summary{cursor:pointer;font-weight:800;font-size:14px;color:#e8e6e1;padding:12px 16px;list-style:none}
details.fold summary::before,details.act summary::before{content:'▸ ';color:#b0567a}
details[open].fold summary::before,details[open].act summary::before{content:'▾ '}
details.act .actbody{padding:0 14px 14px}
.benchstory{background:#1d1d24;border:1px solid #2c2c36;border-radius:14px;padding:14px 16px;margin-bottom:22px}
.benchhead{font-weight:800;color:#8fd3ff;font-size:14px;margin-bottom:8px}
.benchrow{font-size:13px;color:#c9c6c0;line-height:1.7}
.chunk{text-align:center;margin:30px 0;font-weight:800;letter-spacing:3px;font-size:14px}
.chunk span{background:#b0567a;color:#fff;padding:6px 18px;border-radius:18px}
@media (max-width:640px){.cut{flex-direction:column}.imgwrap{flex:none;width:100%}.imgwrap img,.imgwrap.noimg{width:100%}}
</style></head><body><div class="wrap">
<h1>__TITLE__</h1>
<div class="logline">__LOGLINE__</div>
<div class="count">총 __NCUTS__컷 · 10/10/10/4 청크</div>
__CAST__
__STORYSEC__
__STORYBENCH__
__CARDS__
</div></body></html>"""
    doc = (doc.replace('__TITLE__', html.escape(args.title))
              .replace('__LOGLINE__', html.escape(args.logline))
              .replace('__NCUTS__', str(len(cuts)))
              .replace('__CAST__', cast_html)
              .replace('__STORYSEC__', story_html)
              .replace('__STORYBENCH__', story_bench)
              .replace('__CARDS__', ''.join(cards)))
    if args.feedback:
        js = FEEDBACK_JS.replace('__EPISODE__', args.episode).replace('__ENDPOINT__', args.feedback)
        doc = doc.replace('</body>', js + '</body>')
    open(args.out, 'w').write(doc)
    print('storybook: %s (%d cuts, images=%s, feedback=%s)' % (
        args.out, len(cuts), bool(args.images), bool(args.feedback)))

if __name__ == '__main__':
    from PIL import Image as PILImage
    main()
