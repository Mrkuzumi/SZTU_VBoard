$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib\Toolchain.ps1")

function Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

Write-Host "=== VirtualSTM32 Windows Toolchain Doctor ===" -ForegroundColor Cyan
Write-Host "Project: $Root"
Write-Host ""

if(-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    Fail "cmake.exe not found in PATH."
    Write-Host "Install current CMake for Windows, then reopen PowerShell."
    exit 2
}
$versionLine = (& cmake --version | Select-Object -First 1)
Ok $versionLine

$generators = Get-Vstm32CMakeGenerators
$vswhere = Get-Vstm32VsWhere
if($vswhere) { Ok "vswhere: $vswhere" }
else { Warn "vswhere.exe not found; Visual Studio/Build Tools may be missing." }

$installations = @(Get-Vstm32VisualStudioInstallations)
if($installations.Count -gt 0) {
    foreach($vs in $installations) {
        Ok "C++ toolchain: $($vs.displayName) $($vs.installationVersion)"
    }
} else {
    Fail "No Visual Studio installation with MSVC x64/x86 C++ tools was detected."
}

$selection = Select-Vstm32VisualStudioGenerator
if($selection) {
    Ok "Selected CMake generator: $($selection.Generator)"
} else {
    Fail "No installed Visual Studio C++ toolchain matches a generator supported by this CMake."
    Write-Host "CMake knows: $($generators -join ', ')"
    Write-Host ""
    Write-Host "Install the 'Desktop development with C++' workload in Visual Studio/Build Tools."
    Write-Host "For Visual Studio 2026, CMake 4.2+ is required for the 'Visual Studio 18 2026' generator."
    Write-Host "Visual Studio 2022 remains supported by this project as a fallback."
    exit 3
}

if($env:CMAKE_GENERATOR) {
    Warn "CMAKE_GENERATOR='$env:CMAKE_GENERATOR' will be ignored by build_windows.ps1."
}
if($env:CMAKE_GENERATOR_PLATFORM) {
    Warn "CMAKE_GENERATOR_PLATFORM='$env:CMAKE_GENERATOR_PLATFORM' will be ignored by build_windows.ps1."
}

$renode = Join-Path $Root "third_party\renode\renode.exe"
if(Test-Path $renode) { Ok "Renode portable: $renode" }
else { Warn "Renode not installed yet. setup_all.ps1 will download it." }

$build = Join-Path $Root "build"
$cache = Join-Path $build "CMakeCache.txt"
if(Test-Path $cache) {
    $cached = Select-String -Path $cache -Pattern '^CMAKE_GENERATOR:INTERNAL=(.*)$' | Select-Object -First 1
    if($cached) {
        $old = $cached.Matches[0].Groups[1].Value
        if($old -ne $selection.Generator) {
            Warn "Stale build cache uses '$old'; build_windows.ps1 will recreate build/."
        } else {
            Ok "Existing build cache generator matches: $old"
        }
    }
}

Write-Host ""
Write-Host "Doctor finished: environment is ready for the Windows build." -ForegroundColor Cyan
