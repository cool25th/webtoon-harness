#!/usr/bin/env python3
"""fake_zai_server.py — zai_imagegen_batch.sh 테스트용 가짜 Z.ai 이미지 API

Usage: fake_zai_server.py <port> <fixture_png> <fixture_jpeg|->

프롬프트 마커로 동작 제어(fake_agy와 동일 계열):
  MARK_DUP1/MARK_DUP2 → 같은 이미지 URL(md5 중복 유도)
  MARK_EMPTY → 0바이트 / MARK_JUNK → 텍스트 / MARK_FAILAPI → API 오류 JSON
  MARK_404 → 이미지 URL이 404 / MARK_JPEG → JPEG 바이트로 응답
  기본 → 요청마다 고유한 유효 PNG
"""
import http.server
import json
import pathlib
import sys

PORT = int(sys.argv[1])
PNG = pathlib.Path(sys.argv[2]).read_bytes()
JPEG = pathlib.Path(sys.argv[3]).read_bytes() if sys.argv[3] != "-" else None


class H(http.server.BaseHTTPRequestHandler):
    counter = 1

    def log_message(self, *a):
        pass

    def _send(self, code, body=b"", ctype="application/octet-stream"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(n))
        p = req.get("prompt", "")
        if "MARK_FAILAPI" in p:
            body = json.dumps({"code": 1211, "message": "fake content policy"}).encode()
            return self._send(200, body, "application/json")
        marker = next((m for m in ("MARK_DUP1", "MARK_DUP2", "MARK_EMPTY",
                                   "MARK_JUNK", "MARK_404", "MARK_JPEG") if m in p), None)
        name = {"MARK_DUP1": "dup", "MARK_DUP2": "dup", "MARK_EMPTY": "empty",
                "MARK_JUNK": "junk", "MARK_404": "missing", "MARK_JPEG": "jpeg"}.get(marker, "ok")
        body = json.dumps({"created": 1,
                           "data": [{"url": f"http://127.0.0.1:{PORT}/img/{name}"}]}).encode()
        self._send(200, body, "application/json")

    def do_GET(self):
        name = self.path.rsplit("/", 1)[-1]
        if name == "ok":
            body = bytes(PNG[:-1]) + bytes([PNG[-1] ^ (H.counter & 0xFF)])
            H.counter += 1
            return self._send(200, body, "image/png")
        if name == "jpeg":
            return self._send(200, JPEG, "image/jpeg")
        if name == "dup":
            return self._send(200, PNG, "image/png")
        if name == "empty":
            return self._send(200, b"", "image/png")
        if name == "junk":
            return self._send(200, b"not an image", "text/plain")
        self._send(404, b"nope")


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
