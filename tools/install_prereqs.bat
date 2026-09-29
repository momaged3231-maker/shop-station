@echo off
REM Station prerequisites - MUST run as Administrator (right-click, Run as administrator)
net session >nul 2>&1
if %errorlevel% neq 0 (
echo [X] Not admin. Right-click this file - Run as administrator.
pause
exit /b 1
)
echo [*] 1/4 Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
) else (
echo Python already installed.
)
python --version
echo [*] 2/4 Firewall rules...
netsh advfirewall firewall delete rule name="Station-DHCP" >nul 2>&1
netsh advfirewall firewall delete rule name="Station-TFTP" >nul 2>&1
netsh advfirewall firewall delete rule name="Station-HTTP" >nul 2>&1
netsh advfirewall firewall delete rule name="Station-SMB" >nul 2>&1
netsh advfirewall firewall add rule name="Station-DHCP" dir=in action=allow protocol=UDP localport=67
netsh advfirewall firewall add rule name="Station-TFTP" dir=in action=allow protocol=UDP localport=69
netsh advfirewall firewall add rule name="Station-HTTP" dir=in action=allow protocol=TCP localport=8080
netsh advfirewall firewall add rule name="Station-SMB" dir=in action=allow protocol=TCP localport=445
netsh advfirewall firewall delete rule name="Station-PXEProxy" >nul 2>&1
netsh advfirewall firewall add rule name="Station-PXEProxy" dir=in action=allow protocol=UDP localport=4011
echo [*] 3/4 SMB share...
net share Station=D:\Station /GRANT:Everyone,READ >nul 2>&1
net share Station | findstr Station
echo [*] 4/4 Network...
ipconfig | findstr IPv4
echo.
echo [!] Deploy NIC must be 192.168.10.1 / 255.255.255.0 isolated from router.
echo [!] Single NIC? Add a USB-Ethernet adapter for deploy LAN.
echo [OK] Done. Next: run tools\adksetup.exe + adkwinpesetup.exe as admin (ADK 10.1.26100.9457).
pause
