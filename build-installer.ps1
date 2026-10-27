#Requires -Version 5.1
# Build the Angels95 NSIS installer from an already-assembled `System/` folder.
#
# Layout contract (this script lives in the `setup/` submodule of the main repo):
#   <repo root>/System/   <- the CI-assembled release (exes, DLLs, Data/*.oz*)
#   <repo root>/setup/    <- this submodule
#
# The installer is written next to System/ (the repo root) by default, so CI can
# attach it to a release. All paths must be SPACE-FREE (the Angels95 repo
# forbids spaces/parentheses in paths).

param(
  [string]$Version = "",
  [string]$OutDir = ""
)

$ErrorActionPreference = 'Stop'

$setupRoot = $PSScriptRoot
$repoRoot  = (Resolve-Path (Join-Path $setupRoot '..')).Path
$srcDir    = Join-Path $repoRoot 'System'

if (-not $Version) {
  $Version = if ($env:BUILD_VERSION) { $env:BUILD_VERSION } else { 'dev' }
}
if (-not $OutDir) {
  $OutDir = Join-Path $repoRoot 'release'
}
if (-not (Test-Path $OutDir -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$OutDir = (Resolve-Path $OutDir).Path

if (-not (Test-Path $srcDir -PathType Container)) {
  throw "System/ folder not found at $srcDir — run the main repo's build/assemble step first."
}

# Locate makensis: PATH first, then the two common install locations
# (chocolatey's nsis package installs to Program Files (x86) and drops a shim
# in the chocolatey bin dir).
$makensis = $null
$cmd = Get-Command makensis -ErrorAction SilentlyContinue
if ($cmd) { $makensis = $cmd.Source }
if (-not $makensis) {
  foreach ($c in @(
    "$env:ProgramFiles(x86)\NSIS\makensis.exe",
    "$env:ProgramFiles\NSIS\makensis.exe",
    "$env:ProgramData\chocolatey\bin\makensis.exe"
  )) {
    if (Test-Path $c) { $makensis = $c; break }
  }
}
if (-not $makensis) {
  throw "makensis not found. Install NSIS (e.g. `choco install nsis -y`) or put makensis.exe on PATH."
}

Write-Host "==> Building Angels95-Setup-$Version.exe"
Write-Host "    makensis : $makensis"
Write-Host "    src      : $srcDir"
Write-Host "    out      : $OutDir"

# Compile from the setup/ dir so the .nsi's relative MUI_ICON/MUI_PAGE_LICENSE
# resolve; SRC_DIR/OUT_DIR are passed as absolute defines.
Push-Location $setupRoot
try {
  & $makensis "-DVERSION=$Version" "-DSRC_DIR=$srcDir" "-DOUT_DIR=$OutDir" "installer.nsi"
  if ($LASTEXITCODE -ne 0) { throw "makensis exited with code $LASTEXITCODE" }
}
finally {
  Pop-Location
}

$outFile = Join-Path $OutDir "Angels95-Setup-$Version.exe"
if (-not (Test-Path $outFile)) {
  throw "Expected output not found: $outFile"
}
Write-Host "==> Wrote $outFile"
Get-Item $outFile | Select-Object FullName, Length
