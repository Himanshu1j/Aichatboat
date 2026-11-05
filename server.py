#!/usr/bin/env python3
"""Tiny local web UI and same-origin proxy for llama-server."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
import json

ROOT = Path(__file__).resolve().parent
LLAMA_API = "http://127.0.0.1:8081"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = (ROOT / "index.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path == "/health":
            self.respond_json(200, {"ok": True})
            return
        self.respond_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            self.respond_json(404, {"error": "not found"})
            return
        length = min(int(self.headers.get("Content-Length", "0")), 2_000_000)
        payload = self.rfile.read(length)
        try:
            req = Request(LLAMA_API + self.path, data=payload,
                          headers={"Content-Type": "application/json"}, method="POST")
            with urlopen(req, timeout=600) as response:
                body = response.read()
                self.send_response(response.status)
                self.send_header("Content-Type", response.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
        except HTTPError as e:
            self.respond_json(e.code, {"error": e.read().decode("utf-8", "replace")})
        except (URLError, TimeoutError) as e:
            self.respond_json(503, {"error": f"llama.cpp server is not available: {e}"})

    def respond_json(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("[web] " + fmt % args)


if __name__ == "__main__":
    print("Chat UI: http://127.0.0.1:8000")
    ThreadingHTTPServer(("127.0.0.1", 8000), Handler).serve_forever()
