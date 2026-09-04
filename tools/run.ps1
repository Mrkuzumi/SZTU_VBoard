param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Elf
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$CacheRoot = Join-Path $env:LOCALAPPDATA "VirtualSTM32"

if(!(Test-Path $Elf)) {
    throw "Firmware file not found: $Elf"
}

$Elf = (Resolve-Path $Elf).Path
$Extension = [IO.Path]::GetExtension($Elf).ToLowerInvariant()

if($Extension -notin @(".elf", ".axf")) {
    Write-Warning "Expected .elf or .axf firmware, got: $Extension"
}

function Find-App {
    $candidates = @(
        (Join-Path $ProjectRoot "VirtualSTM32.exe"),
        (Join-Path $ProjectRoot "build\Release\VirtualSTM32.exe"),
        (Join-Path $CacheRoot "build\VirtualSTM32F103C8T6\Release\VirtualSTM32.exe"),
        (Join-Path $CacheRoot "app\latest\VirtualSTM32.exe")
    )

    foreach($candidate in $candidates) {
        if(Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Find-Renode {
    if($env:RENODE_PATH) {
        $p = $env:RENODE_PATH

        if(Test-Path $p) {
            if((Get-Item $p).PSIsContainer) {
                $p = Join-Path $p "renode.exe"
            }

            if(Test-Path $p) {
                return (Resolve-Path $p).Path
            }
        }
    }

    $candidates = @(
        (Join-Path $CacheRoot "renode\1.16.1\renode.exe"),
        (Join-Path $ProjectRoot "third_party\renode\renode.exe")
    )

    foreach($candidate in $candidates) {
        if(Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

$App = Find-App

if(-not $App) {
    & (Join-Path $PSScriptRoot "setup.ps1")
    $App = Find-App
}

if(-not $App) {
    throw "VirtualSTM32.exe is unavailable. Download a Release or run tools\build.ps1."
}

$Renode = Find-Renode

if(-not $Renode) {
    & (Join-Path $PSScriptRoot "setup_runtime.ps1")
    $Renode = Find-Renode
}

if(-not $Renode) {
    throw "Renode runtime is unavailable after setup."
}

Write-Host "VirtualSTM32: $App"
Write-Host "Firmware     : $Elf"
Write-Host "Renode       : $Renode"

# Quote paths explicitly because Start-Process joins ArgumentList into a
# Windows command line.
$Arguments = @(
    "--elf",
    ('"' + $Elf + '"'),
    "--renode",
    ('"' + $Renode + '"')
)

Start-Process `
    -FilePath $App `
    -ArgumentList $Arguments
