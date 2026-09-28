# -*- coding: utf-8 -*-
"""HTTP file server for netboot - stdlib only.
Serves D:\\Station\\netboot on TCP/8080 (avoids clashing with IIS on 80).
iPXE pulls menu.ipxe + wimboot + boot.sdi + boot.wim over HTTP (fast on 1Gbps).
Run as Administrator only for firewall; port 8080 binds without admin but
firewall rule still needed for clients to reach it.
"""
import configparser, os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = configparser.ConfigParser()
CFG.read(os.path.join(BASE, "pxe_config.ini"), encoding="utf-8")
ROOT = CFG.get("http", "root")
PORT = CFG.getint("http", "bind_port")

class H(SimpleHTTPRequestHandler):
    def log_message(self, *a):
        print("[HTTP]", *a[1:])
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

if __name__ == "__main__":
    os.makedirs(ROOT, exist_ok=True)
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), partial(H, directory=ROOT))
    print(f"[HTTP] serving {ROOT} on TCP/{PORT}")
    srv.serve_forever()
