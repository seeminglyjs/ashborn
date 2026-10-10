"""build/web 을 이 PC 에서만 보이게 띄우는 정적 서버 (play.ps1 이 부른다).

    python -I tool/play/serve.py <dir> <port>

- 127.0.0.1 에만 묶어 다른 기기에서는 접속할 수 없다.
- 캐시를 끄므로 새로 빌드하면 창을 다시 여는 것만으로 새 버전이 뜬다.
- Windows 레지스트리의 MIME 설정이 꼬여 있어도 .js · .wasm 이 제대로 실행되게 직접 지정한다.
"""

import functools
import http.server
import sys

TYPES = {
    ".js": "text/javascript",
    ".mjs": "text/javascript",
    ".wasm": "application/wasm",
    ".json": "application/json",
    ".html": "text/html",
    ".png": "image/png",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, **TYPES}

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format, *args):
        pass


def main():
    directory, port = sys.argv[1], int(sys.argv[2])
    handler = functools.partial(Handler, directory=directory)
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
