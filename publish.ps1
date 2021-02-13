﻿#requires -version 5

$ErrorActionPreference = 'Stop'

function Test-Var {
    $input | ForEach-Object { if (!(Test-Path Env:$_)) { throw "Environment Variable $_ must be set" } }

    $params = @{
        Path = $modulePath
    }
}

function Publish-PSGallery {
    "Publishing to Powershell Gallery"

    "NUGET_APIKEY" | Test-Var

    $params = @{
        Path        = $modulePath
        NuGetApiKey = $Env:NUGET_APIKEY
    }
    Publish-Module @params
}

function Publish-Chocolatey {
    "Publishing to Chocolatey"

    "CHOCOLATEY_APIKEY" | Test-Var
    choco push (REsolve-path $buildDir/*.$Version.nupkg) --api-key $Env:CHOCOLATEY_APIKEY
    if ($LASTEXITCODE) { throw "Chocolatey push failed with exit code: $LastExitCode" }
}

function Publish-MyGet {
    "Publishing to MyGet"

    "MYGET_APIKEY" | Test-Var
    choco push (Resolve-Path $buildDir/*.$Version.nupkg) --api-key=$Env:MYGET_APIKEY --source=https://www.myget.org/F/wormie-nugets/api/v2/package
}

if (!(Test-Path Env:\APPVEYOR)) { throw "This script can only be run on appveyor" }

Write-Verbose "Finding installed GitVersion executable"
$useDotnet = $false
$gitVersion = Get-Command GitVersion.exe -ea 0 | ForEach-Object Source
if (!$gitVersion) {
    $gitVersion = "gitversion"
    $useDotnet = $true
}

$cmd = if ($useDotnet) { ". dotnet" } else { "." }
$cmd = "$cmd '$gitVersion' /output json /showvariable NuGetVersionV2"
Write-Verbose "Running $cmd"
Write-Information "Calculating version using gitversion"
$Version = $cmd | Invoke-Expression
$buildDir = "$PSScriptRoot/.build/$Version"
$moduleName = ".\Wormies-AU-Helpers"
$modulePath = "$buildDir/$moduleName"

$isMainBranch = $Env:APPVEYOR_REPO_BRANCH -eq "master"
$isMainRepo = $Env:APPVEYOR_REPO_NAME -eq "WormieCorp/Wormies-AU-Helpers"
$isTaggedBuild = $Env:APPVEYOR_REPO_TAG -eq "true"
$isPullRequest = ![string]::IsNullOrWhiteSpace($Env:APPVEYOR_PULL_REQUEST_NUMBER)
Write-Information "Version found: $Version"
Write-Information "  Branch used: $isMainBranch"
Write-Information "    Main Repo: $isMainRepo"
Write-Information " Tagged Build: $isTaggedBuild"
Write-Information " Pull Request: $isPullRequest"

if (!$isMainRepo) { Write-Warning "Not running on the main repository, skipping"; return }

if ($isTaggedBuild) {
    & $PSScriptRoot/scripts/Create-GithubRelease.ps1 -version $Version -publishRelease
}
elseif ($isMainBranch -and !$isPullRequest) {
    & $PSScriptRoot/scripts/Draft-GithubRelease.ps1 -version $Version
}

& $PSScriptRoot/chocolatey/Build-Package.ps1

& $PSScriptRoot/scripts/Generate-MarkdownDocs.ps1 -PathToModule $modulePath

if ($isTaggedBuild) {
    Publish-PSGallery
    Publish-MyGet
    Publish-Chocolatey
}
elseif (!$isMainBranch -and !$isPullRequest) {
    Publish-MyGet
}

Push-Location $PSScriptRoot/docs
& $PSScriptRoot/docs/build.ps1 -Target AppVeyor -Verbosity Diagnostic
Pop-Location
