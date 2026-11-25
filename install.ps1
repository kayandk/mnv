# mnv cho Windows (lệnh máy khách, như kubectl).
#   Cài / cập nhật:  irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 | iex
#   Gỡ:              $env:MNV_UNINSTALL=1; irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 | iex
#   Bản cụ thể:      $env:MNV_VERSION="v0.5.0"; irm ... | iex
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repo = if ($env:MNV_REPO) { $env:MNV_REPO } else { "kayandk/mnv" }
$dir = Join-Path $env:LOCALAPPDATA "mnv"
$exe = Join-Path $dir "mnv.exe"

function Remove-FromPath($d) {
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  $new = ($p -split ";" | Where-Object { $_ -and $_.Trim() -ne "" -and $_ -ne $d }) -join ";"
  [Environment]::SetEnvironmentVariable("Path", $new, "User")
}

if ($env:MNV_UNINSTALL) {
  Remove-Item -Force -ErrorAction SilentlyContinue $exe, "$exe.old"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $HOME ".mnv")
  Remove-FromPath $dir
  Write-Host "Đã gỡ mnv (chương trình, cấu hình ~/.mnv, PATH)."
  return
}

$rawArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = if ($rawArch -eq "ARM64") { "arm64" } else { "amd64" }
$name = "mnv-windows-$arch.exe"
$base = if ($env:MNV_VERSION) { "https://github.com/$repo/releases/download/$($env:MNV_VERSION)" } else { "https://github.com/$repo/releases/latest/download" }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$tmp = Join-Path $dir "mnv.exe.download"
Write-Host "Tải $name từ $base ..."
Invoke-WebRequest -UseBasicParsing "$base/$name" -OutFile $tmp
$sums = (Invoke-WebRequest -UseBasicParsing "$base/checksums.txt").Content
$want = ($sums -split "`n" | Where-Object { $_ -match "\s\*?$([regex]::Escape($name))\r?$" } | ForEach-Object { ($_ -split "\s+")[0] }) | Select-Object -First 1
$got = (Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLower()
if (-not $want -or $want.ToLower() -ne $got) { Remove-Item -Force $tmp; throw "Sai checksum $name — thử lại." }
if (Test-Path $exe) {
  try { Remove-Item -Force "$exe.old" -ErrorAction SilentlyContinue; Move-Item -Force $exe "$exe.old" } catch {}
}
Move-Item -Force $tmp $exe
$parts = @(([Environment]::GetEnvironmentVariable("Path", "User") -split ";") | Where-Object { $_ -and $_.Trim() -ne "" })
if (-not ($parts -contains $dir)) {
  [Environment]::SetEnvironmentVariable("Path", (($parts + $dir) -join ";"), "User")
  Write-Host "Đã thêm $dir vào PATH người dùng."
}
if (-not (($env:Path -split ";") -contains $dir)) { $env:Path = "$dir;$env:Path" }
& $exe version
Write-Host "Tiếp theo: mnv login https://<domain panel>"
