@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo  === SafeMarket: Them Flutter app vao Firebase ===
echo  Project: safemarketekyc
echo.

where firebase >nul 2>&1
if errorlevel 1 (
  echo  Chua co Firebase CLI. Dang cai...
  call npm install -g firebase-tools
)

echo  Buoc 1/2: Dang nhap Google (se mo trinh duyet)...
echo  Neu da dang nhap roi, co the bo qua.
firebase login
if errorlevel 1 (
  echo  Dang nhap that bai. Thu lai: firebase login
  pause
  exit /b 1
)

echo.
echo  Buoc 2/2: flutterfire configure — tao app Android + Web...
call dart pub global activate flutterfire_cli
call flutterfire configure ^
  --project=safemarketekyc ^
  --platforms=android,web ^
  --android-package-name=com.example.safemarket_app ^
  --yes ^
  --overwrite-firebase-options

if errorlevel 1 (
  echo.
  echo  Configure that bai. Kiem tra:
  echo    - Da dang nhap firebase login
  echo    - Project safemarketekyc ton tai tren console.firebase.google.com
  pause
  exit /b 1
)

echo.
echo  Xong! Da cap nhat:
echo    - lib\firebase_options.dart
echo    - android\app\google-services.json
echo.
echo  Tiep theo: flutter clean ^&^& flutter pub get ^&^& flutter run
pause
