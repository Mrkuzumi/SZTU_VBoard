param(
    [Parameter(Mandatory=$true)]
    [string]$Elf,
    [string]$GdbPath = ""
)

$ErrorActionPreference = "Stop"

if(!(Test-Path $Elf)) { throw "ELF not found: $Elf" }
$Elf = (Resolve-Path $Elf).Path

Write-Host "=== VirtualSTM32 GDB backend probe ===" -ForegroundColor Cyan

$listener = Get-NetTCPConnection -LocalPort 3333 -State Listen -ErrorAction SilentlyContinue
if(-not $listener) {
    Write-Host "[FAIL] Port 3333 is not listening." -ForegroundColor Red
    Write-Host "       Renode did not reach StartGdbServer."
    Write-Host "       Run: powershell -ExecutionPolicy Bypass -File .\tools\diagnose_backend.ps1"
    exit 2
}
Write-Host "[ OK ] Renode GDB server is listening on :3333" -ForegroundColor Green

function Test-GdbCandidate {
    param([string]$Path)
    return (-not [string]::IsNullOrWhiteSpace($Path)) -and (Test-Path $Path)
}

if([string]::IsNullOrWhiteSpace($GdbPath)) {
    $cmd = Get-Command arm-none-eabi-gdb.exe -ErrorAction SilentlyContinue
    if($cmd) { $GdbPath = $cmd.Source }
}

if(-not (Test-GdbCandidate $GdbPath)) {
    $roots = @(
        "C:\ST",
        "C:\Program Files\STMicroelectronics",
        "C:\Program Files (x86)\STMicroelectronics"
    ) | Where-Object { Test-Path $_ }

    foreach($root in $roots) {
        Write-Host "[INFO] Searching for arm-none-eabi-gdb.exe under $root ..."
        $found = Get-ChildItem -Path $root -Filter arm-none-eabi-gdb.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if($found) {
            $GdbPath = $found.FullName
            break
        }
    }
}

if(-not (Test-GdbCandidate $GdbPath)) {
    Write-Host "[WARN] arm-none-eabi-gdb.exe was not found automatically." -ForegroundColor Yellow
    Write-Host "       Port 3333 is already healthy, so the Renode baseline loaded successfully."
    Write-Host "       Re-run with -GdbPath pointing to CubeIDE's arm-none-eabi-gdb.exe."
    exit 0
}

Write-Host "[ OK ] GDB: $GdbPath" -ForegroundColor Green
Write-Host "[INFO] ELF: $Elf"
Write-Host ""

$cmdFile = Join-Path $env:TEMP "VirtualSTM32\gdb-probe.cmd"
$gdbCommands = @(
    "set pagination off",
    "set confirm off",
    "target remote 127.0.0.1:3333",
    "info registers pc sp lr xpsr",
    "printf `"\n--- current source/symbol ---\n`"",
    "info symbol `$pc",
    "info line *`$pc",
    "printf `"\n--- backtrace ---\n`"",
    "bt",
    "printf `"\n--- current instructions ---\n`"",
    "x/8i `$pc",
    "detach",
    "quit"
)
$gdbCommands | Set-Content -Path $cmdFile -Encoding ASCII

& $GdbPath -q -batch -x $cmdFile $Elf
$exit = $LASTEXITCODE

Write-Host ""
if($exit -eq 0) {
    Write-Host "[ OK ] GDB probe completed." -ForegroundColor Green
    Write-Host ""
    Write-Host "Interpretation:" -ForegroundColor Cyan
    Write-Host "  main / HAL_Delay / HAL_GPIO_TogglePin -> HAL firmware is running."
    Write-Host "  Error_Handler                         -> HAL initialization failed."
    Write-Host "  SystemClock_Config / HAL_RCC_*        -> RCC compatibility issue."
    Write-Host "  Default_Handler / HardFault_Handler   -> exception/model issue."
} else {
    Write-Host "[FAIL] GDB exited with code $exit." -ForegroundColor Red
}
