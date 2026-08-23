@echo off
chcp 65001 >nul
echo Mo Windows Firewall cho NestJS port 3000 (can Administrator).
netsh advfirewall firewall delete rule name="SafeMarket NestJS 3000" >nul 2>&1
netsh advfirewall firewall add rule name="SafeMarket NestJS 3000" dir=in action=allow protocol=TCP localport=3000
if errorlevel 1 (
  echo That bai. Chuot phai file nay - Run as administrator.
  pause
  exit /b 1
)
echo OK. Dien thoai cung WiFi co the goi http://IP-MAY-TINH:3000/api
pause
