@echo off
chcp 65001 >nul
title SafeMarket - Ket noi dien thoai (ADB)
setlocal EnableExtensions

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "FLUTTER=C:\src\flutter\bin\flutter.bat"

if not exist "%ADB%" (
  echo [LOI] Khong tim thay adb.exe tai:
  echo   %ADB%
  pause
  exit /b 1
)

echo ============================================
echo  SafeMarket - Ket noi dien thoai OPPO/Android
echo ============================================
echo.
echo [1] USB  - on dinh nhat ^(khuyen dung^)
echo [2] Wi-Fi - pair + connect bang IP
echo [3] Chi reset ADB + reverse port 3000
echo [0] Thoat
echo.
set /p CHOICE=Chon (1/2/3/0): 

if "%CHOICE%"=="0" exit /b 0
if "%CHOICE%"=="1" goto USB
if "%CHOICE%"=="2" goto WIFI
if "%CHOICE%"=="3" goto RESET
echo Lua chon khong hop le.
pause
exit /b 1

:RESET
call :KillAdb
"%ADB%" start-server
"%ADB%" reverse tcp:3000 tcp:3000
goto SHOW

:USB
echo.
echo >> Tren dien thoai:
echo    1^) TAT Wireless debugging
echo    2^) Cam cap USB, chon Che do Truyen tep / MTP
echo    3^) Bat USB debugging, bam CHO PHEP
echo.
pause
call :KillAdb
"%ADB%" start-server
timeout /t 2 >nul
"%ADB%" devices -l
"%ADB%" reverse tcp:3000 tcp:3000
echo.
echo Da bat adb reverse tcp:3000 ^(app dung http://127.0.0.1:3000/api^)
goto SHOW

:WIFI
echo.
echo >> Tren dien thoai ^(cung Wi-Fi voi PC^):
echo    Developer options -^> Wireless debugging
echo    - Bam "Pair device with pairing code"
echo    - Ghi IP:PORT_PAIR va ma 6 so
echo.
set /p PAIR=Nhap IP:PORT ghep noi (vd 192.168.1.20:37123): 
"%ADB%" pair %PAIR%
if errorlevel 1 (
  echo Pair that bai. Thu lai.
  pause
  exit /b 1
)
echo.
echo >> Quay lai man Wireless debugging ^(khong phai man pair^)
echo    Lay IP:PORT ket noi ^(vd 192.168.1.20:5555^)
echo.
set /p PORT=Nhap IP:PORT ket noi: 
"%ADB%" connect %PORT%
"%ADB%" devices -l
echo.
echo Luu y Wi-Fi: API backend dung IP may tinh, vd:
echo   --dart-define=API_BASE_URL=http://192.168.1.19:3000/api
goto SHOW

:SHOW
echo.
echo === adb devices ===
"%ADB%" devices -l
echo.
echo === flutter devices ===
if exist "%FLUTTER%" (
  "%FLUTTER%" devices
) else (
  echo Khong tim thay flutter tai %FLUTTER%
)
echo.
echo Neu CPH2061 hien "device" ^(khong phai unsupported^) thi Run app duoc.
echo Neu van unsupported: rut/cam lai USB, TAT Wireless debugging, chay lai script.
echo.
pause
exit /b 0

:KillAdb
echo Reset ADB...
"%ADB%" disconnect >nul 2>&1
"%ADB%" kill-server >nul 2>&1
timeout /t 2 >nul
exit /b 0
