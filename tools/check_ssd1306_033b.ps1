param()

Write-Host "=== Patch 033B SSD1306 check ===" -ForegroundColor Cyan

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
$resc = Join-Path $temp "runtime.resc"
$bridge = Join-Path $temp "ssd1306_bridge_mem.py"
$log = Join-Path $temp "renode-startup.log"
$oldBin = Join-Path $temp "oled.bin"

Write-Host ""
Write-Host "--- runtime overlay ---" -ForegroundColor Yellow

if(Test-Path $repl) {
    Get-Content $repl

    $all = Get-Content $repl -Raw

    if($all -match 'ssd1306:\s+Mocks\.DummyI2CSlave\s+@\s+i2c1\s+0x3C') {
        Write-Host "[ OK ] SSD1306 is attached to I2C1 @ 0x3C." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] SSD1306 I2C target missing." -ForegroundColor Red
    }

    if($all -match 'oledFramebuffer:\s+Memory\.MappedMemory\s+@\s+sysbus\s+0x60000000') {
        Write-Host "[ OK ] OLED mapped framebuffer exists @ 0x60000000." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] OLED mapped framebuffer missing." -ForegroundColor Red
    }
} else {
    Write-Host "[FAIL] $repl missing." -ForegroundColor Red
}

Write-Host ""
Write-Host "--- runtime script ---" -ForegroundColor Yellow
if(Test-Path $resc) {
    Get-Content $resc

    if((Get-Content $resc -Raw) -match 'include @ssd1306_bridge_mem\.py') {
        Write-Host "[ OK ] SSD1306 parser is included." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] SSD1306 parser include missing." -ForegroundColor Red
    }
}

Write-Host ""
if(Test-Path $bridge) {
    Write-Host "[ OK ] runtime SSD1306 bridge file exists." -ForegroundColor Green
} else {
    Write-Host "[FAIL] runtime SSD1306 bridge file missing." -ForegroundColor Red
}

if(Test-Path $oldBin) {
    Write-Host "[WARN] oled.bin exists, but Patch 033B does not use it." -ForegroundColor Yellow
} else {
    Write-Host "[ OK ] No oled.bin polling file is in use." -ForegroundColor Green
}

Write-Host ""
Write-Host "--- Renode startup tail ---" -ForegroundColor Yellow
if(Test-Path $log) {
    Get-Content $log -Tail 120
} else {
    Write-Host "<missing>"
}

Write-Host ""
Write-Host "Expected startup log marker:" -ForegroundColor Cyan
Write-Host "  VSTM32_SSD1306_BRIDGE_READY framebuffer=0x60000000 size=1024"
