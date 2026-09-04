param()

$root = Split-Path $PSScriptRoot -Parent

Write-Host "=== Patch 032 cleanup check ===" -ForegroundColor Cyan

$checks = @(
    @{ Label="ResetButtonPeripheral.h removed"; Path=(Join-Path $root "src\peripherals\ResetButtonPeripheral.h"); ShouldExist=$false },
    @{ Label="ResetButtonPeripheral.cpp removed"; Path=(Join-Path $root "src\peripherals\ResetButtonPeripheral.cpp"); ShouldExist=$false },
    @{ Label="reset_up.bmp removed"; Path=(Join-Path $root "assets\reset_up.bmp"); ShouldExist=$false },
    @{ Label="reset_down.bmp removed"; Path=(Join-Path $root "assets\reset_down.bmp"); ShouldExist=$false }
)

foreach($c in $checks) {
    $exists = Test-Path $c.Path
    if($exists -eq $c.ShouldExist) {
        Write-Host ("[ OK ] " + $c.Label) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] " + $c.Label) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "--- source references containing RESET experiment names ---" -ForegroundColor Yellow

$hits = Get-ChildItem (Join-Path $root "src") -Recurse -File -Include *.h,*.cpp |
    Select-String -Pattern 'ResetButtonPeripheral|ConsumeResetRequest|ResyncInputs|VSTM32_RESET_RELOAD_CURRENT_FIRMWARE'

if($hits) {
    $hits | Select-Object Path,LineNumber,Line | Format-Table -Wrap -AutoSize
} else {
    Write-Host "[ OK ] No RESET-experiment references remain." -ForegroundColor Green
}

Write-Host ""
Write-Host "Expected KEY positions:" -ForegroundColor Cyan
Write-Host "  KEY0 PB12 x=320"
Write-Host "  KEY1 PB13 x=465"
Write-Host "  KEY2 PB14 x=610"
Write-Host "  KEY3 PB15 x=755"
Write-Host ""
Write-Host "Keyboard R remains a simulator-only full firmware/backend reload."
