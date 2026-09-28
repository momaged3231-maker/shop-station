#Requires -RunAsAdministrator
# Extract Win11 + Win10 + Win7 ISOs to folders for network setup. ~15GB, takes a while.
$jobs = @(
  @{ iso = 'D:\Station\ISO\Win11_English_x64v1.iso'; dst = 'D:\Station\ISO\W11' },
  @{ iso = 'D:\Station\ISO\Windows_10_22H2_15in1_en-US_x64_June_2023.iso'; dst = 'D:\Station\ISO\W10' },
  @{ iso = 'D:\Station\ISO\W7.Aio.October.2016.E_M_A.iso'; dst = 'D:\Station\ISO\W7' }
)
foreach ($j in $jobs) {
  if (Test-Path "$($j.dst)\sources\setup.exe") { Write-Host "SKIP exists: $($j.dst)"; continue }
  Write-Host "Mount $($j.iso) ..."
  $disk = Mount-DiskImage -ImagePath $j.iso -PassThru -ErrorAction Stop
  $d = (($disk | Get-Volume).DriveLetter + ':\')
  Write-Host "Copy $d -> $($j.dst) ..."
  robocopy $d $j.dst /E /NFL /NDL /NJH /NJS | Out-Null
  Dismount-DiskImage -ImagePath $j.iso -ErrorAction Stop | Out-Null
  if (Test-Path "$($j.dst)\sources\setup.exe") { Write-Host "OK $($j.dst)" }
  else { Write-Host "WARN check $($j.dst)" }
}
Write-Host 'Extract done.'
