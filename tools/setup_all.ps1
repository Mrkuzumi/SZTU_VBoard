$ErrorActionPreference = "Stop"
Write-Host "=== VirtualSTM32F103C8T6 first-time setup ===" -ForegroundColor Cyan
Write-Host ""
& (Join-Path $PSScriptRoot "doctor.ps1")
Write-Host ""
& (Join-Path $PSScriptRoot "setup_renode.ps1")
Write-Host ""
& (Join-Path $PSScriptRoot "build_windows.ps1")
Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host "Next: configure CubeIDE makefile.targets or Keil After Build/Rebuild as documented in README.md."
