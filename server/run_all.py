# -*- coding: utf-8 -*-
"""Launcher - starts DHCP + TFTP + HTTP together. Run as Administrator."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
procs = []
for f in ("dhcp_server.py", "tftp_server.py", "http_server.py"):
    p = subprocess.Popen([PY, os.path.join(HERE, f)])
    procs.append(p)
    print(f"started {f} pid={p.pid}")
print("All services running. Press Ctrl+C to stop.")
try:
    for p in procs:
        p.wait()
except KeyboardInterrupt:
    for p in procs:
        p.terminate()
