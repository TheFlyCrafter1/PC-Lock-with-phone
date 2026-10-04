[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

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

$currentPid = $PID
$escapedDir = $ScriptDir
$found = $false
$checked = $false

try {
    $processes = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction Stop |
        Where-Object {
            $_.ProcessId -ne $currentPid -and
            $_.CommandLine -and
            $_.CommandLine -like "*$escapedDir*" -and
            ($_.CommandLine -like "*Start-PcLockBot.ps1*" -or $_.CommandLine -like "*PcLockBot.ps1*")
        }
    $checked = $true

    foreach ($process in $processes) {
        $found = $true
        Write-Host ("Stopping PcLockBot process PID {0}" -f $process.ProcessId)
        Stop-Process -Id $process.ProcessId -Force -ErrorAction Continue
    }
} catch {
    Write-Host ("Could not inspect/stop listener processes: {0}" -f $_.Exception.Message)
}

if ($checked -and -not $found) {
    Write-Host "No running PcLockBot process found for this folder."
}
