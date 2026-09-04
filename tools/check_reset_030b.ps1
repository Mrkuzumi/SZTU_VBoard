param()

$ErrorActionPreference = "Continue"

Write-Host "=== Patch 030b RESET check ===" -ForegroundColor Cyan

$temp = Join-Path $env:TEMP "VirtualSTM32"
$resc = Join-Path $temp "runtime.resc"
$runtimeElf = Join-Path $temp "firmware.elf"

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

Write-Host ""
Write-Host "--- runtime.resc reset macro ---" -ForegroundColor Yellow

if(Test-Path $resc) {
    $lines = Get-Content $resc

    $macroHit = $lines | Select-String -SimpleMatch "macro reset" | Select-Object -First 1

    if($macroHit) {
        $start = [Math]::Max(1, $macroHit.LineNumber - 1)
        $end = [Math]::Min($lines.Count, $macroHit.LineNumber + 8)

        for($i=$start; $i -le $end; $i++) {
            Write-Host ("{0,3}: {1}" -f $i,$lines[$i-1])
        }

        $all = $lines -join "`n"

        if($all -match 'macro reset[\s\S]*sysbus LoadELF @firmware\.elf') {
            Write-Host "[ OK ] reset macro reloads @firmware.elf." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] reset macro exists but LoadELF is missing." -ForegroundColor Red
        }

        if($all -match 'sysbus\.cpu VectorTableOffset 0x08000000') {
            Write-Host "[ OK ] Cortex-M VectorTableOffset restored to flash base." -ForegroundColor Green
        } else {
            Write-Host "[WARN] VectorTableOffset line is missing." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[FAIL] 'macro reset' is missing from runtime.resc." -ForegroundColor Red
    }
}
else {
    Write-Host "[FAIL] runtime.resc not found." -ForegroundColor Red
}

Write-Host ""
Write-Host "--- runtime firmware ---" -ForegroundColor Yellow

if(Test-Path $runtimeElf) {
    $item = Get-Item $runtimeElf
    $hash = Get-FileHash $runtimeElf -Algorithm SHA256

    Write-Host ("Time : {0}" -f $item.LastWriteTime)
    Write-Host ("Size : {0}" -f $item.Length)
    Write-Host ("Hash : {0}" -f $hash.Hash)
}
else {
    Write-Host "[FAIL] firmware.elf not found." -ForegroundColor Red
}

Write-Host ""
Write-Host "Expected RESET sequence:" -ForegroundColor Cyan
Write-Host "  machine Reset"
Write-Host "    -> Renode automatically runs `$reset"
Write-Host "    -> LoadELF @firmware.elf"
Write-Host "    -> VectorTableOffset 0x08000000"
Write-Host "  start"
Write-Host ""
Write-Host "Expected user-visible result:"
Write-Host "  KEY/LED firmware works before RESET and works again after RESET."
