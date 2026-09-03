param()

Write-Host "=== Patch 027 runtime check ===" -ForegroundColor Cyan

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
Write-Host "--- vboard_runtime.repl ---" -ForegroundColor Yellow
$repl = Join-Path $temp "vboard_runtime.repl"
if(Test-Path $repl) {
    Get-Content $repl

    $content = Get-Content $repl -Raw
    if($content -match 'systickFrequency|^nvic:' ) {
        Write-Host "[FAIL] Invalid NVIC/SysTick overlay is still present." -ForegroundColor Red
    } else {
        Write-Host "[ OK ] No secondary NVIC SysTick override." -ForegroundColor Green
    }
} else {
    Write-Host "<missing>" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- runtime.resc ---" -ForegroundColor Yellow
$resc = Join-Path $temp "runtime.resc"
if(Test-Path $resc) { Get-Content $resc } else { Write-Host "<missing>" -ForegroundColor Red }

Write-Host ""
Write-Host "--- firmware hash ---" -ForegroundColor Yellow
$runtimeElf = Join-Path $temp "firmware.elf"
$releaseElf = "G:\STM32_test\Vboard_test\test_main\Release\test_main.elf"

if(Test-Path $runtimeElf) {
    Write-Host ("runtime : " + (Get-FileHash $runtimeElf -Algorithm SHA256).Hash)
}
if(Test-Path $releaseElf) {
    Write-Host ("release : " + (Get-FileHash $releaseElf -Algorithm SHA256).Hash)
}

Write-Host ""
Write-Host "--- startup log tail ---" -ForegroundColor Yellow
$log = Join-Path $temp "renode-startup.log"
if(Test-Path $log) {
    Get-Content $log -Tail 100
} else {
    Write-Host "<missing>"
}
