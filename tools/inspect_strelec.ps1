#Requires -RunAsAdministrator
# Inspect Strelec ISO boot layout: find wim/sdi/BCD, then dismount.
$iso = 'D:\Station\ISO\WinPE10_8_Sergei_Strelec_x86_x64_2022.12.07_English.iso'
$disk = Mount-DiskImage -ImagePath $iso -PassThru -ErrorAction Stop
$drv = ((($disk | Get-Volume).DriveLetter) + ':')
Write-Host "Mounted at $drv"
Get-ChildItem ($drv + '\') -Recurse -Include *.wim,*.sdi,BCD -ErrorAction SilentlyContinue |
  Select-Object FullName,@{N='MB';E={[math]::Round($_.Length/1MB,1)}}
Dismount-DiskImage -ImagePath $iso -ErrorAction Stop | Out-Null
Write-Host 'Dismounted.'
