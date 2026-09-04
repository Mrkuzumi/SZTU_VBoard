param()

Write-Host "=== Patch 035 replacement-instance check ===" -ForegroundColor Cyan

$boards = Get-CimInstance Win32_Process -Filter "Name='VirtualSTM32.exe'" -ErrorAction SilentlyContinue
$renodes = Get-CimInstance Win32_Process -Filter "Name='renode.exe'" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("VirtualSTM32 count : " + @($boards).Count)
Write-Host ("Renode count       : " + @($renodes).Count)

if(@($boards).Count -le 1) {
    Write-Host "[ OK ] At most one VirtualSTM32 GUI is running." -ForegroundColor Green
} else {
    Write-Host "[FAIL] More than one VirtualSTM32 GUI is running." -ForegroundColor Red
}

Write-Host ""
Write-Host "--- processes ---" -ForegroundColor Yellow

@($boards) + @($renodes) |
    Select-Object Name,ProcessId,ParentProcessId,ExecutablePath |
    Format-Table -AutoSize

Write-Host ""
Write-Host "--- backend ports ---" -ForegroundColor Yellow

foreach($port in @(3333,33334,33335)) {
    $listener = Get-NetTCPConnection `
        -LocalPort $port `
        -State Listen `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if($listener) {
        Write-Host ("[LISTEN] :{0} pid={1}" -f $port,$listener.OwningProcess)
    } else {
        Write-Host ("[FREE]   :{0}" -f $port) -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Expected replacement test:" -ForegroundColor Cyan
Write-Host "  1. Start board A and wait for BACKEND green."
Write-Host "  2. Without closing A, start the same VirtualSTM32.exe again."
Write-Host "  3. A should close automatically."
Write-Host "  4. B should then open/connect and become green."
Write-Host "  5. There should never remain two steady-state GUI/backend instances."
