function Get-Vstm32CMakeGenerators {
    if(-not (Get-Command cmake -ErrorAction SilentlyContinue)) { return @() }
    $caps = (& cmake -E capabilities | Out-String | ConvertFrom-Json)
    return @($caps.generators | ForEach-Object { $_.name })
}

function Get-Vstm32VsWhere {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"),
        (Join-Path $env:ProgramFiles "Microsoft Visual Studio\Installer\vswhere.exe")
    )
    foreach($p in $candidates) {
        if($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Get-Vstm32VisualStudioInstallations {
    $vswhere = Get-Vstm32VsWhere
    if(-not $vswhere) { return @() }
    try {
        $raw = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json -utf8
        if(-not $raw) { return @() }
        return @($raw | Out-String | ConvertFrom-Json)
    } catch {
        return @()
    }
}

function Select-Vstm32VisualStudioGenerator {
    $generators = Get-Vstm32CMakeGenerators
    $installations = @(Get-Vstm32VisualStudioInstallations | Sort-Object {
        try { [version]$_.installationVersion } catch { [version]'0.0' }
    } -Descending)

    foreach($vs in $installations) {
        $major = 0
        try { $major = ([version]$vs.installationVersion).Major } catch {}
        $candidate = switch($major) {
            18 { "Visual Studio 18 2026" }
            17 { "Visual Studio 17 2022" }
            default { $null }
        }
        if($candidate -and ($generators -contains $candidate)) {
            return [pscustomobject]@{
                Generator = $candidate
                InstallationPath = $vs.installationPath
                InstallationVersion = $vs.installationVersion
                DisplayName = $vs.displayName
            }
        }
    }
    return $null
}
