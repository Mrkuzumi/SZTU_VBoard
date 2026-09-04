param(
    [string]$Version = "1.16.1",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if(-not $env:LOCALAPPDATA) {
    throw "LOCALAPPDATA is not available."
}

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$CacheRoot = Join-Path $env:LOCALAPPDATA "VirtualSTM32"
$InstallDir = Join-Path $CacheRoot ("renode\" + $Version)
$RenodeExe = Join-Path $InstallDir "renode.exe"

if((Test-Path $RenodeExe) -and -not $Force) {
    $env:RENODE_PATH = $RenodeExe
    [Environment]::SetEnvironmentVariable(
        "RENODE_PATH",
        $RenodeExe,
        "User"
    )

    Write-Host "[ OK ] Renode already installed:" -ForegroundColor Green
    Write-Host "       $RenodeExe"
    exit 0
}

# If this is an old development checkout that still bundles Renode,
# reuse it instead of downloading another copy.
$BundledExe = Join-Path $ProjectRoot "third_party\renode\renode.exe"

if((Test-Path $BundledExe) -and -not $Force) {
    $env:RENODE_PATH = (Resolve-Path $BundledExe).Path
    [Environment]::SetEnvironmentVariable(
        "RENODE_PATH",
        $env:RENODE_PATH,
        "User"
    )

    Write-Host "[ OK ] Using project-local Renode for this checkout:" -ForegroundColor Green
    Write-Host "       $env:RENODE_PATH"
    Write-Host ""
    Write-Host "Run tools\repo_slim.ps1 -Apply -MoveRenodeToCache later to move it out of the repository."
    exit 0
}

if($Version -ne "1.16.1") {
    throw "This bootstrap currently pins and verifies Renode 1.16.1 only."
}

$Url = "https://github.com/renode/renode/releases/download/v1.16.1/renode-1.16.1.windows-portable-dotnet.zip"
$ExpectedSha256 = "D09B7934CFD560CD06BDE8F131EF78F521F10D423D5AAC6096F2A583224AEB3E"

$TempRoot = Join-Path $env:TEMP ("VirtualSTM32-Renode-" + [Guid]::NewGuid().ToString("N"))
$Zip = Join-Path $TempRoot "renode.zip"
$Extract = Join-Path $TempRoot "extract"

New-Item -ItemType Directory -Force -Path $TempRoot,$Extract | Out-Null

try {
    Write-Host "Downloading Renode $Version portable runtime..." -ForegroundColor Cyan
    Write-Host "This is a one-time download and is cached outside the repository."

    Invoke-WebRequest `
        -Uri $Url `
        -OutFile $Zip `
        -UseBasicParsing

    $ActualHash = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToUpperInvariant()

    if($ActualHash -ne $ExpectedSha256) {
        throw "Renode SHA256 mismatch.`nExpected: $ExpectedSha256`nActual:   $ActualHash"
    }

    Write-Host "[ OK ] SHA256 verified." -ForegroundColor Green

    Expand-Archive -Path $Zip -DestinationPath $Extract -Force

    $FoundExe = Get-ChildItem `
        -Path $Extract `
        -Filter "renode.exe" `
        -File `
        -Recurse |
        Select-Object -First 1

    if(-not $FoundExe) {
        throw "renode.exe was not found after extracting the official archive."
    }

    if(Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    # Copy the complete directory containing renode.exe so all sibling
    # runtime files stay together.
    Copy-Item `
        (Join-Path $FoundExe.Directory.FullName "*") `
        $InstallDir `
        -Recurse `
        -Force

    if(!(Test-Path $RenodeExe)) {
        throw "Runtime extraction finished, but $RenodeExe is missing."
    }

    $env:RENODE_PATH = $RenodeExe
    [Environment]::SetEnvironmentVariable(
        "RENODE_PATH",
        $RenodeExe,
        "User"
    )

    Write-Host ""
    Write-Host "[ OK ] Renode installed:" -ForegroundColor Green
    Write-Host "       $RenodeExe"
}
finally {
    Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
