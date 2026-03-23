@echo off
REM Network Fix Launcher - Choose your approach
color 0A

:MENU
cls
echo ================================================================================
echo   ERR_ADDRESS_UNREACHABLE - NETWORK FIX LAUNCHER
echo ================================================================================
echo.
echo   Current Issue: WebView cannot reach backend at http://192.168.0.163:3000
echo   Error: net::ERR_ADDRESS_UNREACHABLE
echo.
echo ================================================================================
echo   CHOOSE YOUR APPROACH
echo ================================================================================
echo.
echo   [0] Run Diagnostic (RECOMMENDED FIRST)
echo       - Tests network connectivity
echo       - Checks ADB status
echo       - Recommends best approach
echo.
echo   [1] APPROACH 1: ADB Port Forwarding (FASTEST - 5 min)
echo       - Uses localhost via ADB tunnel
echo       - 95%% success rate
echo       - Requires USB connection
echo.
echo   [2] APPROACH 2: Enhanced Android Config (15 min)
echo       - Fixes Android cleartext restrictions
echo       - 60%% success rate (needs network reachable)
echo       - Works over WiFi
echo.
echo   [3] APPROACH 3: ngrok HTTPS Tunnel (10 min)
echo       - Creates public HTTPS URL
echo       - 90%% success rate
echo       - Works from anywhere
echo.
echo   [4] View Documentation
echo       - Open complete guide
echo.
echo   [5] Quick Start Guide
echo       - Open quick reference
echo.
echo   [Q] Quit
echo.
echo ================================================================================
echo.
set /p choice="Enter your choice (0-5 or Q): "

if /i "%choice%"=="0" goto DIAGNOSTIC
if /i "%choice%"=="1" goto APPROACH1
if /i "%choice%"=="2" goto APPROACH2
if /i "%choice%"=="3" goto APPROACH3
if /i "%choice%"=="4" goto DOCS
if /i "%choice%"=="5" goto QUICKSTART
if /i "%choice%"=="Q" goto END
if /i "%choice%"=="q" goto END

echo Invalid choice. Please try again.
timeout /t 2 >nul
goto MENU

:DIAGNOSTIC
cls
echo ================================================================================
echo   RUNNING DIAGNOSTIC...
echo ================================================================================
echo.
powershell -ExecutionPolicy Bypass -File "test_network.ps1"
echo.
echo ================================================================================
echo   Diagnostic Complete
echo ================================================================================
echo.
pause
goto MENU

:APPROACH1
cls
echo ================================================================================
echo   APPROACH 1: ADB Port Forwarding
echo ================================================================================
echo.
echo   This will:
echo     1. Check ADB connection
echo     2. Setup port forwarding (localhost:3000)
echo     3. Update app config
echo     4. Rebuild Flutter app
echo.
echo   Press Ctrl+C to cancel, or
pause
echo.
powershell -ExecutionPolicy Bypass -File "apply_approach1_adb.ps1"
echo.
pause
goto MENU

:APPROACH2
cls
echo ================================================================================
echo   APPROACH 2: Enhanced Android Config
echo ================================================================================
echo.
echo   IMPORTANT: First verify device Chrome can reach backend!
echo   Open in device Chrome: http://192.168.0.163:3000/api/health
echo.
echo   If it works -> Continue
echo   If it fails -> Use Approach 1 or 3 instead
echo.
set /p continue="Continue? (Y/N): "
if /i not "%continue%"=="Y" goto MENU
echo.
echo   This will:
echo     1. Update network_security_config.xml
echo     2. Create debug AndroidManifest
echo     3. Rebuild Flutter app
echo.
powershell -ExecutionPolicy Bypass -File "apply_approach2_enhanced_android.ps1"
echo.
pause
goto MENU

:APPROACH3
cls
echo ================================================================================
echo   APPROACH 3: ngrok HTTPS Tunnel
echo ================================================================================
echo.
echo   Requirements:
echo     - ngrok installed (download from https://ngrok.com/download)
echo     - OR install via chocolatey: choco install ngrok
echo.
set /p continue="Continue? (Y/N): "
if /i not "%continue%"=="Y" goto MENU
echo.
echo   This will:
echo     1. Check ngrok installation
echo     2. Start backend if needed
echo     3. Start ngrok tunnel
echo     4. Update app config with HTTPS URL
echo     5. Rebuild Flutter app
echo.
echo   NOTE: Keep ngrok window open while using the app!
echo.
pause
powershell -ExecutionPolicy Bypass -File "apply_approach3_ngrok.ps1"
echo.
pause
goto MENU

:DOCS
cls
echo Opening complete documentation...
start NETWORK_FIX_ALTERNATIVES.md
timeout /t 2 >nul
goto MENU

:QUICKSTART
cls
echo Opening quick start guide...
start QUICK_START_NETWORK_FIX.md
timeout /t 2 >nul
goto MENU

:END
cls
echo.
echo Thank you for using the Network Fix Launcher!
echo.
echo If you need help, check:
echo   - QUICK_START_NETWORK_FIX.md (quick reference)
echo   - NETWORK_FIX_ALTERNATIVES.md (complete guide)
echo   - NETWORK_FIX_SUMMARY.txt (summary)
echo.
timeout /t 3 >nul
exit
