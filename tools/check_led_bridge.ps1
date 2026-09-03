param(
    [int]$Samples = 20,
    [int]$IntervalMs = 200
)

$root = Join-Path $env:TEMP "VirtualSTM32"
Write-Host "=== VirtualSTM32 LED bridge check ===" -ForegroundColor Cyan
Write-Host "Directory: $root"
Write-Host ""

for($i = 1; $i -le $Samples; $i++) {
    $values = @()

    for($n = 0; $n -lt 4; $n++) {
        $p = Join-Path $root ("led{0}.state" -f $n)
        if(Test-Path $p) {
            try {
                $v = (Get-Content $p -Raw -ErrorAction Stop).Trim()
                if([string]::IsNullOrWhiteSpace($v)) { $v = "?" }
            } catch {
                $v = "ERR"
            }
        } else {
            $v = "-"
        }

        $values += ("LED{0}={1}" -f $n,$v)
    }

    Write-Host ("[{0,2}] {1}" -f $i,($values -join "  "))
    Start-Sleep -Milliseconds $IntervalMs
}

Write-Host ""
Write-Host "For PC13 active-low blink, raw LED0 should alternate 0/1." -ForegroundColor Yellow
Write-Host "If LED0 alternates here but the picture does not, the remaining bug is SDL rendering." -ForegroundColor Yellow
Write-Host "If LED0 never alternates, the firmware/STM32 emulation path needs GDB diagnosis on port 3333." -ForegroundColor Yellow
