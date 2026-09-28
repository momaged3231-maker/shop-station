#Requires -RunAsAdministrator
# Build shop WinPE (network + PowerShell) and stage it for PXE boot.
$ErrorActionPreference = 'Stop'
$kit = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots').KitsRoot10
$copype = Join-Path $kit 'Assessment and Deployment Kit\Deployment Tools\copype.cmd'
$peRoot = Join-Path $kit 'Assessment and Deployment Kit\Windows Preinstallation Environment\amd64'
if (!(Test-Path "$peRoot\en-us\winpe.wim")) { Write-Host 'MISSING WinPE addon - run tools\adkwinpesetup.exe as admin first.'; exit 1 }

# Limited reader account for WinPE clients (isolated deploy LAN only)
if (!(Get-LocalUser tech -ErrorAction SilentlyContinue)) {
  New-LocalUser tech -Password (ConvertTo-SecureString 'CHANGE_ME' -AsPlainText -Force) -PasswordNeverExpires | Out-Null
  Write-Host 'User tech created.'
}
icacls 'D:\Station' /grant 'tech:(OI)(CI)R' | Out-Null
net share Station /GRANT:tech,READ | Out-Null

$build = 'D:\Station\build\pe'
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
cmd /c "`"$copype`" amd64 `"$build`"" | Out-Null
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
$startnet = @'
wpeinit
echo Station WinPE - connecting to server...
net use S: \\192.168.10.1\Station /user:tech CHANGE_ME /persistent:no
echo.
echo Setup folders: S:\ISO\W11  S:\ISO\W10  S:\ISO\W7
echo Drivers: S:\Drivers   Apps: S:\Apps
echo Run S:\ISO\W11\sources\setup.exe to install Windows.
cmd
'@
$startnet | Out-File "$mount\Windows\System32\startnet.cmd" -Encoding ascii
Dismount-WindowsImage -Path $mount -Save | Out-Null
New-Item -ItemType Directory -Force -Path 'D:\Station\netboot\winpe' | Out-Null
Copy-Item $wim 'D:\Station\netboot\winpe\boot-pe.wim' -Force
Copy-Item "$build\media\boot\boot.sdi" 'D:\Station\netboot\winpe\boot.sdi' -Force
Get-Item 'D:\Station\netboot\winpe\*' | Select-Object Name,@{N='MB';E={[math]::Round($_.Length/1MB,1)}}
Write-Host 'WinPE build done.'
