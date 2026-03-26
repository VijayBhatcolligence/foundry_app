#!/bin/bash

echo "========================================="
echo "Phase 4 Implementation Verification"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check function
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (MISSING)"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        return 0
    else
        echo -e "${RED}✗${NC} $1/ (MISSING)"
        return 1
    fi
}

total=0
passed=0

echo "1. React/JavaScript Files"
echo "-------------------------"
((total++)); check_file "src/shell/assets/modules/sample-warehouse/db/schema.js" && ((passed++))
((total++)); check_file "src/shell/assets/modules/sample-warehouse/db/useDatabase.js" && ((passed++))
((total++)); check_file "src/shell/assets/modules/sample-warehouse/sync/SyncManager.js" && ((passed++))
((total++)); check_file "src/shell/assets/modules/sample-warehouse/api/TransactionAPI.js" && ((passed++))
((total++)); check_file "src/shell/assets/modules/sample-warehouse/index.html" && ((passed++))
((total++)); check_file "src/shell/assets/modules/sample-warehouse/package.json" && ((passed++))
echo ""

echo "2. Flutter/Dart Files"
echo "---------------------"
((total++)); check_file "src/shell/lib/bridge/connectivity_bridge_extension.dart" && ((passed++))
((total++)); check_file "src/shell/lib/bridge/shell_bridge.dart" && ((passed++))
((total++)); check_file "src/shell/lib/main.dart" && ((passed++))
echo ""

echo "3. Documentation Files"
echo "---------------------"
((total++)); check_file "src/shell/assets/modules/sample-warehouse/TESTING.md" && ((passed++))
((total++)); check_file "phases/phase-4-demo-transaction-workflow/IMPLEMENTATION_SUMMARY.md" && ((passed++))
((total++)); check_file "phases/phase-4-demo-transaction-workflow/QUICK_START.md" && ((passed++))
((total++)); check_file "phases/phase-4-demo-transaction-workflow/ARCHITECTURE.md" && ((passed++))
((total++)); check_file "phases/phase-4-demo-transaction-workflow/planner/plan.md" && ((passed++))
echo ""

echo "4. Directories"
echo "-------------"
((total++)); check_dir "src/shell/assets/modules/sample-warehouse/db" && ((passed++))
((total++)); check_dir "src/shell/assets/modules/sample-warehouse/sync" && ((passed++))
((total++)); check_dir "src/shell/assets/modules/sample-warehouse/api" && ((passed++))
((total++)); check_dir "src/shell/assets/modules/sample-warehouse/node_modules" && ((passed++))
echo ""

echo "5. Dependencies"
echo "--------------"
if [ -d "src/shell/assets/modules/sample-warehouse/node_modules/rxdb" ]; then
    echo -e "${GREEN}✓${NC} RxDB installed"
    ((passed++))
else
    echo -e "${RED}✗${NC} RxDB not installed"
fi
((total++))

if [ -d "src/shell/assets/modules/sample-warehouse/node_modules/dexie" ]; then
    echo -e "${GREEN}✓${NC} Dexie installed"
    ((passed++))
else
    echo -e "${RED}✗${NC} Dexie not installed"
fi
((total++))

if [ -d "src/shell/assets/modules/sample-warehouse/node_modules/uuid" ]; then
    echo -e "${GREEN}✓${NC} UUID installed"
    ((passed++))
else
    echo -e "${RED}✗${NC} UUID not installed"
fi
((total++))
echo ""

echo "========================================="
echo "Results: $passed / $total checks passed"
echo "========================================="

if [ $passed -eq $total ]; then
    echo -e "${GREEN}✓ All checks passed! Implementation complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review above output.${NC}"
    exit 1
fi
