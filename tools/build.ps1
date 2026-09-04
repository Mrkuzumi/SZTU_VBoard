param(
    [ValidateSet("Release","Debug")]
    [string]$Config = "Release",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$BuildRoot = Join-Path $env:LOCALAPPDATA "VirtualSTM32\build\VirtualSTM32F103C8T6"

$cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue

if(-not $cmake) {
    throw @"
CMake was not found.

This script is only for developers modifying VirtualSTM32 itself.
Normal users do NOT need CMake or Visual Studio; use a GitHub Release instead.
"@
}

if($Clean -and (Test-Path $BuildRoot)) {
    Remove-Item $BuildRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null

Write-Host "=== Configure ===" -ForegroundColor Cyan
Write-Host "Source: $ProjectRoot"
Write-Host "Build : $BuildRoot"

& cmake.exe `
    -S $ProjectRoot `
    -B $BuildRoot `
    -G "Visual Studio 17 2022" `
    -A x64

if($LASTEXITCODE -ne 0) {
    throw @"
CMake configure failed.

Developer prerequisite:
  Visual Studio 2022 / Build Tools
  workload: Desktop development with C++

Normal users should use the prebuilt Release and do not need this toolchain.
"@
}

Write-Host ""
Write-Host "=== Build $Config ===" -ForegroundColor Cyan

& cmake.exe `
    --build $BuildRoot `
    --config $Config

if($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE."
}

$Exe = Join-Path $BuildRoot "$Config\VirtualSTM32.exe"

if(!(Test-Path $Exe)) {
    throw "Build succeeded but VirtualSTM32.exe was not found: $Exe"
}

Write-Host ""
Write-Host "[ OK ] Build complete:" -ForegroundColor Green
Write-Host "       $Exe"
Write-Host ""
Write-Host 'Run firmware with:'
Write-Host '  .\tools\run.ps1 "D:\path\to\firmware.elf"'
