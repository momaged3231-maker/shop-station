@echo off
REM Station client setup - run ONCE on fresh Windows (same LAN as server).
REM Double-click and approve UAC. Server IP editable below.
setlocal
set SERVER=10.0.0.39
set SHARE=Station
set USER=tech
set PASS=CHANGE_ME
set LOG=%TEMP%\Station-Setup.log
echo [%date% %time%] START > "%LOG%"

net session >nul 2>&1
if %errorlevel% neq 0 (
echo Requesting admin rights...
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b
)

echo [1/4] Mapping server share...
net use S: \\%SERVER%\%SHARE% /user:%USER% %PASS% /persistent:no >> "%LOG%" 2>&1
if %errorlevel% neq 0 (
echo [X] Cannot reach \\%SERVER%\%SHARE% - check cable and server.
pause
exit /b 1
)

echo [2/4] Drivers (SDIO auto - takes a while)...
S:\Drivers\SDIO\SDIO_x64_R887.exe /script:S:\Drivers\SDIO\auto-install.txt >> "%LOG%" 2>&1

echo [3/4] Programs...
call S:\Apps\Install.bat auto >> "%LOG%" 2>&1

echo [4/4] Tweaks...
tzutil /s "Egypt Standard Time" >> "%LOG%" 2>&1
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >> "%LOG%" 2>&1
powercfg -change -standby-timeout-ac 0 >> "%LOG%" 2>&1
powercfg -change -standby-timeout-dc 30 >> "%LOG%" 2>&1

net use S: /delete /y >nul 2>&1
echo [%date% %time%] DONE >> "%LOG%"
echo.
echo Done. Log: %LOG%
echo Office 2019 (if needed): run it manually from the Apps share.
echo Reboot recommended.
pause
