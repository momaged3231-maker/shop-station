# -*- coding: utf-8 -*-
"""Minimal TFTP server (RRQ only) - stdlib only.
Serves D:\\Station\\netboot over UDP/69. Small files only (iPXE).
Large WIMs go over HTTP/SMB, not TFTP.
Run as Administrator.
"""
import configparser, os, socket, struct

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = configparser.ConfigParser()
CFG.read(os.path.join(BASE, "pxe_config.ini"), encoding="utf-8")
ROOT = CFG.get("tftp", "root")
PORT = CFG.getint("tftp", "bind_port")

def safe(path):
    p = os.path.normpath(os.path.join(ROOT, path.replace("/", os.sep).lstrip("\\/")))
    return p if p.startswith(os.path.normpath(ROOT)) else None

def serve():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.bind(("0.0.0.0", PORT))
    except OSError as e:
        print(f"[TFTP] cannot bind UDP/{PORT} (need Admin?): {e}")
        return
    print(f"[TFTP] serving {ROOT} on UDP/{PORT}")
    while True:
        data, cli = s.recvfrom(516)
        if len(data) < 4 or struct.unpack("!H", data[:2])[0] != 1:
            continue
        parts = data[2:].split(b"\x00")
        fname = parts[0].decode("utf-8", "ignore")
        fpath = safe(fname)
        if not fpath or not os.path.isfile(fpath):
            err = struct.pack("!HH", 5, 1) + "File not found".encode() + b"\x00"
            s.sendto(err, cli)
            print(f"[TFTP] NOT FOUND: {fname}")
            continue
        print(f"[TFTP] send {fname} -> {cli[0]}")
        with open(fpath, "rb") as f:
            block = 1
            while True:
                chunk = f.read(512)
                pkt = struct.pack("!HH", 3, block) + chunk
                s.sendto(pkt, cli)
                s.settimeout(5)
                try:
                    ack, _ = s.recvfrom(516)
                    if struct.unpack("!HH", ack[:4]) != (4, block):
                        break
                except socket.timeout:
                    print(f"[TFTP] timeout {fname} block {block}")
                    break
                if len(chunk) < 512:
                    break
                block = (block + 1) % 65536

if __name__ == "__main__":
    serve()
