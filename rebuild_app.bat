@echo off
REM ========================================
REM Flutter App Complete Rebuild Script
REM Fixes ERR_CLEARTEXT_NOT_PERMITTED
REM ========================================

echo.
echo ========================================
echo REBUILDING FLUTTER APP
echo ========================================
echo.

REM Navigate to shell project
cd /d "C:\Users\bijay\OneDrive\Desktop\auto_agent3\pocs\output\foundry-position-shell-poc\src\shell"

echo [1/5] Cleaning build artifacts...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)

echo.
echo [2/5] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)

echo.
echo [3/5] Building debug APK...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo [4/5] Checking for connected devices...
adb devices
if %errorlevel% neq 0 (
    echo ERROR: ADB not found or no devices connected!
    pause
    exit /b 1
)

echo.
echo [5/5] Installing APK on device...
adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
if %errorlevel% neq 0 (
    echo ERROR: Installation failed!
    echo.
    echo Trying to uninstall old version first...
    adb uninstall com.example.foundry_shell
    echo Retrying installation...
    adb install "build\app\outputs\flutter-apk\app-debug.apk"
)

echo.
echo ========================================
echo BUILD COMPLETE!
echo ========================================
echo.
echo APK installed successfully!
echo.
echo Next steps:
echo 1. Launch the app on your device
echo 2. Check logs with: adb logcat ^| findstr "Backend Health"
echo 3. Verify connection to http://192.168.0.163:3000
echo.
echo Press any key to view logs...
pause > nul

echo.
echo Showing app logs (Ctrl+C to exit)...
adb logcat | findstr /I "chromium flutter Backend Health ERR_CLEARTEXT"
