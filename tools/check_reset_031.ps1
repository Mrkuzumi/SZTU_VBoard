param()

Write-Host "=== Patch 031 RESET runtime check ===" -ForegroundColor Cyan

foreach($port in @(3333,33334,33335)) {
    $listener = Get-NetTCPConnection `
        -LocalPort $port `
        -State Listen `
        -ErrorAction SilentlyContinue

    if($listener) {
        Write-Host ("[ OK ] :{0} LISTEN pid={1}" -f $port,$listener[0].OwningProcess) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] :{0} not listening" -f $port) -ForegroundColor Red
    }
}

$temp = Join-Path $env:TEMP "VirtualSTM32"
$runtimeElf = Join-Path $temp "firmware.elf"
$releaseElf = "G:\STM32_test\Vboard_test\test_main\Release\test_main.elf"

Write-Host ""
Write-Host "--- firmware hashes ---" -ForegroundColor Yellow

if(Test-Path $runtimeElf) {
    Write-Host ("runtime : " + (Get-FileHash $runtimeElf -Algorithm SHA256).Hash)
} else {
    Write-Host "runtime : <missing>" -ForegroundColor Red
}

if(Test-Path $releaseElf) {
    Write-Host ("release : " + (Get-FileHash $releaseElf -Algorithm SHA256).Hash)
} else {
    Write-Host "release : <missing>" -ForegroundColor Red
}

Write-Host ""
Write-Host "Patch 031 does NOT require a `$reset macro in runtime.resc." -ForegroundColor Cyan
Write-Host "RESET is executed explicitly as:"
Write-Host "  machine Reset"
Write-Host "  sysbus LoadELF @firmware.elf"
Write-Host "  sysbus.cpu VectorTableOffset 0x08000000"
Write-Host "  start"
