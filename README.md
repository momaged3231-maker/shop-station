# Shop Station - Private Network Deployment System

Own PXE deployment station for a PC repair shop. Boots client PCs over an
isolated 1Gbps LAN and installs Windows + drivers + apps. No third-party
deployment suites, no licenses, works fully offline.

## Layout

- `server/` - DHCP + TFTP + HTTP services (Python stdlib only, run as admin)
- `netboot/menu.ipxe` - iPXE boot menu (English - iPXE font has no Arabic)
- `pxe_config.example.ini` - copy to `pxe_config.ini`, set your server IP
- `tools/` - admin scripts: prerequisites, ISO verify/extract, WinPE build
- `PLAN.md` - full build/operate plan

## Not in this repo (large / licensed, fetch separately)

- Windows ISOs (Microsoft), WinPE (built with free Windows ADK)
- iPXE binaries: http://boot.ipxe.org/undionly.kpxe ,
  http://boot.ipxe.org/x86_64-efi/ipxe.efi ,
  http://boot.ipxe.org/x86_64-efi/snponly.efi
- wimboot: https://github.com/ipxe/wimboot/releases/latest/download/wimboot
- SDIO driver packs: https://www.snappy-driver-installer.org/

## Quick start

1. Isolated switch, server NIC `192.168.10.1/24` (never connect to router).
2. Run `tools/install_prereqs.bat` as admin (Python + firewall + SMB share).
3. Install Windows ADK + WinPE addon.
4. Extract Windows ISOs, build WinPE (`tools/extract_isos.ps1`,
   `tools/build_winpe.ps1`).
5. Set your reader password: replace `CHANGE_ME` in `tools/build_winpe.ps1`.
6. As admin: `python server/run_all.py`, PXE-boot clients.
