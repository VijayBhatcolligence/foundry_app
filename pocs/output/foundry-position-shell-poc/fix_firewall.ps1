# Firewall Fix Script for Foundry Backend
# Run this script as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Foundry Backend - Firewall Fix Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host "Step 1: Checking if backend is running on port 3000..." -ForegroundColor Yellow
$portCheck = netstat -ano | Select-String ":3000.*LISTENING"

if ($portCheck) {
    Write-Host "✓ Backend is running on port 3000" -ForegroundColor Green
    Write-Host "  $portCheck" -ForegroundColor Gray
} else {
    Write-Host "✗ Backend is NOT running on port 3000" -ForegroundColor Red
    Write-Host "  Start the backend first: cd src/backend && npm start" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 2: Getting PC IP address..." -ForegroundColor Yellow
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -or $_.PrefixOrigin -eq "Manual" } | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" } | Select-Object -First 1

if ($ipInfo) {
    $ipAddress = $ipInfo.IPAddress
    Write-Host "✓ PC IP Address: $ipAddress" -ForegroundColor Green
    Write-Host "  Use this IP in your mobile device: http://$($ipAddress):3000" -ForegroundColor Gray
} else {
    Write-Host "✗ Could not determine IP address" -ForegroundColor Red
    Write-Host "  Run 'ipconfig' manually to find your IP" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 3: Checking existing firewall rules for port 3000..." -ForegroundColor Yellow
$existingRule = Get-NetFirewallRule -DisplayName "Foundry Backend Port 3000" -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "✓ Firewall rule already exists" -ForegroundColor Green
    Write-Host ""
    Write-Host "Do you want to remove and recreate it? (y/n): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    if ($response -eq "y") {
        Remove-NetFirewallRule -DisplayName "Foundry Backend Port 3000"
        Write-Host "✓ Existing rule removed" -ForegroundColor Green
    } else {
        Write-Host "Keeping existing rule" -ForegroundColor Gray
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Configuration Complete!" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        pause
        exit 0
    }
}

Write-Host ""
Write-Host "Step 4: Adding firewall rule for port 3000..." -ForegroundColor Yellow

try {
    New-NetFirewallRule -DisplayName "Foundry Backend Port 3000" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 3000 `
        -Profile Any `
        -Enabled True `
        -Description "Allow incoming connections to Foundry Backend on port 3000"

    Write-Host "✓ Firewall rule added successfully!" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to add firewall rule: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "Step 5: Verifying firewall rule..." -ForegroundColor Yellow
$newRule = Get-NetFirewallRule -DisplayName "Foundry Backend Port 3000"
if ($newRule) {
    Write-Host "✓ Firewall rule verified" -ForegroundColor Green
    Write-Host "  Rule Name: $($newRule.DisplayName)" -ForegroundColor Gray
    Write-Host "  Enabled: $($newRule.Enabled)" -ForegroundColor Gray
    Write-Host "  Direction: $($newRule.Direction)" -ForegroundColor Gray
    Write-Host "  Action: $($newRule.Action)" -ForegroundColor Gray
} else {
    Write-Host "✗ Could not verify firewall rule" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firewall Configuration Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Make sure backend is running: cd src/backend && npm start" -ForegroundColor White
Write-Host "2. Test from PC browser: http://$ipAddress:3000/api/health" -ForegroundColor White
Write-Host "3. Test from mobile browser: http://$ipAddress:3000/api/health" -ForegroundColor White
Write-Host "4. If mobile test works, restart Flutter app FULLY (not hot reload)" -ForegroundColor White
Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Yellow
Write-Host "- If mobile browser can't connect, check WiFi AP Isolation on router" -ForegroundColor White
Write-Host "- Make sure both PC and mobile are on same WiFi network" -ForegroundColor White
Write-Host "- Check firewall: netsh advfirewall show rule name='Foundry Backend Port 3000'" -ForegroundColor White
Write-Host ""

pause
