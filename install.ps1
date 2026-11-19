# mnv cho Windows (lệnh máy khách, như kubectl).
#   Cài / cập nhật:  irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 | iex
#   Gỡ:              $env:MNV_UNINSTALL=1; irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 | iex
#   Bản cụ thể:      $env:MNV_VERSION="v0.5.0"; irm ... | iex
$ErrorActionPreference = "Stop"
$repo = if ($env:MNV_REPO) { $env:MNV_REPO } else { "kayandk/mnv" }
$dir = Join-Path $env:LOCALAPPDATA "mnv"
$exe = Join-Path $dir "mnv.exe"

function Remove-FromPath($d) {
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  $new = ($p -split ";" | Where-Object { $_ -and $_ -ne $d }) -join ";"
  [Environment]::SetEnvironmentVariable("Path", $new, "User")
}

if ($env:MNV_UNINSTALL) {
  Remove-Item -Force -ErrorAction SilentlyContinue $exe
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $HOME ".mnv")
  Remove-FromPath $dir
  Write-Host "Đã gỡ mnv (chương trình, cấu hình ~/.mnv, PATH)."
  return
}

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$name = "mnv-windows-$arch.exe"
$base = if ($env:MNV_VERSION) { "https://github.com/$repo/releases/download/$($env:MNV_VERSION)" } else { "https://github.com/$repo/releases/latest/download" }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$tmp = Join-Path $dir "mnv.exe.download"
Write-Host "Tải $name từ $base ..."
Invoke-WebRequest -UseBasicParsing "$base/$name" -OutFile $tmp
$sums = (Invoke-WebRequest -UseBasicParsing "$base/checksums.txt").Content
$want = ($sums -split "`n" | Where-Object { $_ -match "\s\*?$([regex]::Escape($name))$" } | ForEach-Object { ($_ -split "\s+")[0] }) | Select-Object -First 1
$got = (Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLower()
if (-not $want -or $want.ToLower() -ne $got) { Remove-Item $tmp; throw "Sai checksum $name — thử lại." }
Move-Item -Force $tmp $exe
$p = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not ($p -split ";" | Where-Object { $_ -eq $dir })) {
  [Environment]::SetEnvironmentVariable("Path", "$p;$dir", "User")
  Write-Host "Đã thêm $dir vào PATH — mở cửa sổ PowerShell mới để dùng."
}
& $exe version
Write-Host "Tiếp theo: mnv login https://<domain panel>"
