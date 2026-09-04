param()

Write-Host "=== Patch 034 process cleanup check ===" -ForegroundColor Cyan

Write-Host ""
Write-Host "--- VirtualSTM32 / Renode processes ---" -ForegroundColor Yellow

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -in @("VirtualSTM32.exe","renode.exe")
    } |
    Select-Object Name,ProcessId,ParentProcessId,CommandLine |
    Format-Table -AutoSize

Write-Host ""
Write-Host "--- fixed backend ports ---" -ForegroundColor Yellow

foreach($port in @(3333,33334,33335)) {
    $listener = Get-NetTCPConnection `
        -LocalPort $port `
        -State Listen `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if($listener) {
        Write-Host (
            "[BUSY] :{0} pid={1}" -f
            $port,
            $listener.OwningProcess
        ) -ForegroundColor Yellow
    }
    else {
        Write-Host (
            "[FREE] :{0}" -f $port
        ) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Test procedure:" -ForegroundColor Cyan
Write-Host "  1. Start VirtualSTM32 and confirm backend is green."
Write-Host "  2. Close the GUI with the X button."
Write-Host "  3. Run this script again."
Write-Host ""
Write-Host "After GUI exit the expected result is:"
Write-Host "  - no renode.exe owned by VirtualSTM32"
Write-Host "  - :3333  FREE"
Write-Host "  - :33334 FREE"
Write-Host "  - :33335 FREE"
