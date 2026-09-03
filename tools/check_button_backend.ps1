param()

$ErrorActionPreference = "Continue"

Write-Host "=== VirtualSTM32 button backend check ===" -ForegroundColor Cyan

foreach($port in @(3333,33334,33335)) {
    $listener = Get-NetTCPConnection `
        -LocalPort $port `
        -State Listen `
        -ErrorAction SilentlyContinue

    if($listener) {
        Write-Host (
            "[ OK ] :{0} LISTEN pid={1}" -f
            $port,
            $listener[0].OwningProcess
        ) -ForegroundColor Green
    } else {
        Write-Host (
            "[FAIL] :{0} not listening" -f
            $port
        ) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Expected button electrical levels:" -ForegroundColor Cyan
Write-Host "  KEY0 / PB12 : released=HIGH, pressed=LOW"
Write-Host "  KEY1 / PB13 : released=HIGH, pressed=LOW"
Write-Host "  KEY2 / PB14 : released=HIGH, pressed=LOW"
Write-Host "  KEY3 / PB15 : released=HIGH, pressed=LOW"
Write-Host ""
Write-Host "For the current KEY0 test firmware:" -ForegroundColor Cyan
Write-Host "  released -> PB12 HIGH -> PC13 RESET -> LED0 ON"
Write-Host "  pressed  -> PB12 LOW  -> PC13 SET   -> LED0 OFF"
Write-Host ""
Write-Host "If that behavior is reversed from what you want,"
Write-Host "swap GPIO_PIN_SET and GPIO_PIN_RESET in the STM32 firmware."
