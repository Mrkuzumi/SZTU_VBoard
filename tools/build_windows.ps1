$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

# PATCH004_AUTOSTOP_VIRTUALSTM32
function Stop-ProjectVirtualSTM32 {
    param([string]$ProjectRoot)

    $exe = [IO.Path]::GetFullPath((Join-Path $ProjectRoot "build\Release\VirtualSTM32.exe"))

    $matches = @()
    try {
        $matches = Get-CimInstance Win32_Process -Filter "Name='VirtualSTM32.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                if([string]::IsNullOrWhiteSpace($_.ExecutablePath)) {
                    return $true
                }

                try {
                    return [IO.Path]::GetFullPath($_.ExecutablePath) -ieq $exe
                } catch {
                    return $true
                }
            }
    } catch {}

    foreach($p in $matches) {
        Write-Host "[INFO] Closing running VirtualSTM32.exe (PID $($p.ProcessId)) before link..."
        try {
            # /T also terminates the Renode process started as a child of this board instance.
            & taskkill.exe /PID $p.ProcessId /T /F 2>$null | Out-Null
        } catch {}
    }

    # Give Windows a moment to release the image file mapping.
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while([DateTime]::UtcNow -lt $deadline) {
        $stillRunning = Get-Process -Name VirtualSTM32 -ErrorAction SilentlyContinue
        if(-not $stillRunning) { break }
        Start-Sleep -Milliseconds 100
    }

    if(Test-Path $exe) {
        for($i = 0; $i -lt 20; $i++) {
            try {
                # We do not need to delete the executable; opening it for exclusive
                # write access is enough to verify that the linker can replace it.
                $fs = [IO.File]::Open(
                    $exe,
                    [IO.FileMode]::Open,
                    [IO.FileAccess]::ReadWrite,
                    [IO.FileShare]::None
                )
                $fs.Dispose()
                break
            } catch {
                if($i -eq 19) {
                    throw "VirtualSTM32.exe is still locked after stopping the running board. Close any remaining VirtualSTM32/antivirus handle and retry."
                }
                Start-Sleep -Milliseconds 150
            }
        }
    }
}

Stop-ProjectVirtualSTM32 -ProjectRoot $Root
# END_PATCH004_AUTOSTOP_VIRTUALSTM32
$Build = Join-Path $Root "build"
. (Join-Path $PSScriptRoot "lib\Toolchain.ps1")

if(-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw "cmake.exe was not found. Run tools\doctor.ps1 for environment diagnostics."
}

$selection = Select-Vstm32VisualStudioGenerator
if(-not $selection) {
    & (Join-Path $PSScriptRoot "doctor.ps1")
    throw "No compatible installed Visual Studio C++ toolchain / CMake generator."
}
$Generator = $selection.Generator

# Do not inherit NMake/MinGW/platform choices from the shell.
Remove-Item Env:CMAKE_GENERATOR -ErrorAction SilentlyContinue
Remove-Item Env:CMAKE_GENERATOR_PLATFORM -ErrorAction SilentlyContinue

# A build directory is tied to one generator. Recreate it after a failed V0.1.0 NMake configure.
$Cache = Join-Path $Build "CMakeCache.txt"
if(Test-Path $Cache) {
    $m = Select-String -Path $Cache -Pattern '^CMAKE_GENERATOR:INTERNAL=(.*)$' | Select-Object -First 1
    if($m) {
        $OldGenerator = $m.Matches[0].Groups[1].Value
        if($OldGenerator -ne $Generator) {
            Write-Host "Removing stale CMake cache: '$OldGenerator' -> '$Generator'" -ForegroundColor Yellow
            Remove-Item $Build -Recurse -Force
        }
    }
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

