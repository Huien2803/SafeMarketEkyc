@echo off
setlocal EnableExtensions
chcp 65001 >nul
title SafeMarket - Cau hinh SMTP (OTP email)

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "ENVFILE=%BACKEND%\.env"

echo.
echo ========================================
echo  Cau hinh gui OTP qua Gmail
echo ========================================
echo.
echo Code OTP da san sang. Chi thieu mat khau ung dung Gmail.
echo.
echo Buoc 1: Trinh duyet se mo trang tao App Password.
echo         - Dang nhap Gmail letanloc05122020@gmail.com
echo         - Neu chua co Xac minh 2 buoc: bat truoc
echo         - Tao mat khau ung dung (Mail / Other) → copy 16 ky tu
echo.
pause

start "" "https://myaccount.google.com/apppasswords"

echo.
set "SMTP_USER=letanloc05122020@gmail.com"
set /p "SMTP_USER=Email Gmail gui OTP [%SMTP_USER%]: "
if "%SMTP_USER%"=="" set "SMTP_USER=letanloc05122020@gmail.com"

echo.
set "SMTP_PASS="
set /p "SMTP_PASS=Dan 16 ky tu App Password vao day: "
if "%SMTP_PASS%"=="" (
  echo [LOI] Ban chua dan App Password. Thoat.
  pause
  exit /b 1
)

if not exist "%ENVFILE%" (
  echo [LOI] Khong thay %ENVFILE%
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\set-smtp-pass.ps1" -EnvFile "%ENVFILE%" -SmtpUser "%SMTP_USER%" -SmtpPass "%SMTP_PASS%"
if errorlevel 1 (
  echo [LOI] Khong ghi duoc .env
  pause
  exit /b 1
)

echo.
echo Dang test gui mail...
cd /d "%BACKEND%"
node scripts\test-smtp.js
if errorlevel 1 (
  echo.
  echo [LOI] Gui mail that bai. Kiem tra App Password / 2FA roi chay lai file nay.
  pause
  exit /b 1
)

echo.
echo OK — OTP da gui thu. Mo Gmail (ca Spam) de xac nhan.
echo Tiep theo: chay CHAY-BACKEND.bat (neu server dang chay, tat di roi chay lai).
echo.
set /p "RUN=Chay lai backend ngay? (Y/N): "
if /I "%RUN%"=="Y" (
  start "" "%ROOT%CHAY-BACKEND.bat"
)

echo.
pause
exit /b 0
