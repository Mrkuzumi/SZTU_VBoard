param(
    [string]$ProjectRoot = "",
    [string]$Elf = "G:\STM32_test\Vboard_test\test_main\Release\test_main.elf"
)

$ErrorActionPreference = "Stop"

if([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Get-Location).Path
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

$exe = Join-Path $ProjectRoot "build\Release\VirtualSTM32.exe"
if(!(Test-Path $exe)) { throw "VirtualSTM32.exe not found: $exe" }
if(!(Test-Path $Elf)) { throw "ELF not found: $Elf" }

# Stop an existing project instance first.
$projectExe = [IO.Path]::GetFullPath($exe)
Get-CimInstance Win32_Process -Filter "Name='VirtualSTM32.exe'" -ErrorAction SilentlyContinue |
    ForEach-Object {
        try {
            if($_.ExecutablePath -and ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $projectExe)) {
                & taskkill.exe /PID $_.ProcessId /T /F 2>$null | Out-Null
            }
        } catch {}
    }

Start-Sleep -Milliseconds 300

$p = Start-Process -FilePath $exe -ArgumentList @($Elf) -PassThru
Start-Sleep -Seconds 3

$tempDir = Join-Path $env:TEMP "VirtualSTM32"
$runtimeElf = Join-Path $tempDir "firmware.elf"
$resc = Join-Path $tempDir "runtime.resc"

Write-Host "=== VirtualSTM32 runtime firmware path verification ===" -ForegroundColor Cyan

if(Test-Path $runtimeElf) {
    Write-Host "[ OK ] Runtime ELF exists: $runtimeElf" -ForegroundColor Green
    Write-Host ("       Size: {0:N0} bytes" -f (Get-Item $runtimeElf).Length)
} else {
    Write-Host "[FAIL] Runtime ELF was not created." -ForegroundColor Red
}

if(Test-Path $resc) {
    $rescText = Get-Content $resc -Raw
    Write-Host ""
    Write-Host "--- runtime.resc ---" -ForegroundColor Yellow
    Write-Host $rescText

    if($rescText -match 'sysbus LoadELF @firmware\.elf') {
        Write-Host "[ OK ] runtime.resc uses relative @firmware.elf." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] runtime.resc does not use relative @firmware.elf." -ForegroundColor Red
    }
}

$gdb = Get-NetTCPConnection -LocalPort 3333 -State Listen -ErrorAction SilentlyContinue
if($gdb) {
    Write-Host "[ OK ] GDB :3333 is listening." -ForegroundColor Green
} else {
    Write-Host "[FAIL] GDB :3333 is not listening." -ForegroundColor Red
}

Write-Host ""
Write-Host "VirtualSTM32 PID: $($p.Id)"
Write-Host "Keep it open if you want to run tools\probe_gdb_backend.ps1 next."
