#Requires -RunAsAdministrator
# Verify all ISOs in D:\Station\ISO - mount, inspect, dismount, report.
$isoDir = 'D:\Station\ISO'
$report = 'D:\Station\logs\iso_report.csv'
"FileName,SizeGB,BootWim,InstallWim,InstallEsd,EfiBoot,Label" | Out-File $report -Encoding ascii
foreach ($iso in Get-ChildItem $isoDir -Filter *.iso) {
  $size = [math]::Round($iso.Length / 1GB, 2)
  $row = @{ f = $iso.Name; s = $size; boot = 'NO'; wim = 'NO'; esd = 'NO'; efi = 'NO'; lbl = '' }
  try {
    $disk = Mount-DiskImage -ImagePath $iso.FullName -PassThru -ErrorAction Stop
    $vol = ($disk | Get-Volume)
    $row.lbl = $vol.FileSystemLabel
    $d = ($vol.DriveLetter + ':')
    if (Test-Path "$d\sources\boot.wim") { $row.boot = 'YES' }
    if (Test-Path "$d\sources\install.wim") { $row.wim = 'YES' }
    if (Test-Path "$d\sources\install.esd") { $row.esd = 'YES' }
    if (Test-Path "$d\efi\boot\bootx64.efi") { $row.efi = 'YES' }
    Dismount-DiskImage -ImagePath $iso.FullName -ErrorAction Stop | Out-Null
  } catch {
    $row.lbl = 'MOUNT-FAILED: ' + $_.Exception.Message
  }
  "$($row.f),$($row.s),$($row.boot),$($row.wim),$($row.esd),$($row.efi),$($row.lbl)" | Out-File $report -Append -Encoding ascii
  Write-Host "$($row.f) boot=$($row.boot) wim=$($row.wim) esd=$($row.esd) efi=$($row.efi)"
}
Write-Host "Report: $report"
