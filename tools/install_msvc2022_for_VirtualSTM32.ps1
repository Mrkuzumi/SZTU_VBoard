# VirtualSTM32 - Install Visual Studio 2022 Build Tools (MSVC)
# Run from an elevated PowerShell, or this script will request elevation.

$ErrorActionPreference = "Stop"

function Test-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "Administrator privileges are required. Requesting elevation..." -ForegroundColor Yellow
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`""
    )
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit 0
}

Write-Host "=== VirtualSTM32 MSVC 2022 Bootstrap ===" -ForegroundColor Cyan

$TempDir = Join-Path $env:TEMP "VirtualSTM32_MSVC"
$Bootstrapper = Join-Path $TempDir "vs_BuildTools.exe"
$InstallPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

Write-Host "[1/3] Downloading Visual Studio 2022 Build Tools bootstrapper..."
Invoke-WebRequest `
    -Uri "https://aka.ms/vs/17/release/vs_BuildTools.exe" `
    -OutFile $Bootstrapper `
    -UseBasicParsing

Write-Host "[2/3] Installing Desktop development with C++..."
Write-Host "      Workload: Microsoft.VisualStudio.Workload.VCTools"
Write-Host "      Install path: $InstallPath"
Write-Host "      This may open the Visual Studio Installer UI/progress window."

$arguments = @(
    "--installPath", "`"$InstallPath`"",
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--includeRecommended",
    "--passive",
    "--wait",
    "--norestart"
)

$proc = Start-Process -FilePath $Bootstrapper -ArgumentList $arguments -Wait -PassThru

# 0 = success, 3010 = success but reboot required
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw "Visual Studio Build Tools installer failed with exit code $($proc.ExitCode)."
}

Write-Host "[3/3] Verifying installation..."

$vswhereCandidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "$InstallPath\Common7\Tools\vswhere.exe"
)

$vswhere = $vswhereCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($vswhere) {
    Write-Host "[ OK ] vswhere.exe found: $vswhere" -ForegroundColor Green
    & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
} else {
    Write-Host "[WARN] vswhere.exe was not found in the usual locations." -ForegroundColor Yellow
}

$clCandidates = @()
if (Test-Path $InstallPath) {
    $clCandidates = Get-ChildItem `
        -Path (Join-Path $InstallPath "VC\Tools\MSVC") `
        -Filter cl.exe `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "Hostx64\\x64\\cl\.exe$" }
}

if ($clCandidates.Count -gt 0) {
    Write-Host "[ OK ] MSVC x64 compiler found:" -ForegroundColor Green
    $clCandidates | Select-Object -First 1 | ForEach-Object { Write-Host "      $($_.FullName)" }
} else {
    Write-Host "[WARN] MSVC x64 compiler not found yet." -ForegroundColor Yellow
    Write-Host "       If the installer requested a reboot, reboot Windows and run tools\doctor.ps1 again."
}

Write-Host ""
if ($proc.ExitCode -eq 3010) {
    Write-Host "Installation completed. Windows restart is required." -ForegroundColor Yellow
} else {
    Write-Host "Installation completed." -ForegroundColor Green
}

Write-Host ""
Write-Host "Next:"
Write-Host "  cd <your VirtualSTM32 project>"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tools\doctor.ps1"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tools\build_windows.ps1"
