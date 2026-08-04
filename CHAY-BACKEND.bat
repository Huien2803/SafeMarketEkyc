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

rem Neu dang chay tren cong 3000 thi tu dung roi start lai (khong hoi Y/N).
powershell -NoProfile -Command "$c=Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if($c){ Write-Host 'Dang dung process cu tren cong 3000...'; Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue }"
timeout /t 2 /nobreak >nul

echo Dang bat backend...
echo API:     http://localhost:3000/api
echo Swagger: http://localhost:3000/api/docs
echo.
echo GIU CUA SO NAY MO khi dung app.
echo Tat backend: Ctrl+C
echo ----------------------------------------
echo.

call npm run start:dev

echo.
echo Backend da dung.
pause
exit /b 0
