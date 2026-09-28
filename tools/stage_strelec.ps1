#Requires -RunAsAdministrator
# Stage Strelec boot files for PXE (wimboot needs flat files over HTTP).
$iso = 'D:\Station\ISO\WinPE10_8_Sergei_Strelec_x86_x64_2022.12.07_English.iso'
$dst = 'D:\Station\netboot\strelec'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
$disk = Mount-DiskImage -ImagePath $iso -PassThru -ErrorAction Stop
$drv = ((($disk | Get-Volume).DriveLetter) + ':\')
foreach ($f in @('SSTR\boot.sdi', 'SSTR\BCD', 'SSTR\strelec10x64Eng.wim', 'SSTR\strelec10Eng.wim')) {
  Copy-Item ($drv + $f) $dst -Force -ErrorAction Stop
  Write-Host "OK $f"
}
Dismount-DiskImage -ImagePath $iso -ErrorAction Stop | Out-Null
Get-Item "$dst\*" | Select-Object Name,@{N='MB';E={[math]::Round($_.Length/1MB,1)}}
Write-Host 'Strelec staged.'
