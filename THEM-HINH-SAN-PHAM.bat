@echo off
setlocal EnableExtensions
chcp 65001 >nul
title SafeMarket - Gan hinh san pham

set "ROOT=%~dp0"
set "SQL=%ROOT%backend\db\seed-product-images.sql"

echo.
echo ========================================
echo  SafeMarket - Gan hinh san pham demo
echo ========================================
echo.
echo File SQL: %SQL%
echo.
echo Cach 1 (SSMS - khuyen dung):
echo   Mo SQL Server Management Studio
echo   Ket noi SafeMarketDB ^> File ^> Open ^> chon file tren ^> Execute
echo.
echo Cach 2 (sqlcmd - Windows Auth):
echo   sqlcmd -S localhost -d SafeMarketDB -E -i "%SQL%" -C
echo.

where sqlcmd >nul 2>&1
if errorlevel 1 (
  echo [CANH BAO] Khong tim thay sqlcmd. Dung SSMS de chay file SQL.
  pause
  exit /b 0
)

echo [..] Dang chay seed-product-images.sql ^(Windows Auth^)...
sqlcmd -S localhost -d SafeMarketDB -E -i "%SQL%" -C
if errorlevel 1 (
  echo.
  echo [LOI] sqlcmd that bai. Mo SSMS va chay file SQL thu cong.
  pause
  exit /b 1
)

echo.
echo [OK] Da gan hinh. Khoi dong lai app hoac keo de refresh cho.
echo      Anh nam trong: backend\uploads\products\
echo.
pause
