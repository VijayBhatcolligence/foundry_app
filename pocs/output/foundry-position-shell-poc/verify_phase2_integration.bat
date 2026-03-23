@echo off
echo ================================================
echo Phase 2 Integration Verification Script
echo ================================================
echo.

cd src\shell

echo [1/4] Checking Flutter environment...
flutter --version
echo.

echo [2/4] Installing dependencies...
flutter pub get
echo.

echo [3/4] Running code analysis...
flutter analyze lib/main.dart
echo.

echo [4/4] Checking integration files...
echo.
echo Checking Phase 1 files (should exist):
if exist "lib\auth\mock_auth_service.dart" (echo   ✓ auth/mock_auth_service.dart) else (echo   ✗ auth/mock_auth_service.dart MISSING)
if exist "lib\position\position_resolver.dart" (echo   ✓ position/position_resolver.dart) else (echo   ✗ position/position_resolver.dart MISSING)
if exist "lib\session\session_broker.dart" (echo   ✓ session/session_broker.dart) else (echo   ✗ session/session_broker.dart MISSING)
if exist "lib\bridge\shell_bridge.dart" (echo   ✓ bridge/shell_bridge.dart) else (echo   ✗ bridge/shell_bridge.dart MISSING)

echo.
echo Checking Phase 2 files (should exist):
if exist "lib\modules\module_registry.dart" (echo   ✓ modules/module_registry.dart) else (echo   ✗ modules/module_registry.dart MISSING)
if exist "lib\modules\module_cache.dart" (echo   ✓ modules/module_cache.dart) else (echo   ✗ modules/module_cache.dart MISSING)
if exist "lib\modules\module_updater.dart" (echo   ✓ modules/module_updater.dart) else (echo   ✗ modules/module_updater.dart MISSING)
if exist "lib\modules\fallback_manager.dart" (echo   ✓ modules/fallback_manager.dart) else (echo   ✗ modules/fallback_manager.dart MISSING)
if exist "lib\security\module_verifier.dart" (echo   ✓ security/module_verifier.dart) else (echo   ✗ security/module_verifier.dart MISSING)
if exist "lib\bridge\module_bridge_extension.dart" (echo   ✓ bridge/module_bridge_extension.dart) else (echo   ✗ bridge/module_bridge_extension.dart MISSING)

echo.
echo Checking integration report:
if exist "..\phases\phase-2-trust-delivery\INTEGRATION_REPORT.md" (echo   ✓ INTEGRATION_REPORT.md exists) else (echo   ✗ INTEGRATION_REPORT.md MISSING)

echo.
echo ================================================
echo Verification Complete!
echo ================================================
echo.
echo To run the integrated app:
echo   flutter run
echo.
echo To run in web browser:
echo   flutter run -d chrome
echo.
pause
