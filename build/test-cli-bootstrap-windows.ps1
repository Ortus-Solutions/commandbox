$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $repoRoot "build\dist\box.exe"
if (-not (Test-Path $launcher)) {
    throw "Missing launcher: $launcher"
}

$originalEnvironment = @{}
foreach ($name in @("BVM_HOME", "BOXLANG_INSTALL_HOME", "BOXLANG_HOME", "BOX_JAVA_PROPS")) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

function Clear-BoxLangEnvironment {
    foreach ($name in @("BVM_HOME", "BOXLANG_INSTALL_HOME", "BOXLANG_HOME", "BOX_JAVA_PROPS")) {
        [Environment]::SetEnvironmentVariable($name, $null, "Process")
    }
}

function Invoke-LauncherScenario {
    param(
        [string]$Name,
        [string]$LauncherDirectory,
        [string]$InstallHome,
        [string]$PropertyContent
    )

    New-Item -ItemType Directory -Path $LauncherDirectory -Force | Out-Null
    $scenarioLauncher = Join-Path $LauncherDirectory "box.exe"
    Copy-Item $launcher $scenarioLauncher -Force
    if ($PropertyContent) {
        Set-Content -Path (Join-Path $LauncherDirectory "commandbox.properties") -Value $PropertyContent -Encoding ASCII
    }

    Clear-BoxLangEnvironment
    if ($InstallHome) {
        [Environment]::SetEnvironmentVariable("BOXLANG_INSTALL_HOME", $InstallHome, "Process")
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $scenarioLauncher -clidebug version 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode`n$output"
    }
    if ($output -notmatch "CommandBox") {
        throw "$Name did not produce CommandBox output`n$output"
    }
    if ($output -match "\[clidebug\] BoxLang command:.*-clidebug") {
        throw "$Name forwarded -clidebug to BoxLang`n$output"
    }
    if (-not (Test-Path (Join-Path $InstallHome "bin\boxlang.bat"))) {
        throw "$Name did not install BoxLang at $InstallHome`n$output"
    }
    if ($output -notmatch "BoxLang was not detected; installing") {
        throw "$Name did not exercise the installer`n$output"
    }
    Write-Host "PASS: $Name"
}

$root = Join-Path $env:TEMP ("commandbox-cli-bootstrap-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    if ($env:BOXLANG_TEST_JAR) {
        $pathBin = Join-Path $root "path-bin"
        New-Item -ItemType Directory -Path $pathBin | Out-Null
        Set-Content -Path (Join-Path $pathBin "boxlang.bat") -Value "@echo off`r`njava -jar `"$env:BOXLANG_TEST_JAR`" %*" -Encoding ASCII
        $env:PATH = $pathBin + ";" + $env:PATH
    }
    Clear-BoxLangEnvironment

    $pathOutput = & $launcher -clidebug version 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $pathOutput -notmatch "CommandBox") {
        throw "PATH scenario failed with exit code $LASTEXITCODE`n$pathOutput"
    }
    if ($pathOutput -notmatch "BoxLang executable source: PATH") {
        throw "PATH scenario did not use the PATH executable`n$pathOutput"
    }
    Write-Host "PASS: BoxLang already on PATH"

    $envHome = Join-Path $root "env-install"
    Invoke-LauncherScenario "Installer with BOXLANG_INSTALL_HOME" (Join-Path $root "env") $envHome $null

    $propertyHome = Join-Path $root "property-install"
    Invoke-LauncherScenario "Installer with commandbox.properties" (Join-Path $root "property") $propertyHome ("boxlang.install.home=" + $propertyHome)
}
finally {
    foreach ($entry in $originalEnvironment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Process")
    }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}
