[CmdletBinding()]
param(
    [string]$TaskName = "PcLockFromPhone"
)

$ErrorActionPreference = "Stop"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupVbsPath = Join-Path $startupFolder "$TaskName.vbs"

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host ("Autostart scheduled task removed: {0}" -f $TaskName)
    } else {
        Write-Host ("Autostart scheduled task not found: {0}" -f $TaskName)
    }
} catch {
    Write-Host ("Could not check/remove scheduled task: {0}" -f $_.Exception.Message)
}

if (Test-Path -LiteralPath $startupVbsPath) {
    Remove-Item -LiteralPath $startupVbsPath -Force
    Write-Host ("Autostart Startup folder file removed: {0}" -f $startupVbsPath)
} else {
    Write-Host ("Autostart Startup folder file not found: {0}" -f $startupVbsPath)
}
