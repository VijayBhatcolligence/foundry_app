@echo off
echo Running Network Diagnostics...
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0test_network.ps1"
pause
