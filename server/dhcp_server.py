# -*- coding: utf-8 -*-
"""PXE boot server - DHCP part. Two modes ([dhcp] mode in pxe_config.ini):
  proxy - proxyDHCP on UDP/4011. Shares the LAN with the router:
          router gives clients their IP, we only answer boot requests.
          SAFE for single-NIC shop operation.
  full  - classic DHCP on UDP/67 with IP pool. ISOLATED SWITCH ONLY!
          Never use on a LAN with another DHCP server/router.
Boot file is chosen by DHCP option 93 (client arch):
  0 = BIOS -> undionly.kpxe | 7/9 = UEFI x64 -> ipxe.efi
Run as Administrator (firewall + TFTP/69 need it; 4011 does not strictly).
"""
import configparser, ipaddress, socket, struct, threading, time, os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = configparser.ConfigParser()
CFG.read(os.path.join(BASE, "pxe_config.ini"), encoding="utf-8")

SERVER_IP = CFG.get("server", "server_ip")
MODE = CFG.get("dhcp", "mode", fallback="proxy").strip().lower()
PROXY_PORT = CFG.getint("dhcp", "proxy_port", fallback=4011)
MASK = CFG.get("server", "subnet_mask")
FILE_BIOS = CFG.get("dhcp", "bootfile_bios")
FILE_UEFI = CFG.get("dhcp", "bootfile_uefi64")
POOL_START = ipaddress.IPv4Address(CFG.get("dhcp", "pool_start", fallback="192.168.10.100"))
POOL_END = ipaddress.IPv4Address(CFG.get("dhcp", "pool_end", fallback="192.168.10.200"))
LEASE = CFG.getint("dhcp", "lease_seconds", fallback=3600)

leases = {}
lock = threading.Lock()

def next_ip(mac):
    now = time.time()
    with lock:
        if mac in leases and leases[mac][1] > now:
            return leases[mac][0]
        used = {v[0] for v in leases.values()}
        for i in range(int(POOL_START), int(POOL_END) + 1):
            ip = str(ipaddress.IPv4Address(i))
            if ip not in used:
                leases[mac] = (ip, now + LEASE)
                return ip
        return None

def parse_opts(data):
    opts = {}
    i = 0
    magic = b"\x63\x82\x53\x63"
    if magic in data:
        i = data.index(magic) + 4
    while i < len(data):
        c = data[i]; i += 1
        if c == 0: continue
        if c == 255: break
        if i >= len(data): break
        ln = data[i]; i += 1
        opts[c] = data[i:i+ln]; i += ln
    return opts

def bootp_base(xid, yiaddr, siaddr, bootfile, cli_mac):
    pkt = struct.pack("!BBBBIHH", 2, 1, 6, 0, xid, 0, 0)
    pkt += socket.inet_aton("0.0.0.0")      # ciaddr
    pkt += socket.inet_aton(yiaddr)         # yiaddr
    pkt += socket.inet_aton(siaddr)         # siaddr (next server)
    pkt += socket.inet_aton("0.0.0.0")      # giaddr
    pkt += bytes.fromhex(cli_mac.replace(":", "")) + b"\x00" * 10  # chaddr
    pkt += b"\x00" * 64                     # sname
    pkt += bootfile.encode()[:128].ljust(128, b"\x00")  # file
    pkt += b"\x63\x82\x53\x63"              # magic
    return pkt

def full_offer_ack(xid, yiaddr, msgtype, bootfile, cli_mac):
    srv = socket.inet_aton(SERVER_IP)
    pkt = bootp_base(xid, yiaddr, SERVER_IP, bootfile, cli_mac)
    pkt += struct.pack("BBB", 53, 1, msgtype)   # 2=offer 5=ack
    pkt += struct.pack("BBB", 54, 4, 0) + srv
    pkt += struct.pack("BBB", 51, 4, 0) + struct.pack("!I", LEASE)
    pkt += struct.pack("BBB", 1, 4, 0) + socket.inet_aton(MASK)
    pkt += struct.pack("BBB", 66, 4, 0) + srv
    bf = bootfile.encode()
    pkt += bytes([67, len(bf)]) + bf
    pkt += b"\xff"
    return pkt

def proxy_ack(xid, bootfile, cli_mac):
    """Answer a PXE boot request. Assigns NO IP (yiaddr=0)."""
    srv = socket.inet_aton(SERVER_IP)
    pkt = bootp_base(xid, "0.0.0.0", SERVER_IP, bootfile, cli_mac)
    pkt += struct.pack("BBB", 53, 1, 5)     # ack
    pkt += struct.pack("BBB", 54, 4, 0) + srv
    pkt += bytes([60, 9]) + b"PXEClient"    # vendor class
    pkt += struct.pack("BBB", 66, 4, 0) + srv
    bf = bootfile.encode()
    pkt += bytes([67, len(bf)]) + bf
    pkt += b"\xff"
    return pkt

def pick_bootfile(opts):
    arch = int.from_bytes(opts.get(93, b"\x00\x00"), "big") if 93 in opts else 0
    return (FILE_UEFI if arch in (7, 9) else FILE_BIOS), arch

def serve_full():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        s.bind(("0.0.0.0", 67))
    except OSError as e:
        print(f"[DHCP-full] cannot bind UDP/67 (need Admin?): {e}")
        return
    print(f"[DHCP-full] UDP/67 server={SERVER_IP} pool={POOL_START}-{POOL_END}")
    while True:
        data, _ = s.recvfrom(1024)
        if len(data) < 240: continue
        xid = struct.unpack("!I", data[4:8])[0]
        mac = ":".join(f"{b:02x}" for b in data[28:34])
        opts = parse_opts(data[236:])
        mtype = opts.get(53, b"\x00")[0] if 53 in opts else 0
        bootfile, arch = pick_bootfile(opts)
        if mtype == 1:
            ip = next_ip(mac)
            if not ip:
                print(f"[DHCP-full] pool exhausted for {mac}")
                continue
            s.sendto(full_offer_ack(xid, ip, 2, bootfile, mac), ("<broadcast>", 68))
            print(f"[DHCP-full] OFFER {ip} -> {mac} arch={arch} file={bootfile}")
        elif mtype == 3:
            rip = socket.inet_ntoa(opts.get(50, b"\x00\x00\x00\x00")) if 50 in opts else None
            ip = next_ip(mac)
            if rip and rip != ip:
                ip = rip
                with lock:
                    leases[mac] = (ip, time.time() + LEASE)
            s.sendto(full_offer_ack(xid, ip, 5, bootfile, mac), ("<broadcast>", 68))
            print(f"[DHCP-full] ACK {ip} -> {mac} file={bootfile}")

def serve_proxy():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        s.bind(("0.0.0.0", PROXY_PORT))
    except OSError as e:
        print(f"[DHCP-proxy] cannot bind UDP/{PROXY_PORT}: {e}")
        return
    print(f"[DHCP-proxy] UDP/{PROXY_PORT} next-server={SERVER_IP} (router keeps assigning IPs)")
    while True:
        data, _ = s.recvfrom(1024)
        if len(data) < 240: continue
        xid = struct.unpack("!I", data[4:8])[0]
        mac = ":".join(f"{b:02x}" for b in data[28:34])
        opts = parse_opts(data[236:])
        mtype = opts.get(53, b"\x00")[0] if 53 in opts else 0
        if mtype not in (1, 3):
            continue
        bootfile, arch = pick_bootfile(opts)
        s.sendto(proxy_ack(xid, bootfile, mac), ("<broadcast>", 68))
        print(f"[DHCP-proxy] BOOT {mac} arch={arch} file={bootfile}")

if __name__ == "__main__":
    if MODE == "full":
        print("WARNING: full DHCP mode - use on an ISOLATED switch only!")
        serve_full()
    else:
        serve_proxy()
