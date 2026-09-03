param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Continue"

if([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Get-Location).Path
}

$tempDir = Join-Path $env:TEMP "VirtualSTM32"
$startup = Join-Path $tempDir "renode-startup.log"
$runtime = Join-Path $tempDir "renode-runtime.log"
$resc    = Join-Path $tempDir "runtime.resc"

Write-Host "=== VirtualSTM32 backend diagnostics ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectRoot"
Write-Host "Temp:    $tempDir"
Write-Host ""

Write-Host "--- Processes ---" -ForegroundColor Yellow
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @("VirtualSTM32.exe","renode.exe") } |
    Select-Object ProcessId,Name,ExecutablePath,CommandLine |
    Format-List

Write-Host "--- Ports ---" -ForegroundColor Yellow
foreach($port in @(3333,33335)) {
    $listeners = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if($listeners) {
        foreach($l in $listeners) {
            Write-Host ("[LISTEN] {0}  PID={1}" -f $port,$l.OwningProcess) -ForegroundColor Green
        }
    } else {
        Write-Host ("[----]   {0}" -f $port) -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host "--- Bridge files ---" -ForegroundColor Yellow
for($i=0; $i -lt 4; $i++) {
    $p = Join-Path $tempDir ("led{0}.state" -f $i)
    if(Test-Path $p) {
        $v = (Get-Content $p -Raw -ErrorAction SilentlyContinue).Trim()
        Write-Host "[ OK ] $p = $v" -ForegroundColor Green
    } else {
        Write-Host "[MISS] $p" -ForegroundColor Red
    }
}

function Show-FileTail {
    param([string]$Title,[string]$Path,[int]$Lines=120)

    Write-Host ""
    Write-Host ("--- " + $Title + " ---") -ForegroundColor Yellow
    Write-Host $Path
    if(Test-Path $Path) {
        Get-Content $Path -Tail $Lines
    } else {
        Write-Host "<file does not exist>" -ForegroundColor Red
    }
}

Show-FileTail "Renode startup stdout/stderr" $startup
Show-FileTail "Renode runtime logger" $runtime

Write-Host ""
Write-Host "--- runtime.resc ---" -ForegroundColor Yellow
Write-Host $resc
if(Test-Path $resc) {
    Get-Content $resc
} else {
    Write-Host "<file does not exist>" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- Built resource presence ---" -ForegroundColor Yellow
$release = Join-Path $ProjectRoot "build\Release"
foreach($rel in @(
    "VirtualSTM32.exe",
    "renode\teaching_board.repl",
    "renode\gpio_led_bridge.cs",
    "renode\ssd1306_bridge.py"
)) {
    $p = Join-Path $release $rel
    if(Test-Path $p) {
        Write-Host "[ OK ] $p" -ForegroundColor Green
    } else {
        Write-Host "[MISS] $p" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Copy this complete output back to ChatGPT if the board still does not run." -ForegroundColor Cyan
