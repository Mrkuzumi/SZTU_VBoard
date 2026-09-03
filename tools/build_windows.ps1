$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root "build"
Write-Host "[1/2] Configure (Visual Studio x64)..."
cmake -S $Root -B $Build -A x64
Write-Host "[2/2] Build Release..."
cmake --build $Build --config Release --parallel
$Exe = Join-Path $Build "Release\VirtualSTM32.exe"
if (!(Test-Path $Exe)) { throw "Build finished but $Exe was not found" }
Write-Host "OK: $Exe" -ForegroundColor Green
