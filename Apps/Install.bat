@echo off
REM Shop apps offline installer - runs from \\SERVER\Station\Apps on client PCs.
REM Drop offline installers next to this file, then run as admin on the client.
REM Naming: put each setup in its own folder or prefix with app key below.
set LOG=%~dp0install.log
echo [%date% %time%] START > "%LOG%"

REM --- Runtimes (install first) ---
if exist "%~dp0VCpp\*.exe" for %%f in ("%~dp0VCpp\*.exe") do "%%f" /install /quiet /norestart >> "%LOG%" 2>&1
if exist "%~dp0DirectX\DXSETUP.exe" "%~dp0DirectX\DXSETUP.exe" /silent >> "%LOG%" 2>&1

REM --- Browsers ---
if exist "%~dp0Chrome\*.msi" for %%f in ("%~dp0Chrome\*.msi") do msiexec /i "%%f" /qn /norestart >> "%LOG%" 2>&1

REM --- Media ---
if exist "%~dp0VLC\*.exe" for %%f in ("%~dp0VLC\*.exe") do "%%f" /S >> "%LOG%" 2>&1
if exist "%~dp0KLite\*.exe" for %%f in ("%~dp0KLite\*.exe") do "%%f" /verysilent /norestart >> "%LOG%" 2>&1

REM --- Archivers / tools ---
if exist "%~dp07zip\*.msi" for %%f in ("%~dp07zip\*.msi") do msiexec /i "%%f" /qn /norestart >> "%LOG%" 2>&1
if exist "%~dp0WinRAR\*.exe" for %%f in ("%~dp0WinRAR\*.exe") do "%%f" /S >> "%LOG%" 2>&1

REM --- Remote support ---
if exist "%~dp0AnyDesk\*.exe" for %%f in ("%~dp0AnyDesk\*.exe") do "%%f" --install --start-with-win --create-shortcuts >> "%LOG%" 2>&1

echo [%date% %time%] DONE >> "%LOG%"
echo Done. Check install.log for errors.
pause
