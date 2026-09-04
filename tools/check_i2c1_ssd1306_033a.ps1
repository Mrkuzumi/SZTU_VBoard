param()

Write-Host "=== Patch 033A I2C1 / SSD1306 check ===" -ForegroundColor Cyan

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
$repl = Join-Path $temp "vboard_runtime.repl"
$log  = Join-Path $temp "renode-startup.log"

Write-Host ""
Write-Host "--- vboard_runtime.repl ---" -ForegroundColor Yellow

if(Test-Path $repl) {
    Get-Content $repl

    $content = Get-Content $repl -Raw

    if($content -match 'ssd1306:\s+Mocks\.DummyI2CSlave\s+@\s+i2c1\s+0x3C') {
        Write-Host "[ OK ] SSD1306 target is attached to I2C1 at 7-bit 0x3C." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] SSD1306 I2C target is missing." -ForegroundColor Red
    }
}
else {
    Write-Host "[FAIL] runtime REPL missing: $repl" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- startup log tail ---" -ForegroundColor Yellow

if(Test-Path $log) {
    Get-Content $log -Tail 100
} else {
    Write-Host "<missing>"
}

Write-Host ""
Write-Host "HAL address reminder:" -ForegroundColor Cyan
Write-Host "  Renode REPL : 0x3C       (7-bit)"
Write-Host "  STM32 HAL   : 0x3C << 1  = 0x78"
Write-Host ""
Write-Host "PASS condition in firmware:"
Write-Host "  HAL_I2C_IsDeviceReady(...) == HAL_OK"
Write-Host "  HAL_I2C_Master_Transmit(...) == HAL_OK"
