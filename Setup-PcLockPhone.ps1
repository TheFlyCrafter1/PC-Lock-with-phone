[CmdletBinding()]
param(
    [string]$ConfigPath,
    [int]$PairTimeoutSeconds = 180
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

Write-Host ""
Write-Host "PC Lock Phone Setup"
Write-Host "1. Open Telegram on your phone."
Write-Host "2. Write to @BotFather: /newbot"
Write-Host "3. Copy the bot token and paste it here."
Write-Host ""

$secureToken = Read-Host "Telegram bot token" -AsSecureString
$plainToken = Convert-PcLockSecureStringToPlainText -SecureString $secureToken
$protectedToken = Protect-PcLockBotToken -Token $secureToken

Write-Host "Checking bot token..."
Invoke-TelegramApi -Token $plainToken -Method "deleteWebhook" -Body @{ drop_pending_updates = "true" } -TimeoutSec 30 | Out-Null
$me = Invoke-TelegramApi -Token $plainToken -Method "getMe" -Body @{} -TimeoutSec 30
$botUsername = (Get-ObjectProperty -Value (Get-ObjectProperty -Value $me -Name "result") -Name "username")

$config = [ordered]@{
    BotTokenProtected = $protectedToken
    BotUsername = $botUsername
    AllowedChatId = $null
    LastUpdateId = 0
    CreatedAt = (Get-Date).ToString("o")
}
Save-PcLockConfig -Config $config -Path $ConfigPath

Write-Host ""
Write-Host "OK. Now open Telegram and send /pair to your new bot."
if ($botUsername) {
    Write-Host ("Bot: @{0}" -f $botUsername)
}
Write-Host ("Waiting up to {0} seconds..." -f $PairTimeoutSeconds)

$deadline = (Get-Date).AddSeconds($PairTimeoutSeconds)
$offset = 0

while ((Get-Date) -lt $deadline) {
    $remaining = [Math]::Max(1, [int]($deadline - (Get-Date)).TotalSeconds)
    $timeout = [Math]::Min(15, $remaining)
    $updates = Invoke-TelegramApi `
        -Token $plainToken `
        -Method "getUpdates" `
        -Body @{
            offset = $offset
            timeout = $timeout
            allowed_updates = '["message"]'
        } `
        -TimeoutSec ($timeout + 10)

    foreach ($update in @((Get-ObjectProperty -Value $updates -Name "result"))) {
        $updateId = [int64](Get-ObjectProperty -Value $update -Name "update_id")
        $offset = $updateId + 1

        $message = Get-ObjectProperty -Value $update -Name "message"
        $text = Get-ObjectProperty -Value $message -Name "text"
        $chat = Get-ObjectProperty -Value $message -Name "chat"
        $chatId = Get-ObjectProperty -Value $chat -Name "id"

        if ($null -eq $text -or $null -eq $chatId) {
            continue
        }

        if ($text.Trim().ToLowerInvariant() -eq "/pair") {
            $config.AllowedChatId = [string]$chatId
            $config.LastUpdateId = $updateId
            Save-PcLockConfig -Config $config -Path $ConfigPath

            Send-TelegramMessage `
                -Token $plainToken `
                -ChatId ([string]$chatId) `
                -Text "Gekoppelt. Tippe auf 'PC sperren', dann sperrt Windows diesen PC." `
                -WithKeyboard

            Write-Host ""
            Write-Host ("Paired with Telegram chat id: {0}" -f $chatId)
            Write-Host "Setup done. Start the listener with Start-PcLockBot.ps1."
            exit 0
        }
    }
}

throw "Pairing timed out. Run setup again and send /pair to the bot while it waits."
