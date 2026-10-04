[CmdletBinding()]
param(
    [int]$WaitSeconds = 60
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

. (Join-Path $ScriptDir "PcLockCommon.ps1")

function Test-PcLockCommand {
    param([string]$Text)

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

Write-Host "PcLock live diagnosis"
Write-Host ("Folder: {0}" -f $ScriptDir)

$configPath = Join-Path $ScriptDir "config.json"
$config = Read-PcLockConfig -Path $configPath
$allowedChatId = [string](Get-ObjectProperty -Value $config -Name "AllowedChatId")
$lastUpdateId = Get-ObjectProperty -Value $config -Name "LastUpdateId"

if ([string]::IsNullOrWhiteSpace($allowedChatId)) {
    throw "No paired Telegram chat found. Run Setup-PcLockPhone.ps1 first."
}

Write-Host ("AllowedChatId: {0}" -f $allowedChatId)

try {
    $token = Unprotect-PcLockBotToken -ProtectedToken $config.BotTokenProtected
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Token decrypted to an empty value."
    }
    Write-Host "Token decrypt: OK"
} catch {
    Write-Host ("Token decrypt: FAILED - {0}" -f $_.Exception.Message)
    throw
}

try {
    $me = Invoke-TelegramApi -Token $token -Method "getMe" -Body @{} -TimeoutSec 20
    $botUser = Get-ObjectProperty -Value (Get-ObjectProperty -Value $me -Name "result") -Name "username"
    Write-Host ("Telegram getMe: OK @{0}" -f $botUser)
} catch {
    Write-Host ("Telegram getMe: FAILED - {0}" -f $_.Exception.Message)
    throw
}

Send-TelegramMessage `
    -Token $token `
    -ChatId $allowedChatId `
    -Text "Diagnose laeuft. Druecke jetzt bitte 'PC sperren'. Wenn der Befehl ankommt, sperre ich diesen PC." `
    -WithKeyboard

Write-Host ("Test message sent. Waiting {0} seconds for the button..." -f $WaitSeconds)
Write-Host "Leave this PowerShell window open during the test."

$deadline = (Get-Date).AddSeconds($WaitSeconds)
if ($null -eq $lastUpdateId) {
    $lastUpdateId = 0
}

while ((Get-Date) -lt $deadline) {
    $remaining = [Math]::Max(1, [int]($deadline - (Get-Date)).TotalSeconds)
    $timeout = [Math]::Min(10, $remaining)

    $updates = Invoke-TelegramApi `
        -Token $token `
        -Method "getUpdates" `
        -Body @{
            offset = ([int64]$lastUpdateId + 1)
            timeout = $timeout
            allowed_updates = '["message"]'
        } `
        -TimeoutSec ($timeout + 10)

    foreach ($update in @((Get-ObjectProperty -Value $updates -Name "result"))) {
        $updateId = [int64](Get-ObjectProperty -Value $update -Name "update_id")
        $lastUpdateId = $updateId
        $config.LastUpdateId = $updateId
        Save-PcLockConfig -Config $config -Path $configPath

        $message = Get-ObjectProperty -Value $update -Name "message"
        $text = [string](Get-ObjectProperty -Value $message -Name "text")
        $chat = Get-ObjectProperty -Value $message -Name "chat"
        $chatId = [string](Get-ObjectProperty -Value $chat -Name "id")

        Write-Host ("Received message from chat {0}: {1}" -f $chatId, $text)

        if ($chatId -ne $allowedChatId) {
            Write-Host "Message ignored because it is not from the paired chat."
            continue
        }

        if (Test-PcLockCommand -Text $text) {
            Send-TelegramMessage -Token $token -ChatId $allowedChatId -Text "Befehl ist angekommen. Sperre diesen PC jetzt..."
            Write-Host "Lock command received. Locking now."
            Start-Sleep -Seconds 1
            Invoke-PcLock
            exit 0
        }

        Send-TelegramMessage -Token $token -ChatId $allowedChatId -Text ("Nachricht kam an, aber war kein Sperrbefehl: {0}" -f $text) -WithKeyboard
    }
}

Write-Host ""
Write-Host "No lock command arrived during diagnosis."
Write-Host "If you pressed the button, another PC is probably polling the same bot token, or the button belongs to a different bot/chat."
Write-Host "Use one separate Telegram bot token per PC, then run setup again on this PC."
