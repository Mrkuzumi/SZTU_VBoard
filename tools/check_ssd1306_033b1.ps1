param()

$ErrorActionPreference = "Continue"

Write-Host "=== Patch 033B1 check ===" -ForegroundColor Cyan

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
$resc = Join-Path $temp "runtime.resc"
$bridge = Join-Path $temp "ssd1306_bridge_mem.py"

Write-Host ""
Write-Host "--- runtime ordering ---" -ForegroundColor Yellow

if(Test-Path $resc) {
    Get-Content $resc

    $all = Get-Content $resc -Raw

    $ecPos = $all.IndexOf('CreateExternalControlServer')
    $pyPos = $all.IndexOf('include @ssd1306_bridge_mem.py')

    if($ecPos -ge 0 -and $pyPos -ge 0 -and $ecPos -lt $pyPos) {
        Write-Host "[ OK ] External Control is created before OLED bridge include." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Runtime command order was not updated." -ForegroundColor Red
    }
}

if(Test-Path $bridge) {
    Write-Host "[ OK ] runtime bridge file exists." -ForegroundColor Green
} else {
    Write-Host "[FAIL] runtime bridge file missing." -ForegroundColor Red
}

Write-Host ""
Write-Host "--- OLED bridge status through Monitor :33335 ---" -ForegroundColor Yellow

try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $client.Connect("127.0.0.1",33335)

    $stream = $client.GetStream()
    $stream.ReadTimeout = 800
    $stream.WriteTimeout = 800

    Start-Sleep -Milliseconds 150

    $buffer = New-Object byte[] 8192

    # Drain greeting/prompt.
    while($stream.DataAvailable) {
        [void]$stream.Read($buffer,0,$buffer.Length)
    }

    $cmd = "sysbus ReadDoubleWord 0x60000410`r`n"
    $bytes = [Text.Encoding]::ASCII.GetBytes($cmd)

    $stream.Write($bytes,0,$bytes.Length)
    $stream.Flush()

    Start-Sleep -Milliseconds 180

    $out = ""

    while($stream.DataAvailable) {
        $n = $stream.Read($buffer,0,$buffer.Length)

        if($n -gt 0) {
            $out += [Text.Encoding]::ASCII.GetString($buffer,0,$n)
        }

        Start-Sleep -Milliseconds 30
    }

    $client.Close()

    Write-Host $out.Trim()

    if($out -match 'B033B1FF') {
        Write-Host "[ OK ] SSD1306 Python bridge reports READY." -ForegroundColor Green
    }
    elseif($out -match 'E033B102') {
        Write-Host "[FAIL] Python could not find sysbus.i2c1.ssd1306." -ForegroundColor Red
    }
    elseif($out -match 'E033B103') {
        Write-Host "[FAIL] Python bridge installed but failed handling I2C data." -ForegroundColor Red
    }
    elseif($out -match 'B033B101') {
        Write-Host "[WARN] Python bridge remained in INIT state." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] Status value not recognized; paste this whole output back." -ForegroundColor Yellow
    }
}
catch {
    Write-Host ("[FAIL] Could not query Monitor: " + $_.Exception.Message) -ForegroundColor Red
}

Write-Host ""
Write-Host "Expected final state:" -ForegroundColor Cyan
Write-Host "  :3333  LISTEN"
Write-Host "  :33334 LISTEN"
Write-Host "  :33335 LISTEN"
Write-Host "  bridge status = 0xB033B1FF"
Write-Host "  BACKEND = GREEN"
Write-Host "  OLED = VIRTUAL STM32 / SSD1306 OK / I2C1 0X3C"
