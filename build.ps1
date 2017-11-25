﻿param(
    [string]$Version = $null,
    [switch]$Install,
    [switch]$Clean,
    [switch]$NoChocoPackage,
    [switch]$PullTranslations
)
$ErrorActionPreference = "Stop"

function init {
    if ($removeOld) {
        "Removing older builds"
        Remove-Item -Recurse (Split-path $buildDir) -ea Ignore
    }

    mkdir -Force $buildDir | Out-Null
    Copy-Item -Recurse $modulePath $buildDir
}

function CreateManifest {
    "Creating module manifest"
    $params = @{
        ModulePath = $modulePath
        Version    = $Version -split '\-' | Select-Object -first 1
    }

    & $PSScriptRoot/scripts/Create-ModuleManifest.ps1 @params
}

function CreateHelp {
    "Creating module help"
    $helpDir = "$PSScriptRoot/docs/en"

    Get-ChildItem $modulePath/public/*.ps1 -Recurse | ForEach-Object {
        & $PSScriptRoot/scripts/Extract-Description.ps1 -scriptFile $_.Fullname -outDirectory $helpDir
    }

    $helpDir = Split-Path -Parent $helpDir

    if (Test-Path Env:\APPVEYOR) {
        "& tx push -s" | Invoke-Expression
    }

    if ((Test-Path Env:\APPVEYOR) -or $PullTranslations) {
        "& tx pull -a --minimum-perc=60" | Invoke-Expression
    }

    & $PSScriptRoot/scripts/Create-HelpFiles.ps1 -docsDirectory $helpDir -buildDirectory $modulePath
}

if ($Clean) { git clean -Xfd -e vars.ps1; return }
if (!$Version) {
    Write-Verbose "Finding installed GitVersion executable"
    $gitVersion = Get-Command GitVersion.exe | ForEach-Object Source
    if ($env:APPVEYOR -eq $true) {
        $cmd = ". '$gitVersion' /output buildserver"
        Write-Information "Running $cmd"
        $cmd | Invoke-Expression
    }
    $cmd = ". '$gitVersion' /output json /showvariable NuGetVersionV2"
    Write-Verbose "Running $cmd"
    Write-Information "Calculating version using gitversion"
    $Version = $cmd | Invoke-Expression
    Write-Information "Version found: $Version"
}

$modulePath = "$PSScriptRoot/Wormies-AU-Helpers"
$moduleName = Split-Path -Leaf $modulePath
$buildDir = "$PSScriptRoot/.build/$version"
#$installerPath = "$PSScriptRoot/install.ps1"
$removeOld = $true

"`n==| Building $moduleName $version`n"
init

$modulePath = "$buildDir/$moduleName"
CreateManifest
CreateHelp
