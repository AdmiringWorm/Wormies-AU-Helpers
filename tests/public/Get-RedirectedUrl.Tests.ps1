﻿Remove-Module wormies-au-helpers -ea ignore
Import-Module "$PSScriptRoot/../../Wormies-AU-Helpers"

Describe "Get-RedirectedUrl" {
    It "Should return redirected url on success" {
        Get-RedirectedUrl "https://chocolatey.org/api/v2/package/chocolatey/0.10.8" | Should Be "https://packages.chocolatey.org/chocolatey.0.10.8.nupkg"
        Get-RedirectedUrl "http://submain.com/download/ghostdoc/pro/registered/" -referer "http://submain.com/download/ghostdoc/pro/" | Should -Match "https://submain.com/download/GhostDocPro_v[\d\.]+.zip"
    }

    It "Should return same url when no redirect happens" {
        Get-RedirectedUrl "https://chocolatey.org/" | Should Be "https://chocolatey.org/"
    }

    It "Should escape urls with spaces in the path" {
        Get-RedirectedUrl "https://electron.authy.com/download?channel=stable&arch=x64&platform=win32&version=latest&product=authy" | Should -Match "\%20"
    }
}
