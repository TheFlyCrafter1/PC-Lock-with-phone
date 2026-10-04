[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $ScriptDir = Split-Path -Parent $PSCommandPath
    } elseif (-not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $ScriptDir = (Get-Location).Path
    }
} else {
    $ScriptDir = $PSScriptRoot
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "Stop-PcLockBot.ps1")
Start-Sleep -Seconds 1
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "Start-HiddenNow.ps1")
Start-Sleep -Seconds 3
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "Status-PcLockBot.ps1")
