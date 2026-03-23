@echo off
echo ============================================
echo ADB Port Forwarding Setup
echo ============================================
echo.
echo This will map device localhost:3000 to PC backend
echo.

echo [1/3] Checking ADB connection...
adb devices
echo.

echo [2/3] Setting up port forwarding...
adb reverse tcp:3000 tcp:3000
echo.

echo [3/3] Verifying forwarding...
adb reverse --list
echo.

echo ============================================
echo Setup Complete!
echo ============================================
echo.
echo Device localhost:3000 now forwards to PC port 3000
echo.
echo Make sure backend is running on PC:
echo   cd pocs\output\foundry-position-shell-poc\src\backend
echo   node server.js
echo.
echo Then test the app!
echo.
pause
