[CmdletBinding()]
param(
    [string]$TaskName = "PcLockFromPhone"
)

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
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupVbsPath = Join-Path $startupFolder "$TaskName.vbs"

try {
    $action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $arguments -WorkingDirectory $ScriptDir
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Days 365)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Locks this PC from a paired Telegram button." `
        -Force | Out-Null

    Start-ScheduledTask -TaskName $TaskName
    Write-Host ("Autostart installed and started as scheduled task: {0}" -f $TaskName)
    exit 0
} catch {
    Write-Host ("Scheduled task failed, using Startup folder fallback: {0}" -f $_.Exception.Message)
}

$escapedPowerShell = $powerShellExe.Replace('"', '""')
$escapedScript = $scriptPath.Replace('"', '""')
$vbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run """$escapedPowerShell"" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$escapedScript""", 0, False
"@

Set-Content -LiteralPath $startupVbsPath -Value $vbs -Encoding ASCII
Start-Process -FilePath "wscript.exe" -ArgumentList "`"$startupVbsPath`"" -WindowStyle Hidden
Write-Host ("Autostart installed and started via Startup folder: {0}" -f $startupVbsPath)
