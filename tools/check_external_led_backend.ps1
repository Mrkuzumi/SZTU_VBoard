param()

$ErrorActionPreference = "Continue"

Write-Host "=== VirtualSTM32 Patch 021 backend check ===" -ForegroundColor Cyan

foreach($port in @(3333,33334,33335)) {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if($listener) {
        Write-Host ("[ OK ] :{0} LISTEN pid={1}" -f $port,$listener[0].OwningProcess) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] :{0} not listening" -f $port) -ForegroundColor Red
    }
}

$temp = Join-Path $env:TEMP "VirtualSTM32"

Write-Host ""
Write-Host "--- runtime.resc ---" -ForegroundColor Yellow
$resc = Join-Path $temp "runtime.resc"
if(Test-Path $resc) {
    Get-Content $resc
} else {
    Write-Host "<missing>" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- vboard_runtime.repl ---" -ForegroundColor Yellow
$repl = Join-Path $temp "vboard_runtime.repl"
if(Test-Path $repl) {
    Get-Content $repl
} else {
    Write-Host "<missing>" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- Renode startup tail ---" -ForegroundColor Yellow
$log = Join-Path $temp "renode-startup.log"
if(Test-Path $log) {
    Get-Content $log -Tail 80
} else {
    Write-Host "<missing>" -ForegroundColor Red
}

Write-Host ""
Write-Host "Expected overlay:" -ForegroundColor Cyan
Write-Host "  PC13 -> PB0"
Write-Host "  PA0  -> PB1"
Write-Host "  PA1  -> PB2"
Write-Host "  PA2  -> PB3"
Write-Host "  SysTick = 8 MHz"
Write-Host ""
Write-Host "Expected window title after connection:"
Write-Host "  RUN | GPIO API | GDB :3333"
