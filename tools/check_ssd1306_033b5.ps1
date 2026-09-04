param()

$ErrorActionPreference = "Continue"

Write-Host "=== Patch 033B5 runtime check ===" -ForegroundColor Cyan

foreach($port in @(3333,33334,33335)) {
    $listener = Get-NetTCPConnection `
        -LocalPort $port `
        -State Listen `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if($listener) {
        Write-Host ("[ OK ] :{0} LISTEN pid={1}" -f $port,$listener.OwningProcess) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] :{0} not listening" -f $port) -ForegroundColor Red
    }
}

$temp = Join-Path $env:TEMP "VirtualSTM32"
$overlay = Join-Path $temp "vboard_runtime.repl"
$resc = Join-Path $temp "runtime.resc"

Write-Host ""
Write-Host "--- runtime overlay ---" -ForegroundColor Yellow

if(Test-Path $overlay) {
    Get-Content $overlay

    $all = Get-Content $overlay -Raw

    if($all -match 'ssd1306:\s+Mocks\.DummyI2CSlave\s+@\s+i2c1\s+0x3C') {
        Write-Host "[ OK ] SSD1306 DummyI2CSlave @ I2C1 0x3C exists." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] SSD1306 I2C target missing." -ForegroundColor Red
    }

    if($all -match 'oledFramebuffer:\s+Memory\.MappedMemory') {
        Write-Host "[FAIL] Duplicate OLED MappedMemory still exists!" -ForegroundColor Red
    } else {
        Write-Host "[ OK ] No duplicate MappedMemory is registered at 0x60000000." -ForegroundColor Green
    }
} else {
    Write-Host "[FAIL] Runtime overlay missing: $overlay" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- runtime script ---" -ForegroundColor Yellow

if(Test-Path $resc) {
    Get-Content $resc
}

Write-Host ""
Write-Host "--- OLED mailbox / bridge status ---" -ForegroundColor Yellow

try {
    $client = [Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 1000
    $client.SendTimeout = 1000
    $client.Connect("127.0.0.1",33335)

    $stream = $client.GetStream()
    $stream.ReadTimeout = 800
    $stream.WriteTimeout = 800

    Start-Sleep -Milliseconds 150

    $buf = New-Object byte[] 16384
    while($stream.DataAvailable) {
        [void]$stream.Read($buf,0,$buf.Length)
    }

    foreach($cmd in @(
        "sysbus ReadDoubleWord 0x60000000",
        "sysbus ReadDoubleWord 0x60000404",
        "sysbus ReadDoubleWord 0x60000408",
        "sysbus ReadDoubleWord 0x60000410"
    )) {
        Write-Host ""
        Write-Host ("> " + $cmd) -ForegroundColor Cyan

        $bytes = [Text.Encoding]::ASCII.GetBytes($cmd + "`r`n")
        $stream.Write($bytes,0,$bytes.Length)
        $stream.Flush()

        Start-Sleep -Milliseconds 160
        $out = ""

        for($i=0; $i -lt 8; $i++) {
            while($stream.DataAvailable) {
                $n = $stream.Read($buf,0,$buf.Length)
                if($n -gt 0) {
                    $out += [Text.Encoding]::ASCII.GetString($buf,0,$n)
                }
            }
            Start-Sleep -Milliseconds 30
        }

        Write-Host $out.Trim()
    }

    $client.Close()
}
catch {
    Write-Host ("[FAIL] Monitor query failed: " + $_.Exception.Message) -ForegroundColor Red
}

Write-Host ""
Write-Host "Expected healthy result:" -ForegroundColor Cyan
Write-Host "  :33335 LISTEN"
Write-Host "  :33334 LISTEN"
Write-Host "  :3333  LISTEN"
Write-Host "  runtime overlay has NO oledFramebuffer: Memory.MappedMemory"
Write-Host "  0x60000410 should become 0xB033B1FF when Python SSD1306 bridge is ready"
Write-Host "  BACKEND should be green"
