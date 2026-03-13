#!/bin/bash

# Foundry Position Shell - Quick Run Script
# This script sets up and runs the Phase 1 Foundation app

set -e  # Exit on error

echo "🚀 Foundry Position Shell - Quick Setup & Run"
echo "=============================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📂 Working directory: $SCRIPT_DIR"
echo ""

# Step 1: Setup Flutter Shell
echo "📱 Step 1/4: Setting up Flutter shell..."
cd src/shell
if [ -f "pubspec.yaml" ]; then
    flutter pub get
    echo "✅ Flutter dependencies installed"
else
    echo "❌ Error: pubspec.yaml not found"
    exit 1
fi
cd ../..
echo ""

# Step 2: Build Runtime Host
echo "🌐 Step 2/4: Building runtime host..."
cd src/runtime-host
if [ -f "package.json" ]; then
    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
    fi
    echo "Building runtime host..."
    npm run build
    echo "✅ Runtime host built"
else
    echo "❌ Error: package.json not found in runtime-host"
    exit 1
fi
cd ../..
echo ""

# Step 3: Build React Module
echo "⚛️  Step 3/4: Building React module..."
cd src/modules/sample-warehouse
if [ -f "package.json" ]; then
    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
    fi
    echo "Building sample warehouse module..."
    npm run build
    echo "✅ React module built"
else
    echo "❌ Error: package.json not found in sample-warehouse"
    exit 1
fi
cd ../../..
echo ""

# Step 4: Check for devices
echo "📱 Step 4/4: Checking for devices/emulators..."
cd src/shell
DEVICES=$(flutter devices 2>&1)

if echo "$DEVICES" | grep -q "No devices detected"; then
    echo "⚠️  Warning: No devices found"
    echo ""
    echo "Please start an emulator or connect a device:"
    echo "  - Android: flutter emulators --launch <emulator_id>"
    echo "  - iOS: open -a Simulator"
    echo "  - Physical: Connect via USB and enable USB debugging"
    echo ""
    echo "Then run: flutter run"
    exit 1
else
    echo "✅ Devices found:"
    echo "$DEVICES"
    echo ""
fi

# Step 5: Run the app
echo "🚀 Launching Foundry Position Shell..."
echo "=============================================="
echo ""
echo "The app will now start. You should see:"
echo "  1. Mock login screen"
echo "  2. Position resolution"
echo "  3. Runtime host boot"
echo "  4. Sample warehouse module"
echo ""
echo "Press 'r' for hot reload, 'R' for hot restart, 'q' to quit"
echo ""

flutter run

echo ""
echo "✅ App closed"
