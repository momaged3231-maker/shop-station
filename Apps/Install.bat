@echo off
REM Shop apps silent installer - matches the actual offline collection.
REM Run as admin on the client PC from \\SERVER\Station\Apps (or USB copy).
REM Office 2019 stays MANUAL (Arabic/English choice + activation per customer).
setlocal
set LOG=%~dp0install.log
echo [%date% %time%] START > "%LOG%"

echo === Runtime === >> "%LOG%"
"%~dp0microsoft-visual-cplusplus-redistributable-14-40-33810-0.exe" /install /quiet /norestart >> "%LOG%" 2>&1

echo === Browsers === >> "%LOG%"
msiexec /i "%~dp0microsoft-edge-129-0-2792-52.msi" /qn /norestart >> "%LOG%" 2>&1
"%~dp0ChromeSetup.exe" /silent /install >> "%LOG%" 2>&1

echo === Media === >> "%LOG%"
"%~dp0vlc-media-player-3-0-21.exe" /S >> "%LOG%" 2>&1
"%~dp0K-Lite_Codec_Pack_1935_Full.exe" /verysilent /norestart >> "%LOG%" 2>&1

echo === Archiver === >> "%LOG%"
"%~dp0winrar-x64-701.exe" /S >> "%LOG%" 2>&1

echo === Reader + Java === >> "%LOG%"
"%~dp0adobe-acrobat-reader-dc-2024-003-20112.exe" /sAll /rs /msi EULA_ACCEPT=YES >> "%LOG%" 2>&1
"%~dp0java-2-runtime-environment-8-update-421.exe" /s >> "%LOG%" 2>&1

echo === Calls + Remote === >> "%LOG%"
"%~dp0ZoomInstallerFull.exe" /silent >> "%LOG%" 2>&1
"%~dp0Skype-8.130.0.205.exe" /silent >> "%LOG%" 2>&1
"%~dp0TeamViewer_Setup.exe" /S >> "%LOG%" 2>&1
"%~dp0UltraViewer_setup_6.2_en.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART >> "%LOG%" 2>&1
"%~dp0new USB Disk Security 5.1.0.15\setup.exe" /SILENT /SUPPRESSMSGBOXES >> "%LOG%" 2>&1

echo === Office 2019: MANUAL === >> "%LOG%"
echo Open "FaresCD.Com.Offic,Diam,Aio.All2019\2019" and run Office ProPlus Arabic.exe or English.exe.

echo [%date% %time%] DONE >> "%LOG%"
echo Done. See install.log for details.
if /i "%~1"=="auto" exit /b 0
pause
