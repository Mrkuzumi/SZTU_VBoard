param(
    [switch]$Apply,
    [switch]$MoveRenodeToCache
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$CacheRoot = Join-Path $env:LOCALAPPDATA "VirtualSTM32"
$RenodeCache = Join-Path $CacheRoot "renode\1.16.1"

function Get-DirectoryBytes([string]$Path) {
    if(!(Test-Path $Path)) { return [int64]0 }

    return [int64](
        Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum
    ).Sum
}

function Format-Bytes([int64]$Bytes) {
    if($Bytes -ge 1GB) { return "{0:N2} GiB" -f ($Bytes / 1GB) }
    if($Bytes -ge 1MB) { return "{0:N2} MiB" -f ($Bytes / 1MB) }
    if($Bytes -ge 1KB) { return "{0:N2} KiB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

$Before = Get-DirectoryBytes $ProjectRoot

Write-Host "=== VirtualSTM32 repository slim tool ===" -ForegroundColor Cyan
Write-Host "Project size before: $(Format-Bytes $Before)"
Write-Host ""

$GeneratedDirs = @(
    (Join-Path $ProjectRoot "build"),
    (Join-Path $ProjectRoot "out"),
    (Join-Path $ProjectRoot ".vs"),
    (Join-Path $ProjectRoot "Download")
)

$ObsoleteSources = @(
    "src\App.cpp",
    "src\App.h",
    "src\BoardConfig.h",
    "src\BoardRenderer.cpp",
    "src\BoardRenderer.h",
    "src\MonitorClient.cpp",
    "src\MonitorClient.h",
    "src\OledFramebuffer.cpp",
    "src\OledFramebuffer.h",
    "src\RenodeProcess.cpp",
    "src\RenodeProcess.h"
)

$ObsoleteRenode = @(
    "renode\gpio_led_bridge.cs",
    "renode\ssd1306_bridge.py",
    "renode\teaching_board.repl",
    "ssd1306_bridge_mem.py"
)

$CMakeText = ""
$CMakePath = Join-Path $ProjectRoot "CMakeLists.txt"

if(Test-Path $CMakePath) {
    $CMakeText = Get-Content $CMakePath -Raw
}

Write-Host "Generated directories:" -ForegroundColor Yellow
foreach($p in $GeneratedDirs) {
    if(Test-Path $p) {
        Write-Host ("  {0,-55} {1}" -f $p,(Format-Bytes (Get-DirectoryBytes $p)))
    }
}

$BundledRenode = Join-Path $ProjectRoot "third_party\renode"

if(Test-Path $BundledRenode) {
    Write-Host ("  {0,-55} {1}" -f $BundledRenode,(Format-Bytes (Get-DirectoryBytes $BundledRenode)))
}

$Backups = @(
    Get-ChildItem `
        $ProjectRoot `
        -File `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match '\.pre.*\.bak$'
    }
)

Write-Host ""
Write-Host "Patch backup files: $($Backups.Count)"

$SafeObsolete = @()

foreach($rel in $ObsoleteSources) {
    $path = Join-Path $ProjectRoot $rel

    if(!(Test-Path $path)) {
        continue
    }

    $cmakeForm = $rel.Replace("\","/")

    if($CMakeText -match [regex]::Escape($cmakeForm)) {
        Write-Warning "Keeping because CMakeLists references it: $rel"
        continue
    }

    $SafeObsolete += $path
}

foreach($rel in $ObsoleteRenode) {
    $path = Join-Path $ProjectRoot $rel

    if(Test-Path $path) {
        $SafeObsolete += $path
    }
}

Write-Host "Obsolete duplicate/legacy files: $($SafeObsolete.Count)"
Write-Host ""

if(-not $Apply) {
    Write-Host "DRY RUN only. Nothing was deleted or moved." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Apply cleanup:"
    Write-Host '  .\tools\repo_slim.ps1 -Apply'
    Write-Host ""
    Write-Host "Apply cleanup and move bundled Renode out of the repository:"
    Write-Host '  .\tools\repo_slim.ps1 -Apply -MoveRenodeToCache'
    exit 0
}

foreach($p in $GeneratedDirs) {
    if(Test-Path $p) {
        Write-Host "Removing generated directory: $p"
        Remove-Item $p -Recurse -Force
    }
}

foreach($f in $Backups) {
    Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
}

foreach($p in $SafeObsolete) {
    Write-Host "Removing obsolete file: $p"
    Remove-Item $p -Force -ErrorAction SilentlyContinue
}

if($MoveRenodeToCache -and (Test-Path $BundledRenode)) {
    Write-Host ""
    Write-Host "Moving bundled Renode out of repository..." -ForegroundColor Cyan

    if(Test-Path $RenodeCache) {
        $CachedExe = Join-Path $RenodeCache "renode.exe"

        if(Test-Path $CachedExe) {
            Write-Host "[ OK ] Cached Renode already exists. Removing project-local copy."
            Remove-Item $BundledRenode -Recurse -Force
        }
        else {
            throw "Renode cache directory exists but renode.exe is missing: $RenodeCache"
        }
    }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path $RenodeCache -Parent) | Out-Null
        Move-Item $BundledRenode $RenodeCache
    }

    $CachedExe = Join-Path $RenodeCache "renode.exe"

    if(!(Test-Path $CachedExe)) {
        throw "Renode was moved, but renode.exe was not found at $CachedExe"
    }

    $env:RENODE_PATH = $CachedExe
    [Environment]::SetEnvironmentVariable(
        "RENODE_PATH",
        $CachedExe,
        "User"
    )

    Write-Host "[ OK ] Renode cache: $CachedExe" -ForegroundColor Green
}

# Remove the now-empty third_party directory if possible.
$ThirdParty = Join-Path $ProjectRoot "third_party"

if(Test-Path $ThirdParty) {
    $children = @(Get-ChildItem $ThirdParty -Force -ErrorAction SilentlyContinue)

    if($children.Count -eq 0) {
        Remove-Item $ThirdParty -Force
    }
}

$After = Get-DirectoryBytes $ProjectRoot

Write-Host ""
Write-Host "Project size after : $(Format-Bytes $After)" -ForegroundColor Green
Write-Host "Space removed      : $(Format-Bytes ([Math]::Max(0,$Before-$After)))"
Write-Host ""
Write-Host "Large build/runtime caches now belong in %LOCALAPPDATA%\VirtualSTM32."
