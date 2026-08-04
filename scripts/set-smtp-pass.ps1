param(
  [Parameter(Mandatory = $true)][string]$EnvFile,
  [Parameter(Mandatory = $true)][string]$SmtpUser,
  [Parameter(Mandatory = $true)][string]$SmtpPass
)

if (-not (Test-Path -LiteralPath $EnvFile)) {
  Write-Error "Missing .env: $EnvFile"
  exit 1
}

$raw = Get-Content -LiteralPath $EnvFile -Raw -Encoding UTF8
$passClean = ($SmtpPass -replace '\s+', '').Trim()
$userClean = $SmtpUser.Trim()

function Set-EnvLine([string]$text, [string]$key, [string]$value) {
  $pattern = "(?m)^" + [regex]::Escape($key) + "=.*$"
  $line = "$key=$value"
  if ($text -match $pattern) {
    return [regex]::Replace($text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $line })
  }
  return $text.TrimEnd() + "`r`n" + $line + "`r`n"
}

$raw = Set-EnvLine $raw 'SMTP_HOST' 'smtp.gmail.com'
$raw = Set-EnvLine $raw 'SMTP_PORT' '587'
$raw = Set-EnvLine $raw 'SMTP_SECURE' 'false'
$raw = Set-EnvLine $raw 'SMTP_USER' $userClean
$raw = Set-EnvLine $raw 'SMTP_PASS' $passClean
$raw = Set-EnvLine $raw 'MAIL_FROM' $userClean
$raw = Set-EnvLine $raw 'SMTP_ALLOW_DEV_FALLBACK' 'false'

Set-Content -LiteralPath $EnvFile -Value $raw -Encoding UTF8 -NoNewline
Write-Host "Da ghi SMTP_USER / SMTP_PASS vao backend/.env"
exit 0
