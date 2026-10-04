[CmdletBinding()]
param(
    [string]$ConfigPath,
    [int]$LongPollSeconds = 25
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

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $ScriptDir "config.json"
}

. (Join-Path $ScriptDir "PcLockCommon.ps1")

function Test-PcLockCommand {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $normalized = $Text.Trim().ToLowerInvariant()
    return (
        $normalized -eq "/lock" -or
        $normalized -eq "pc sperren" -or
        $normalized -eq "sperren" -or
        $normalized -eq "lock" -or
        $normalized -match "^/lock@\w+$"
    )
}

function Test-PcHelpCommand {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $normalized = $Text.Trim().ToLowerInvariant()
    return (
        $normalized -eq "/start" -or
        $normalized -eq "/help" -or
        $normalized -match "^/start@\w+$" -or
        $normalized -match "^/help@\w+$"
    )
}

$config = Read-PcLockConfig -Path $ConfigPath
$protectedToken = Get-ObjectProperty -Value $config -Name "BotTokenProtected"
$allowedChatId = Get-ObjectProperty -Value $config -Name "AllowedChatId"

if ([string]::IsNullOrWhiteSpace($protectedToken)) {
    throw "Missing BotTokenProtected in config. Run Setup-PcLockPhone.ps1 again."
}

if ([string]::IsNullOrWhiteSpace($allowedChatId)) {
    throw "Missing AllowedChatId in config. Run Setup-PcLockPhone.ps1 and pair your Telegram chat."
}

try {
    $token = Unprotect-PcLockBotToken -ProtectedToken $protectedToken
} catch {
    Write-PcLockLog ("Could not decrypt bot token. Run Setup-PcLockPhone.ps1 again in the same Windows user that starts the bot. Error: {0}" -f $_.Exception.Message)
    throw
}
$mutexName = "Local\PcLockFromPhone"
try {
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    $hasMutex = $mutex.WaitOne(0)
} catch {
    Write-PcLockLog ("Could not create listener mutex. Error: {0}" -f $_.Exception.Message)
    throw
}

if (-not $hasMutex) {
    Write-PcLockLog "PcLockBot is already running. This instance exits."
    exit 0
}

try {
    Invoke-TelegramApi -Token $token -Method "deleteWebhook" -Body @{ drop_pending_updates = "false" } -TimeoutSec 30 | Out-Null
} catch {
    Write-PcLockLog ("Could not delete Telegram webhook. Retrying anyway: {0}" -f $_.Exception.Message)
}

Write-PcLockLog "PcLockBot is running. Press Ctrl+C to stop."

while ($true) {
    try {
        $config = Read-PcLockConfig -Path $ConfigPath
        $lastUpdateId = Get-ObjectProperty -Value $config -Name "LastUpdateId"
        if ($null -eq $lastUpdateId) {
            $lastUpdateId = 0
        }

        $updates = Invoke-TelegramApi `
            -Token $token `
            -Method "getUpdates" `
            -Body @{
                offset = ([int64]$lastUpdateId + 1)
                timeout = $LongPollSeconds
                allowed_updates = '["message"]'
            } `
            -TimeoutSec ($LongPollSeconds + 10)

        foreach ($update in @((Get-ObjectProperty -Value $updates -Name "result"))) {
            $updateId = [int64](Get-ObjectProperty -Value $update -Name "update_id")
            $config.LastUpdateId = $updateId
            Save-PcLockConfig -Config $config -Path $ConfigPath

            $message = Get-ObjectProperty -Value $update -Name "message"
            $text = Get-ObjectProperty -Value $message -Name "text"
            $chat = Get-ObjectProperty -Value $message -Name "chat"
            $chatId = [string](Get-ObjectProperty -Value $chat -Name "id")

            if ([string]::IsNullOrWhiteSpace($chatId)) {
                continue
            }

            if ($chatId -ne [string]$allowedChatId) {
                Write-PcLockLog ("Ignored message from unpaired chat id {0}." -f $chatId)
                continue
            }

            if (Test-PcLockCommand -Text $text) {
                Write-PcLockLog "Lock command received from paired Telegram chat."
                Send-TelegramMessage -Token $token -ChatId $chatId -Text "Sperre PC jetzt..."
                Invoke-PcLock
                continue
            }

            if (Test-PcHelpCommand -Text $text) {
                Send-TelegramMessage -Token $token -ChatId $chatId -Text "Bereit. Tippe auf 'PC sperren'." -WithKeyboard
                continue
            }

            Send-TelegramMessage -Token $token -ChatId $chatId -Text "Bereit. Tippe auf 'PC sperren'." -WithKeyboard
        }
    } catch {
        Write-PcLockLog ("Error: {0}. Retry in 5 seconds." -f $_.Exception.Message)
        Start-Sleep -Seconds 5
    }
}
