#!/usr/bin/env python3
"""Exercise the real Swift downloader against a local HTTP server."""
import http.server
import os
from pathlib import Path
import subprocess
import tempfile
import threading

root = Path(__file__).resolve().parents[1]
build = root / '.build/tests'
build.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(build / 'ModuleCache'),
                str(root / 'Pock/Network/Services/Downloader.swift'),
                str(root / 'Tests/DownloaderTests.swift'), '-o', str(build / 'DownloaderTests')], check=True)

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/missing':
            self.send_error(404)
            return
        self.send_response(200)
        if self.path != '/unknown-length':
            self.send_header('Content-Length', '1000' if self.path == '/truncated' else '11')
        self.end_headers()
        self.wfile.write(b'widget-data')
        self.close_connection = True

    def log_message(self, *_):
        pass

with http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory(dir=build) as temporary:
        subprocess.run([str(build / 'DownloaderTests'), f'http://127.0.0.1:{server.server_port}/'],
                       env={**os.environ, 'POCK_TEST_TEMP': temporary}, check=True)
    server.shutdown()
