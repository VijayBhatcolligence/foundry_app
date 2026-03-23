# Network Diagnostic Script for Foundry Backend
# Tests connectivity and identifies issues

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Foundry Backend - Network Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if backend is running
Write-Host "[1/6] Checking if backend is running on port 3000..." -ForegroundColor Yellow
$portCheck = netstat -ano | Select-String ":3000.*LISTENING"

if ($portCheck) {
    Write-Host "  ✓ PASS: Backend is running" -ForegroundColor Green
    Write-Host "    $portCheck" -ForegroundColor Gray
    $backendRunning = $true
} else {
    Write-Host "  ✗ FAIL: Backend is NOT running" -ForegroundColor Red
    Write-Host "    Solution: cd src/backend; npm start" -ForegroundColor Yellow
    $backendRunning = $false
}

Write-Host ""

# Step 2: Get PC IP address
Write-Host "[2/6] Getting PC IP address..." -ForegroundColor Yellow
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -or $_.PrefixOrigin -eq "Manual" } | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" } | Select-Object -First 1

if ($ipInfo) {
    $ipAddress = $ipInfo.IPAddress
    $gateway = (Get-NetRoute -InterfaceIndex $ipInfo.InterfaceIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
    Write-Host "  ✓ PASS: Network configured" -ForegroundColor Green
    Write-Host "    IP Address: $ipAddress" -ForegroundColor Gray
    Write-Host "    Gateway: $gateway" -ForegroundColor Gray
    Write-Host "    Interface: $($ipInfo.InterfaceAlias)" -ForegroundColor Gray
    $ipConfigured = $true
} else {
    Write-Host "  ✗ FAIL: Could not determine IP address" -ForegroundColor Red
    Write-Host "    Solution: Check network connection" -ForegroundColor Yellow
    $ipAddress = "UNKNOWN"
    $ipConfigured = $false
}

Write-Host ""

# Step 3: Check firewall rule
Write-Host "[3/6] Checking firewall rule for port 3000..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule -DisplayName "Foundry Backend Port 3000" -ErrorAction SilentlyContinue

if ($firewallRule -and $firewallRule.Enabled -eq $true) {
    Write-Host "  ✓ PASS: Firewall rule exists and is enabled" -ForegroundColor Green
    Write-Host "    Rule: $($firewallRule.DisplayName)" -ForegroundColor Gray
    Write-Host "    Action: $($firewallRule.Action)" -ForegroundColor Gray
    $firewallConfigured = $true
} else {
    Write-Host "  ✗ FAIL: Firewall rule missing or disabled" -ForegroundColor Red
    Write-Host "    Solution: Run fix_firewall.ps1 as Administrator" -ForegroundColor Yellow
    $firewallConfigured = $false
}

Write-Host ""

# Step 4: Test localhost connection
Write-Host "[4/6] Testing backend on localhost..." -ForegroundColor Yellow
if ($backendRunning) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -TimeoutSec 3 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✓ PASS: Backend responds on localhost" -ForegroundColor Green
            Write-Host "    Status: $($response.StatusCode)" -ForegroundColor Gray
            Write-Host "    Response: $($response.Content)" -ForegroundColor Gray
            $localhostWorks = $true
        } else {
            Write-Host "  ✗ FAIL: Backend returned status $($response.StatusCode)" -ForegroundColor Red
            $localhostWorks = $false
        }
    } catch {
        Write-Host "  ✗ FAIL: Cannot connect to backend on localhost" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Gray
        $localhostWorks = $false
    }
} else {
    Write-Host "  ⊘ SKIP: Backend not running" -ForegroundColor Gray
    $localhostWorks = $false
}

Write-Host ""

# Step 5: Test network IP connection
Write-Host "[5/6] Testing backend on network IP ($ipAddress)..." -ForegroundColor Yellow
if ($backendRunning -and $ipConfigured) {
    try {
        $response = Invoke-WebRequest -Uri "http://$($ipAddress):3000/api/health" -TimeoutSec 3 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✓ PASS: Backend responds on network IP" -ForegroundColor Green
            Write-Host "    Status: $($response.StatusCode)" -ForegroundColor Gray
            Write-Host "    Response: $($response.Content)" -ForegroundColor Gray
            $networkIpWorks = $true
        } else {
            Write-Host "  ✗ FAIL: Backend returned status $($response.StatusCode)" -ForegroundColor Red
            $networkIpWorks = $false
        }
    } catch {
        Write-Host "  ✗ FAIL: Cannot connect to backend on network IP" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Gray
        Write-Host "    This usually means firewall is blocking" -ForegroundColor Yellow
        $networkIpWorks = $false
    }
} else {
    Write-Host "  ⊘ SKIP: Backend not running or IP not configured" -ForegroundColor Gray
    $networkIpWorks = $false
}

Write-Host ""

# Step 6: Check Flutter configuration
Write-Host "[6/6] Checking Flutter code configuration..." -ForegroundColor Yellow
$offlineBridgePath = "src\shell\lib\bridge\offline_bridge_extension.dart"
$syncManagerPath = "src\shell\lib\offline\sync_manager.dart"

if (Test-Path $offlineBridgePath) {
    $offlineBridgeContent = Get-Content $offlineBridgePath -Raw
    $urlPattern = 'backendUrl\s*=\s*''http://([^'']+)'''
    if ($offlineBridgeContent -match $urlPattern) {
        $configuredUrl = $matches[1]
        if ($configuredUrl -eq "$($ipAddress):3000") {
            Write-Host "  ✓ PASS: offline_bridge_extension.dart has correct IP" -ForegroundColor Green
            Write-Host "    Configured: $configuredUrl" -ForegroundColor Gray
        } else {
            Write-Host "  ⚠ WARNING: offline_bridge_extension.dart IP mismatch" -ForegroundColor Yellow
            Write-Host "    Configured: $configuredUrl" -ForegroundColor Gray
            Write-Host "    Current PC IP: $($ipAddress):3000" -ForegroundColor Gray
            Write-Host "    Update line 21 in offline_bridge_extension.dart" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  ⊘ SKIP: Could not find offline_bridge_extension.dart" -ForegroundColor Gray
}

if (Test-Path $syncManagerPath) {
    $syncManagerContent = Get-Content $syncManagerPath -Raw
    $urlPattern = 'backendUrl\s*=\s*''http://([^'']+)'''
    if ($syncManagerContent -match $urlPattern) {
        $configuredUrl = $matches[1]
        if ($configuredUrl -eq "$($ipAddress):3000") {
            Write-Host "  ✓ PASS: sync_manager.dart has correct IP" -ForegroundColor Green
            Write-Host "    Configured: $configuredUrl" -ForegroundColor Gray
        } else {
            Write-Host "  ⚠ WARNING: sync_manager.dart IP mismatch" -ForegroundColor Yellow
            Write-Host "    Configured: $configuredUrl" -ForegroundColor Gray
            Write-Host "    Current PC IP: $($ipAddress):3000" -ForegroundColor Gray
            Write-Host "    Update line 394 in sync_manager.dart" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  ⊘ SKIP: Could not find sync_manager.dart" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $backendRunning -and $ipConfigured -and $firewallConfigured -and $localhostWorks -and $networkIpWorks

if ($allPassed) {
    Write-Host "✓ ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your backend is properly configured and accessible." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Test from mobile browser: http://$($ipAddress):3000/api/health" -ForegroundColor White
    Write-Host "2. If mobile test works, restart Flutter app (FULL restart, not hot reload)" -ForegroundColor White
    Write-Host "3. Bridge should work properly" -ForegroundColor White
} else {
    Write-Host "✗ SOME CHECKS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Issues found:" -ForegroundColor Yellow
    if (-not $backendRunning) { Write-Host "  - Backend not running → cd src/backend && npm start" -ForegroundColor White }
    if (-not $ipConfigured) { Write-Host "  - Network not configured → Check network connection" -ForegroundColor White }
    if (-not $firewallConfigured) { Write-Host "  - Firewall not configured → Run fix_firewall.ps1 as Administrator" -ForegroundColor White }
    if (-not $localhostWorks) { Write-Host "  - Backend not responding → Check backend logs" -ForegroundColor White }
    if (-not $networkIpWorks) { Write-Host "  - Network IP blocked → Fix firewall or check AP isolation" -ForegroundColor White }
}

Write-Host ""
Write-Host "Mobile Device Configuration:" -ForegroundColor Yellow
Write-Host "  1. Connect to same WiFi network (gateway: $gateway)" -ForegroundColor White
Write-Host "  2. Open mobile browser" -ForegroundColor White
Write-Host "  3. Navigate to: http://$($ipAddress):3000/api/health" -ForegroundColor White
Write-Host "  4. Should see: {\"status\":\"ok\",...}" -ForegroundColor White
Write-Host ""

pause
