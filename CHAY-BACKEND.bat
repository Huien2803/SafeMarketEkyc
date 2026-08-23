@echo off
setlocal EnableExtensions
chcp 65001 >nul
title SafeMarket Backend

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
cd /d "%BACKEND%"
if errorlevel 1 (
  echo [LOI] Khong vao duoc thu muc backend:
  echo %BACKEND%
  pause
  exit /b 1
)

echo.
echo ========================================
echo  SafeMarket - Backend NestJS port 3000
echo ========================================
echo.
echo Thu muc: %CD%
echo.

set "OCR_PROVIDER=fpt"
if exist ".env" (
  for /f "usebackq tokens=2 delims==" %%A in (`findstr /B /C:"EKYC_OCR_PROVIDER=" ".env"`) do set "OCR_PROVIDER=%%A"
)
echo OCR CCCD provider: %OCR_PROVIDER%
echo.

if not exist "package.json" (
  echo [LOI] Khong thay package.json trong:
  echo %CD%
  pause
  exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
  echo [LOI] Chua cai Node.js / npm.
  pause
  exit /b 1
)

rem --- Giai phong cong 3000 (tranh loi EADDRINUSE) ---
call :FreePort3000
if errorlevel 1 (
  echo.
  echo [LOI] Cong 3000 van bi chiem. Mo Task Manager ^> End task cac "Node.js".
  pause
  exit /b 1
)

rem --- Tu dong: firewall + IP LAN + adb reverse ---
echo [..] Chuan bi ket noi dien thoai...
powershell -NoProfile -ExecutionPolicy Bypass -File "%BACKEND%\scripts\dev-phone-setup.ps1"
echo.

echo Dang bat backend...
echo API PC:       http://localhost:3000/api
echo Config app:   http://localhost:3000/api/dev/client-config
echo.
echo Sau khi backend len, app dien thoai tu dong thu:
echo   - 127.0.0.1:3000 ^(adb reverse^)
echo   - IP WiFi PC   ^(cung mang 192.168.x.x^)
echo.
echo GIU CUA SO NAY MO khi dung app. Tat: Ctrl+C
echo ----------------------------------------
echo.

call npm run start:dev

echo.
echo Backend da dung.
pause
exit /b 0

:FreePort3000
echo [..] Kiem tra cong 3000...
set "TRIES=0"
:KillLoop
set /a TRIES+=1
set "FOUND=0"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":3000" ^| findstr "LISTENING"') do (
  set "FOUND=1"
  echo [..] Dang tat process PID %%P tren cong 3000...
  taskkill /F /PID %%P >nul 2>&1
)
if "%FOUND%"=="0" exit /b 0
timeout /t 2 /nobreak >nul
netstat -ano | findstr ":3000" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 exit /b 0
if %TRIES% GEQ 5 exit /b 1
goto KillLoop
