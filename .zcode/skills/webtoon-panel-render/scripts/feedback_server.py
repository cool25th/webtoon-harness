#!/usr/bin/env python3
"""feedback_server.py — 정적 파일 + 피드백 POST 수집 서버 (v10.4 클릭 지적 게이트)

사용법: python3 feedback_server.py <서빙 루트> <피드백 저장 파일> [포트]
- GET  /            : 정적 파일 서빙
- POST /api/feedback: JSON 1건을 피드백 파일에 JSONL append (received_at 자동 부착)
"""
import http.server, socketserver, json, os, sys, datetime

ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
FEEDBACK = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(ROOT, 'feedback.json')
PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 8765

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204); self.end_headers()

    def do_POST(self):
        if not self.path.startswith('/api/feedback'):
            self.send_response(404); self.end_headers(); return
        try:
            length = int(self.headers.get('Content-Length', 0))
            data = json.loads(self.rfile.read(length) or b'{}')
            data['received_at'] = datetime.datetime.now().isoformat(timespec='seconds')
            os.makedirs(os.path.dirname(FEEDBACK) or '.', exist_ok=True)
            with open(FEEDBACK, 'a', encoding='utf-8') as f:
                f.write(json.dumps(data, ensure_ascii=False) + '\n')
            body = b'{"ok":true}'
            self.send_response(200)
        except Exception as e:
            body = json.dumps({'ok': False, 'error': str(e)}).encode()
            self.send_response(500)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True

if __name__ == '__main__':
    with Server(('127.0.0.1', PORT), Handler) as httpd:
        print(f'serving {ROOT} on :{PORT} — feedback → {FEEDBACK}', flush=True)
        httpd.serve_forever()
