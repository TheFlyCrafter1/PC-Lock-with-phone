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

$configPath = Join-Path $ScriptDir "config.json"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "config.json not found. Run Setup-PcLockPhone.ps1 first."
}

$scriptPath = Join-Path $ScriptDir "Start-PcLockBot.ps1"
$powerShellExe = Join-Path $PSHOME "powershell.exe"
$arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $scriptPath

Start-Process `
    -FilePath $powerShellExe `
    -ArgumentList $arguments `
    -WorkingDirectory $ScriptDir `
    -WindowStyle Hidden

Write-Host "PcLockBot started hidden. You can close this PowerShell window now."
Write-Host "For reboot/startup persistence, also run Install-Autostart.ps1 once."
