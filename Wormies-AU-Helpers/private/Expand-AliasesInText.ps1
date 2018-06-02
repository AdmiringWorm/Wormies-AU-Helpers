﻿function Expand-AliasesInText {
    [cmdletbinding(SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$text,
        [Parameter(Mandatory = $true)]
        [hashtable]$aliases,
        $ParserErrors = $null,
        [string[]]$whitelist = @())

    $tokens = [System.Management.Automation.PSParser]::Tokenize($text, [ref]$ParserErrors)
    $commands = $tokens | Where-Object Type -eq "Command" | Sort-Object Start -Descending

    foreach ($cmd in $commands) {
        $key = $cmd.Content
        if ($aliases.Contains($key) -and !$whitelist.Contains($key)) {
            $alias = $aliases.$key
            $old = $cmd.Content
            $new = $alias.ResolvedCommandName
            if ($PSCmdlet.ShouldProcess($old, "Expand alias to $new")) {
                $text = $text.Remove($cmd.Start, $cmd.Content.Length).Insert($cmd.Start, $new)
            }
        }
    }

    return $text
}
