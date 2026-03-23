#!/bin/bash

# Bridge Methods Test Script
# Tests all 4 new bridge methods are working

echo "========================================="
echo "Bridge Methods Test Script"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_DIR="C:/Users/bijay/OneDrive/Desktop/auto_agent3/pocs/output/foundry-position-shell-poc/src/backend"
SHELL_DIR="C:/Users/bijay/OneDrive/Desktop/auto_agent3/pocs/output/foundry-position-shell-poc/src/shell"
DEVICE_ID="2201116PI"

echo "Test Configuration:"
echo "  Backend: $BACKEND_DIR/server.js"
echo "  Shell: $SHELL_DIR"
echo "  Device: $DEVICE_ID"
echo ""

# Step 1: Check backend server
echo "Step 1: Checking backend server..."
if curl -s http://192.168.0.163:3000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Backend server is running"
else
    echo -e "${RED}✗${NC} Backend server not responding"
    echo "  Start with: node $BACKEND_DIR/server.js"
    exit 1
fi

# Step 2: Check device connected
echo ""
echo "Step 2: Checking device connection..."
if adb devices | grep -q "$DEVICE_ID"; then
    echo -e "${GREEN}✓${NC} Device $DEVICE_ID is connected"
else
    echo -e "${RED}✗${NC} Device $DEVICE_ID not found"
    echo "  Connect device and enable USB debugging"
    exit 1
fi

# Step 3: Check Flutter project
echo ""
echo "Step 3: Checking Flutter project..."
if [ -f "$SHELL_DIR/pubspec.yaml" ]; then
    echo -e "${GREEN}✓${NC} Flutter project found"
else
    echo -e "${RED}✗${NC} Flutter project not found at $SHELL_DIR"
    exit 1
fi

# Step 4: Analyze code for errors
echo ""
echo "Step 4: Analyzing Flutter code..."
cd "$SHELL_DIR"
ANALYZE_OUTPUT=$(flutter analyze lib/main.dart lib/bridge/shell_bridge.dart lib/bridge/offline_bridge_extension.dart 2>&1)

if echo "$ANALYZE_OUTPUT" | grep -q "error"; then
    echo -e "${RED}✗${NC} Flutter analysis found errors:"
    echo "$ANALYZE_OUTPUT" | grep "error"
    exit 1
else
    ISSUE_COUNT=$(echo "$ANALYZE_OUTPUT" | grep "issues found" | awk '{print $1}')
    echo -e "${GREEN}✓${NC} Flutter analysis passed ($ISSUE_COUNT warnings, 0 errors)"
fi

# Step 5: Check bridge methods are defined
echo ""
echo "Step 5: Verifying bridge methods in code..."

check_method() {
    local method=$1
    local file=$2
    if grep -q "$method" "$file"; then
        echo -e "  ${GREEN}✓${NC} $method found"
    else
        echo -e "  ${RED}✗${NC} $method NOT found in $file"
        return 1
    fi
}

echo "  Checking JavaScript injection (main.dart):"
check_method "submitTransaction: function(args)" "$SHELL_DIR/lib/main.dart" || exit 1
check_method "getTransactionHistory: function()" "$SHELL_DIR/lib/main.dart" || exit 1
check_method "getSyncStatus: function()" "$SHELL_DIR/lib/main.dart" || exit 1
check_method "forceSyncNow: function()" "$SHELL_DIR/lib/main.dart" || exit 1

echo ""
echo "  Checking Flutter handlers (shell_bridge.dart):"
check_method "_handleSubmitTransaction" "$SHELL_DIR/lib/bridge/shell_bridge.dart" || exit 1
check_method "_handleGetTransactionHistory" "$SHELL_DIR/lib/bridge/shell_bridge.dart" || exit 1
check_method "_handleGetSyncStatus" "$SHELL_DIR/lib/bridge/shell_bridge.dart" || exit 1
check_method "_handleForceSyncNow" "$SHELL_DIR/lib/bridge/shell_bridge.dart" || exit 1

echo ""
echo "  Checking implementation (offline_bridge_extension.dart):"
check_method "Future<Map<String, dynamic>> submitTransaction" "$SHELL_DIR/lib/bridge/offline_bridge_extension.dart" || exit 1
check_method "Future<Map<String, dynamic>> getTransactionHistory" "$SHELL_DIR/lib/bridge/offline_bridge_extension.dart" || exit 1
check_method "Future<Map<String, dynamic>> getSyncStatus" "$SHELL_DIR/lib/bridge/offline_bridge_extension.dart" || exit 1
check_method "Future<Map<String, dynamic>> forceSyncNow" "$SHELL_DIR/lib/bridge/offline_bridge_extension.dart" || exit 1

# Step 6: Ready to run
echo ""
echo "========================================="
echo -e "${GREEN}All pre-flight checks passed!${NC}"
echo "========================================="
echo ""
echo "Ready to run Flutter app. Execute:"
echo ""
echo "  cd $SHELL_DIR"
echo "  flutter run -d $DEVICE_ID"
echo ""
echo "Then test the 4 bridge methods:"
echo "  1. submitTransaction() - Submit a receiving transaction"
echo "  2. getTransactionHistory() - View transaction history"
echo "  3. getSyncStatus() - Check sync status"
echo "  4. forceSyncNow() - Trigger manual sync"
echo ""
echo "See BRIDGE_FIX_TESTING_GUIDE.md for detailed test scenarios."
echo ""
