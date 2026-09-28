# -*- coding: utf-8 -*-
"""DHCP server for the shop - stdlib only, no pip needed.
Listens UDP/67, answers Discover/Request with Offer/ACK.
Selects boot file by DHCP option 93 (client arch):
  0 = BIOS -> undionly.kpxe | 7/9 = UEFI x64 -> ipxe.efi
Run as Administrator. Serves only 192.168.10.0/24 pool.
"""
import configparser, ipaddress, socket, struct, threading, time, os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = configparser.ConfigParser()
CFG.read(os.path.join(BASE, "pxe_config.ini"), encoding="utf-8")

SERVER_IP = CFG.get("server", "server_ip")
POOL_START = ipaddress.IPv4Address(CFG.get("dhcp", "pool_start"))
POOL_END = CFG.get("dhcp", "pool_end")
LEASE = CFG.getint("dhcp", "lease_seconds")
MASK = CFG.get("server", "subnet_mask")
FILE_BIOS = CFG.get("dhcp", "bootfile_bios")
FILE_UEFI = CFG.get("dhcp", "bootfile_uefi64")

leases = {}   # mac -> (ip, expiry)
issued = {}
lock = threading.Lock()

def next_ip(mac):
    now = time.time()
    with lock:
        if mac in leases and leases[mac][1] > now:
            return leases[mac][0]
        base = int(POOL_START)
        end = int(POOL_END)
        used = {v[0] for v in leases.values()}
        for i in range(base, end + 1):
            ip = str(ipaddress.IPv4Address(i))
            if ip not in used:
                leases[mac] = (ip, now + LEASE)
                return ip
        return None

def parse_opts(data):
    """Return dict opt->bytes, skipping pad(0)/end(255)."""
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

def build_reply(xid, yiaddr, msgtype, bootfile, cli_mac):
    # Ethernet+IP+UDP headers not needed; we craft BOOTP payload only.
    # op=2 reply, htype=1, hlen=6, hops=0
    pkt = struct.pack("!BBBBIHH", 2, 1, 6, 0, xid, 0, 0x8000)
    pkt += struct.pack("!IIH", 0, 0, 0) + struct.pack("!H", 0)
    pkt += bytes.fromhex(cli_mac.replace(":", "")) + b"\x00" * 10
    pkt += b"\x00" * 64  # sname
    pkt += bootfile.encode()[:128].ljust(128, b"\x00")  # file
    pkt += b"\x63\x82\x53\x63"  # magic
    srv = socket.inet_aton(SERVER_IP)
    pkt += struct.pack("BBB", 53, 1, msgtype)          # msg type: 2 offer / 5 ack
    pkt += struct.pack("BBB", 54, 4, 0) + srv          # server id
    pkt += struct.pack("BBB", 51, 4, 0) + struct.pack("!I", LEASE)
    pkt += struct.pack("BBB", 1, 4, 0) + socket.inet_aton(MASK)
    pkt += struct.pack("BBB", 66, 4, 0) + srv          # next-server
    bf = bootfile.encode()
    pkt += bytes([67, len(bf)]) + bf                   # bootfile name
    pkt += b"\xff"
    # yiaddr must be placed at offset 16
    pkt = pkt[:16] + socket.inet_aton(yiaddr) + pkt[20:]
    # siaddr (next server) at offset 20
    pkt = pkt[:20] + srv + pkt[24:]
    return pkt

def serve():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        s.bind(("0.0.0.0", 67))
    except OSError as e:
        print(f"[DHCP] cannot bind UDP/67 (need Admin?): {e}")
        return
    print(f"[DHCP] listening on UDP/67, server={SERVER_IP}, pool={POOL_START}-{POOL_END}")
    while True:
        data, addr = s.recvfrom(1024)
        if len(data) < 240: continue
        xid = struct.unpack("!I", data[4:8])[0]
        mac = ":".join(f"{b:02x}" for b in data[28:34])
        opts = parse_opts(data[236:])
        mtype = opts.get(53, b"\x00")[0] if 53 in opts else 0
        arch = int.from_bytes(opts.get(93, b"\x00\x00"), "big") if 93 in opts else 0
        bootfile = FILE_UEFI if arch in (7, 9) else FILE_BIOS
        if mtype == 1:  # discover
            ip = next_ip(mac)
            if not ip:
                print(f"[DHCP] pool exhausted for {mac}")
                continue
            s.sendto(build_reply(xid, ip, 2, bootfile, mac), ("<broadcast>", 68))
            print(f"[DHCP] OFFER {ip} -> {mac} arch={arch} file={bootfile}")
        elif mtype == 3:  # request
            rip = socket.inet_ntoa(opts.get(50, b"\x00\x00\x00\x00")) if 50 in opts else None
            ip = next_ip(mac)
            if rip and rip != ip:
                ip = rip
                with lock:
                    leases[mac] = (ip, time.time() + LEASE)
            s.sendto(build_reply(xid, ip, 5, bootfile, mac), ("<broadcast>", 68))
            print(f"[DHCP] ACK {ip} -> {mac} file={bootfile}")

if __name__ == "__main__":
    serve()
