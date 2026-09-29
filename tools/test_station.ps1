# Station self-test - read-only, no admin needed. Exit 1 on any FAIL.
$fail = 0
function chk($name, $cond) {
  if ($cond) { Write-Host "PASS $name" } else { Write-Host "FAIL $name"; $script:fail++ }
}
# 1. Config consistency
$cfg = @{}
Get-Content 'D:\Station\pxe_config.ini' | Where-Object { $_ -match '=' } | ForEach-Object {
  $k, $v = $_ -split '=', 2; $cfg[$k.Trim()] = $v.Trim()
}
chk 'config has server_ip' ($cfg['server_ip'] -match '^\d+\.\d+\.\d+\.\d+$')
# 2. Boot binaries
foreach ($f in @('undionly.kpxe','ipxe.efi','snponly.efi','wimboot')) {
  chk "ipxe/$f" (Test-Path "D:\Station\netboot\ipxe\$f")
}
# 3. Every http path in menu.ipxe maps to a real file
$root = 'D:\Station\netboot'
foreach ($m in (Select-String -Path "$root\menu.ipxe" -Pattern 'http://\$\{next-server\}:8080/(\S+)' -AllMatches).Matches) {
  $p = Join-Path $root ($m.Groups[1].Value -replace '/', '\')
  chk "menu -> $($m.Groups[1].Value)" (Test-Path $p)
}
# 4. WinPE + Strelec staged
chk 'boot-pe.wim>400MB' ((Get-Item 'D:\Station\netboot\winpe\boot-pe.wim' -ErrorAction SilentlyContinue).Length -gt 400MB)
chk 'boot.sdi' (Test-Path 'D:\Station\netboot\winpe\boot.sdi')
# 5. Every file referenced by Install.bat exists
$bat = Get-Content 'D:\Station\Apps\Install.bat' -Raw
foreach ($m in ([regex]'%~dp0([^"%]+?)"').Matches($bat)) {
  $p = Join-Path 'D:\Station\Apps' $m.Groups[1].Value
  $ok = (Test-Path $p) -or ((Get-ChildItem (Split-Path $p) -Filter (Split-Path $p -Leaf) -ErrorAction SilentlyContinue).Count -gt 0)
  chk "app -> $($m.Groups[1].Value)" $ok
}
# 6. Windows sources complete
foreach ($d in @('W11','W10','W7')) {
  chk "$d setup.exe" (Test-Path "D:\Station\ISO\$d\sources\setup.exe")
}
# 7. Driver packs present
chk 'SDIO packs>60' ((Get-ChildItem 'D:\Station\Drivers\SDIO\drivers\*.7z' -ErrorAction SilentlyContinue).Count -gt 60)
$sdio = Test-Path 'D:\Station\Drivers\SDIO\SDIO_x64.exe'
if (-not $sdio) { $sdio = (Get-ChildItem 'D:\Station\Drivers\SDIO\SDIO*.exe' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0 }
chk 'SDIO tool' $sdio
# 8. Server code compiles
$py = 'C:\Users\Compu Mego\AppData\Local\Programs\Python\Python312\python.exe'
$pyfs = Get-ChildItem D:\Station\server\*.py | ForEach-Object { $_.FullName }
& $py -m py_compile $pyfs 2>$null
chk 'py compile' ($LASTEXITCODE -eq 0)
Write-Host "RESULT fails=$fail"
exit $fail
