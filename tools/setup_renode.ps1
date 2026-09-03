$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Dst = Join-Path $Root "third_party\renode"
$Version = "1.16.1"
$Zip = Join-Path $env:TEMP "renode-$Version.windows-portable-dotnet.zip"
$Url = "https://github.com/renode/renode/releases/download/v$Version/renode-$Version.windows-portable-dotnet.zip"
$Sha256 = "d09b7934cfd560cd06bde8f131ef78f521f10d423d5aac6096f2a583224aeb3e"

Write-Host "Downloading Renode $Version Windows portable build..."
Invoke-WebRequest -Uri $Url -OutFile $Zip
$Actual = (Get-FileHash -Path $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Sha256) {
    throw "Renode SHA256 mismatch. Expected $Sha256, got $Actual"
}

if (Test-Path $Dst) { Remove-Item -Recurse -Force $Dst }
New-Item -ItemType Directory -Force -Path $Dst | Out-Null
Expand-Archive -Path $Zip -DestinationPath $Dst -Force

# The portable archive may contain one top-level directory. Normalize so
# third_party\renode\renode.exe is always the path used by VirtualSTM32.
$Exe = Get-ChildItem -Path $Dst -Filter renode.exe -Recurse | Select-Object -First 1
if (!$Exe) { throw "renode.exe was not found after extraction" }
if ($Exe.Directory.FullName -ne $Dst) {
    $Inner = $Exe.Directory.FullName
    Copy-Item -Path (Join-Path $Inner '*') -Destination $Dst -Recurse -Force
}
if (!(Test-Path (Join-Path $Dst 'renode.exe'))) {
    throw "Renode extraction finished, but third_party\renode\renode.exe is still missing"
}
Write-Host "Renode $Version installed to $Dst" -ForegroundColor Green
