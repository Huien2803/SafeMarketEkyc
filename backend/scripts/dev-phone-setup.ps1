# Chay truoc npm run start:dev — tu adb reverse + hien IP LAN
$ErrorActionPreference = 'SilentlyContinue'
$port = 3000

Write-Host ''
Write-Host '========================================'
Write-Host ' SafeMarket - Chuan bi ket noi dien thoai'
Write-Host '========================================'

# Firewall (can Admin — bo qua neu khong du quyen)
$rule = Get-NetFirewallRule -DisplayName 'SafeMarket API 3000' -ErrorAction SilentlyContinue
if (-not $rule) {
  netsh advfirewall firewall add rule name="SafeMarket API 3000" dir=in action=allow protocol=TCP localport=$port | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Host '[OK] Firewall mo cong 3000' }
}

# IP LAN PC
$lan = $null
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -match '^(192\.168\.|10\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
  Sort-Object { if ($_.IPAddress -like '192.168.*') { 0 } else { 1 } } |
  Select-Object -First 1 |
  ForEach-Object { $lan = $_.IPAddress }

if ($lan) {
  Write-Host "[OK] IP may tinh (WiFi): $lan"
  Write-Host "     App goi: http://${lan}:${port}/api"
} else {
  Write-Host '[CANH BAO] Khong tim thay IP LAN — kiem tra WiFi'
}

# adb reverse
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (Test-Path $adb) {
  & $adb start-server 2>$null
  $devices = & $adb devices 2>&1 | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice' }
  if ($devices) {
    & $adb reverse "tcp:${port}" "tcp:${port}" 2>$null
    Write-Host '[OK] adb reverse tcp:3000 (127.0.0.1 tren dien thoai)'
    $devices | ForEach-Object { Write-Host "     $_" }
  } else {
    Write-Host '[..] Chua co dien thoai ADB — bat Wireless debugging hoac cam USB'
    Write-Host '     Tren dien thoai: Gỡ lỗi không dây → IP (vd 192.168.1.51:39041)'
  }
} else {
  Write-Host '[CANH BAO] Khong tim thay adb.exe'
}

Write-Host '========================================'
Write-Host ''
