param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Get-Location).Path
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

$renode = Join-Path $ProjectRoot "third_party\renode\renode.exe"
if(!(Test-Path $renode)) {
    throw "Renode not found: $renode"
}

$tempDir = Join-Path $env:TEMP "VirtualSTM32\smoke"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$resc   = Join-Path $tempDir "smoke.resc"
$log    = Join-Path $tempDir "smoke-runtime.log"
$stdout = Join-Path $tempDir "smoke-stdout.log"
$stderr = Join-Path $tempDir "smoke-stderr.log"

Remove-Item $log,$stdout,$stderr -Force -ErrorAction SilentlyContinue

@"
mach create "vstm32-smoke"
logFile @smoke-runtime.log
log "VSTM32_SMOKE_OK"
quit
"@ | Set-Content -Path $resc -Encoding ASCII

Write-Host "=== Renode CLI startup smoke test v3 ===" -ForegroundColor Cyan
Write-Host "Renode:  $renode"
Write-Host "Workdir: $tempDir"
Write-Host ""

Push-Location $tempDir
try {
    $p = Start-Process `
        -FilePath $renode `
        -ArgumentList @(
            "-p",
            "--disable-gui",
            "-e",
            '"include @smoke.resc"'
        ) `
        -WorkingDirectory $tempDir `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru

    if(-not $p.WaitForExit(10000)) {
        try { Stop-Process -Id $p.Id -Force } catch {}
        throw "Renode smoke test timed out after 10 seconds."
    }
}
finally {
    Pop-Location
}

$stdoutText = ""
$stderrText = ""
$logText = ""

Write-Host "--- stdout ---" -ForegroundColor Yellow
if(Test-Path $stdout) {
    $stdoutText = Get-Content $stdout -Raw -ErrorAction SilentlyContinue
    if([string]::IsNullOrWhiteSpace($stdoutText)) {
        Write-Host "<empty>"
    } else {
        Write-Host $stdoutText
    }
} else {
    Write-Host "<missing>"
}

Write-Host ""
Write-Host "--- stderr ---" -ForegroundColor Yellow
if(Test-Path $stderr) {
    $stderrText = Get-Content $stderr -Raw -ErrorAction SilentlyContinue
    if([string]::IsNullOrWhiteSpace($stderrText)) {
        Write-Host "<empty>"
    } else {
        Write-Host $stderrText
    }
} else {
    Write-Host "<missing>"
}

Write-Host ""
Write-Host "--- runtime log (informational only) ---" -ForegroundColor Yellow
if(Test-Path $log) {
    $logText = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if([string]::IsNullOrWhiteSpace($logText)) {
        Write-Host "<empty>"
    } else {
        Write-Host $logText
    }
} else {
    Write-Host "<missing>"
}

# The explicit script marker in stdout is the authoritative smoke-test result.
if($stdoutText -notmatch "Including script\(s\):" -or
   $stdoutText -notmatch "VSTM32_SMOKE_OK") {
    throw "FAIL: Renode did not prove execution of smoke.resc. Expected startup include + VSTM32_SMOKE_OK in stdout."
}

Write-Host ""
Write-Host "[ OK ] Renode executed smoke.resc through -e include." -ForegroundColor Green
if(Test-Path $log) {
    Write-Host "[ OK ] logFile sink was also created." -ForegroundColor Green
} else {
    Write-Host "[WARN] logFile sink was not created; this does not invalidate .resc execution." -ForegroundColor Yellow
}
