param(
    [switch]$ForceAppDownload
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$CacheRoot = Join-Path $env:LOCALAPPDATA "VirtualSTM32"
$AppCache = Join-Path $CacheRoot "app\latest"

Write-Host "=== VirtualSTM32 lightweight setup ===" -ForegroundColor Cyan

& (Join-Path $PSScriptRoot "setup_runtime.ps1")

if($LASTEXITCODE -ne 0) {
    throw "Renode runtime setup failed."
}

$LocalCandidates = @(
    (Join-Path $ProjectRoot "VirtualSTM32.exe"),
    (Join-Path $ProjectRoot "build\Release\VirtualSTM32.exe"),
    (Join-Path $CacheRoot "build\VirtualSTM32F103C8T6\Release\VirtualSTM32.exe"),
    (Join-Path $AppCache "VirtualSTM32.exe")
)

$Existing = $LocalCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if($Existing -and -not $ForceAppDownload) {
    Write-Host ""
    Write-Host "[ OK ] VirtualSTM32 executable available:" -ForegroundColor Green
    Write-Host "       $Existing"
    Write-Host ""
    Write-Host "Run:"
    Write-Host '  .\tools\run.ps1 "D:\path\to\firmware.elf"'
    exit 0
}

$git = Get-Command git.exe -ErrorAction SilentlyContinue
if(-not $git) {
    throw @"
No local VirtualSTM32.exe was found and Git is unavailable.

Normal users should download the prebuilt Windows Release.
Developers can build from source with:
  .\tools\build.ps1
"@
}

$Remote = (& git -C $ProjectRoot remote get-url origin 2>$null).Trim()

if([string]::IsNullOrWhiteSpace($Remote)) {
    throw "Could not determine the GitHub repository from git remote origin."
}

$Owner = $null
$Repo = $null

if($Remote -match '^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?$') {
    $Owner = $Matches[1]
    $Repo = $Matches[2]
}
elseif($Remote -match '^git@github\.com:([^/]+)/(.+?)(?:\.git)?$') {
    $Owner = $Matches[1]
    $Repo = $Matches[2]
}
else {
    throw "origin is not a GitHub repository URL: $Remote"
}

$Api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"

Write-Host ""
Write-Host "No local executable found; downloading latest GitHub Release..." -ForegroundColor Cyan
Write-Host "Repository: $Owner/$Repo"

$Headers = @{
    "User-Agent" = "VirtualSTM32-Setup"
    "Accept" = "application/vnd.github+json"
}

$Release = Invoke-RestMethod -Uri $Api -Headers $Headers

$Asset = $Release.assets |
    Where-Object { $_.name -eq "VirtualSTM32-windows-x64.zip" } |
    Select-Object -First 1

if(-not $Asset) {
    $Asset = $Release.assets |
        Where-Object {
            $_.name -match '(?i)VirtualSTM32.*windows.*x64.*\.zip$'
        } |
        Select-Object -First 1
}

if(-not $Asset) {
    throw @"
The latest GitHub Release does not contain VirtualSTM32-windows-x64.zip.

Maintainer:
  build the project and publish a tagged release first.

Developer build:
  .\tools\build.ps1
"@
}

$Temp = Join-Path $env:TEMP ("VirtualSTM32-App-" + [Guid]::NewGuid().ToString("N"))
$Zip = Join-Path $Temp "app.zip"

New-Item -ItemType Directory -Force -Path $Temp | Out-Null

try {
    Invoke-WebRequest `
        -Uri $Asset.browser_download_url `
        -OutFile $Zip `
        -Headers $Headers `
        -UseBasicParsing

    if(Test-Path $AppCache) {
        Remove-Item $AppCache -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $AppCache | Out-Null
    Expand-Archive -Path $Zip -DestinationPath $AppCache -Force

    $Exe = Get-ChildItem `
        -Path $AppCache `
        -Filter "VirtualSTM32.exe" `
        -File `
        -Recurse |
        Select-Object -First 1

    if(-not $Exe) {
        throw "VirtualSTM32.exe was not found in the downloaded Release."
    }

    if($Exe.Directory.FullName -ne $AppCache) {
        Copy-Item `
            (Join-Path $Exe.Directory.FullName "*") `
            $AppCache `
            -Recurse `
            -Force
    }

    Write-Host ""
    Write-Host "[ OK ] VirtualSTM32 Release cached:" -ForegroundColor Green
    Write-Host "       $AppCache"
}
finally {
    Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Setup complete."
Write-Host 'Run: .\tools\run.ps1 "D:\path\to\firmware.elf"'
