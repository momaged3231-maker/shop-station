#Requires -RunAsAdministrator
# Build shop WinPE (network + PowerShell) and stage it for PXE boot.
$ErrorActionPreference = 'Stop'
$kit = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots').KitsRoot10
$peAdd = Join-Path $kit 'Assessment and Deployment Kit\Windows Preinstallation Environment'
$peRoot = Join-Path $peAdd 'amd64'
if (!(Test-Path "$peRoot\en-us\winpe.wim")) { Write-Host 'MISSING WinPE addon - run tools\adkwinpesetup.exe as admin first.'; exit 1 }
$copype = Join-Path $peAdd 'copype.cmd'
if (!(Test-Path $copype)) { $copype = Join-Path $kit 'Assessment and Deployment Kit\Deployment Tools\copype.cmd' }

# Limited reader account for WinPE clients (isolated deploy LAN only)
if (!(Get-LocalUser tech -ErrorAction SilentlyContinue)) {
  New-LocalUser tech -Password (ConvertTo-SecureString 'CHANGE_ME' -AsPlainText -Force) -PasswordNeverExpires | Out-Null
  Write-Host 'User tech created.'
}
icacls 'D:\Station' /grant 'tech:(OI)(CI)R' | Out-Null

$build = 'D:\Station\build\pe'
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
$env:WinPERoot = $peAdd
$env:OSCDImgRoot = Join-Path $kit 'Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg'
& "$copype" amd64 $build | Out-Null
$mount = "$build\mount"
$wim = "$build\media\sources\boot.wim"
Mount-WindowsImage -ImagePath $wim -Index 1 -Path $mount | Out-Null
$oc = "$peRoot\WinPE_OCs"
foreach ($p in @('WinPE-WMI','WinPE-NetFX','WinPE-Scripting','WinPE-PowerShell','WinPE-StorageWMI')) {
  $cab = "$oc\$p.cab"
  $lang = "$oc\en-us\${p}_en-us.cab"
  if (Test-Path $cab) {
    Add-WindowsPackage -Path $mount -PackagePath $cab | Out-Null
    if (Test-Path $lang) { Add-WindowsPackage -Path $mount -PackagePath $lang | Out-Null }
    Write-Host "ADD $p"
  } else { Write-Host "SKIP missing $p" }
}
$srvIp = ((Select-String -Path 'D:\Station\pxe_config.ini' -Pattern '^\s*server_ip\s*=\s*(\S+)').Matches[0].Groups[1].Value)
$startnet = @"
wpeinit
echo Station WinPE - connecting to server...
net use S: \\$srvIp\Station /user:tech CHANGE_ME /persistent:no
echo.
echo Setup folders: S:\ISO\W11  S:\ISO\W10  S:\ISO\W7
echo Drivers: S:\Drivers   Apps: S:\Apps
echo Run S:\ISO\W11\sources\setup.exe to install Windows.
cmd
"@
$startnet | Out-File "$mount\Windows\System32\startnet.cmd" -Encoding ascii
$ok = $false
for ($i = 1; $i -le 5 -and -not $ok; $i++) {
  try {
    Dismount-WindowsImage -Path $mount -Save -ErrorAction Stop | Out-Null
    $ok = $true
  } catch {
    Write-Host "Dismount retry $i/5 ..."
    Start-Sleep 10
  }
}
if (-not $ok) { Write-Host 'Dismount FAILED - close any Explorer window on D:\Station\build and rerun.'; exit 1 }
New-Item -ItemType Directory -Force -Path 'D:\Station\netboot\winpe' | Out-Null
Copy-Item $wim 'D:\Station\netboot\winpe\boot-pe.wim' -Force
Copy-Item "$build\media\boot\boot.sdi" 'D:\Station\netboot\winpe\boot.sdi' -Force
Get-Item 'D:\Station\netboot\winpe\*' | Select-Object Name,@{N='MB';E={[math]::Round($_.Length/1MB,1)}}
Write-Host 'WinPE build done.'
