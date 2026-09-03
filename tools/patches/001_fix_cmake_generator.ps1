param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$Tools = Join-Path $ProjectRoot "tools"
$Target = Join-Path $Tools "build_windows.ps1"

if(-not (Test-Path (Join-Path $ProjectRoot "CMakeLists.txt"))) {
    throw "CMakeLists.txt not found under '$ProjectRoot'. Run this from the SZTU_VBoard project root or pass -ProjectRoot."
}
if(-not (Test-Path $Tools)) { throw "tools directory not found: $Tools" }

$Backup = "$Target.before_v0.1.1.bak"
if(Test-Path $Target) {
    Copy-Item $Target $Backup -Force
    Write-Host "Backup: $Backup" -ForegroundColor DarkGray
}

$fixed = @'
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root "build"

function Get-SupportedGenerator {
    if(-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
        throw "cmake.exe not found in PATH."
    }
    $caps = (& cmake -E capabilities | Out-String | ConvertFrom-Json)
    $names = @($caps.generators | ForEach-Object { $_.name })

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if(-not (Test-Path $vswhere)) {
        throw "Visual Studio vswhere.exe not found. Install Visual Studio/Build Tools with 'Desktop development with C++'."
    }
    $raw = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json -utf8
    $installs = @($raw | Out-String | ConvertFrom-Json | Sort-Object { [version]$_.installationVersion } -Descending)
    foreach($vs in $installs) {
        $major = ([version]$vs.installationVersion).Major
        $candidate = if($major -eq 18) { "Visual Studio 18 2026" } elseif($major -eq 17) { "Visual Studio 17 2022" } else { $null }
        if($candidate -and ($names -contains $candidate)) { return $candidate }
    }
    return $null
}

$Generator = Get-SupportedGenerator
if(-not $Generator) {
    throw "No compatible Visual Studio C++ toolchain / CMake generator. For Visual Studio 2026 use CMake 4.2+. VS2022 is also supported."
}

Remove-Item Env:CMAKE_GENERATOR -ErrorAction SilentlyContinue
Remove-Item Env:CMAKE_GENERATOR_PLATFORM -ErrorAction SilentlyContinue

# V0.1.0 may have initialized build/ with NMake Makefiles. A CMake build tree
# cannot safely change generator/platform, so recreate it once.
if(Test-Path $Build) {
    Write-Host "Removing old build directory to clear the NMake cache..." -ForegroundColor Yellow
    Remove-Item $Build -Recurse -Force
}

Write-Host "[1/2] Configure ($Generator, x64)..." -ForegroundColor Cyan
& cmake -S $Root -B $Build -G $Generator -A x64
if($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE" }

Write-Host "[2/2] Build Release..." -ForegroundColor Cyan
& cmake --build $Build --config Release --parallel
if($LASTEXITCODE -ne 0) { throw "CMake build failed with exit code $LASTEXITCODE" }

$Exe = Join-Path $Build "Release\VirtualSTM32.exe"
if(!(Test-Path $Exe)) { throw "Build finished but $Exe was not found" }
Write-Host "OK: $Exe" -ForegroundColor Green
'@

Set-Content -Path $Target -Value $fixed -Encoding UTF8
if(Test-Path (Join-Path $ProjectRoot "build")) {
    Remove-Item (Join-Path $ProjectRoot "build") -Recurse -Force
}

Write-Host "V0.1.0 build-generator patch applied." -ForegroundColor Green
Write-Host "Now run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tools\build_windows.ps1" -ForegroundColor Cyan
