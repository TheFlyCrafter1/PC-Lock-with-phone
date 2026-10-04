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
$logPath = Join-Path $ScriptDir "pc-lock.log"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupVbsPath = Join-Path $startupFolder "$TaskName.vbs"

Write-Host "PcLock status"
Write-Host ("Folder: {0}" -f $ScriptDir)
Write-Host ("Config: {0}" -f (Test-Path -LiteralPath $configPath))

if (Test-Path -LiteralPath $configPath) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        Write-Host ("AllowedChatId: {0}" -f $config.AllowedChatId)
        Write-Host ("LastUpdateId: {0}" -f $config.LastUpdateId)
    } catch {
        Write-Host ("Config read error: {0}" -f $_.Exception.Message)
    }
}

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $task) {
        Write-Host ("Scheduled task: {0} / {1}" -f $task.TaskName, $task.State)
    } else {
        Write-Host "Scheduled task: not found"
    }
} catch {
    Write-Host ("Scheduled task: cannot check ({0})" -f $_.Exception.Message)
}

Write-Host ("Startup fallback: {0}" -f (Test-Path -LiteralPath $startupVbsPath))

try {
    $needle = (Join-Path $ScriptDir "Start-PcLockBot.ps1").Replace("\", "\\")
    $processes = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction Stop |
        Where-Object { $_.CommandLine -and $_.CommandLine -like "*Start-PcLockBot.ps1*" }

    if ($processes) {
        foreach ($process in $processes) {
            Write-Host ("Running process: PID {0}" -f $process.ProcessId)
        }
    } else {
        Write-Host "Running process: not found"
    }
} catch {
    Write-Host ("Running process: cannot check ({0})" -f $_.Exception.Message)
}

if (Test-Path -LiteralPath $logPath) {
    Write-Host ""
    Write-Host "Last log lines:"
    Get-Content -LiteralPath $logPath -Tail 10
} else {
    Write-Host "Log: not found yet"
}
