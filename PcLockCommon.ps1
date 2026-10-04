if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $script:PcLockRootPath = Split-Path -Parent $PSCommandPath
    } elseif (-not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
        $script:PcLockRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $script:PcLockRootPath = (Get-Location).Path
    }
} else {
    $script:PcLockRootPath = $PSScriptRoot
}

$script:PcLockDefaultConfigPath = Join-Path $script:PcLockRootPath "config.json"
$script:PcLockLogPath = Join-Path $script:PcLockRootPath "pc-lock.log"

function Write-PcLockLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    try {
        Add-Content -LiteralPath $script:PcLockLogPath -Value $line -Encoding UTF8
    } catch {
        # Console logging is enough if the log file cannot be written.
    }
}

function Get-ObjectProperty {
    param(
        [Parameter(Mandatory = $false)]
        $Value,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Value) {
        return $null
    }

    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Read-PcLockConfig {
    param(
        [string]$Path = $script:PcLockDefaultConfigPath
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config not found: $Path. Run Setup-PcLockPhone.ps1 first."
    }

    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Save-PcLockConfig {
    param(
        [Parameter(Mandatory = $true)]
        $Config,

        [string]$Path = $script:PcLockDefaultConfigPath
    )

    $folder = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Convert-PcLockSecureStringToPlainText {
    param(
        [Parameter(Mandatory = $true)]
        [securestring]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Protect-PcLockBotToken {
    param(
        [Parameter(Mandatory = $true)]
        [securestring]$Token
    )

    return (ConvertFrom-SecureString -SecureString $Token)
}

function Unprotect-PcLockBotToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProtectedToken
    )

    $secureToken = ConvertTo-SecureString -String $ProtectedToken
    return Convert-PcLockSecureStringToPlainText -SecureString $secureToken
}

function Invoke-TelegramApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [hashtable]$Body = @{},

        [int]$TimeoutSec = 35
    )

    $uri = "https://api.telegram.org/bot$Token/$Method"
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $uri `
        -Body $Body `
        -ContentType "application/x-www-form-urlencoded" `
        -TimeoutSec $TimeoutSec `
        -ErrorAction Stop

    $ok = Get-ObjectProperty -Value $response -Name "ok"
    if ($null -ne $ok -and -not $ok) {
        $description = Get-ObjectProperty -Value $response -Name "description"
        throw "Telegram API returned ok=false. $description"
    }

    return $response
}

function Get-PcLockKeyboardJson {
    return '{"keyboard":[[{"text":"PC sperren"}]],"resize_keyboard":true,"one_time_keyboard":false}'
}

function Send-TelegramMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ChatId,

        [Parameter(Mandatory = $true)]
        [string]$Text,

        [switch]$WithKeyboard
    )

    $body = @{
        chat_id = $ChatId
        text = $Text
    }

    if ($WithKeyboard) {
        $body.reply_markup = Get-PcLockKeyboardJson
    }

    Invoke-TelegramApi -Token $Token -Method "sendMessage" -Body $body -TimeoutSec 30 | Out-Null
}

function Invoke-PcLock {
    if (-not ("PcLockNative" -as [type])) {
        Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;

public static class PcLockNative
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool LockWorkStation();
}
"@
    }

    $locked = [PcLockNative]::LockWorkStation()
    if (-not $locked) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "LockWorkStation failed. Win32Error=$errorCode"
    }
}
