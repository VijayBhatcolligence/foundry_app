// Phase 5: Scanner Bridge Extension
// Purpose: Extend ShellBridge with barcode/QR code scanning methods

import 'dart:async';
import 'package:flutter/material.dart';
import '../scanner/barcode_scanner_service.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/permission_handler_service.dart';
import 'shell_bridge.dart';

/// Scanner Bridge Extension - Provides barcode and QR code scanning capabilities
/// to React modules via Flutter-WebView bridge
class ScannerBridgeExtension {
  // Track scan call frequency for rate limiting
  final List<DateTime> _recentScans = [];
  static const int _maxScansPerPeriod = 5;
  static const int _rateLimitPeriodSeconds = 10;

  // Reference to navigation context (set during registration)
  BuildContext? _context;

  /// Registers scanner methods with ShellBridge
  void registerWithBridge(ShellBridge bridge) {
    print('[ScannerBridge] Registering scanner methods...');
    // In production, ShellBridge will route method calls to these handlers
    // via the method call handler in shell_bridge.dart
    print('[ScannerBridge] Scanner methods registered');
  }

  /// Sets the navigation context for launching scanner screen
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Scans barcode (UPC, EAN, Code 128)
  /// Returns: {success: bool, barcode: string?, format: string?, error: string?}
  Future<Map<String, dynamic>> scanBarcode() async {
    return await _performScan(ScanMode.barcode);
  }

  /// Scans QR code
  /// Returns: {success: bool, barcode: string?, format: string?, error: string?}
  Future<Map<String, dynamic>> scanQRCode() async {
    return await _performScan(ScanMode.qrCode);
  }

  /// Internal scan implementation
  Future<Map<String, dynamic>> _performScan(ScanMode mode) async {
    try {
      // Rate limiting check
      if (!_checkRateLimit()) {
        return {
          'success': false,
          'error': 'Rate limit exceeded. Please wait before scanning again.',
        };
      }

      // Check camera permission first
      final permissionService = PermissionHandlerService();
      final permissionStatus = await permissionService.checkCameraPermission();

      if (permissionStatus != PermissionStatus.granted) {
        // Try to request permission
        final requestStatus = await permissionService.requestCameraPermission();

        if (requestStatus == PermissionStatus.permanentlyDenied) {
          return {
            'success': false,
            'error': 'Camera permission denied. Please enable in settings or enter manually.',
          };
        } else if (requestStatus != PermissionStatus.granted) {
          return {
            'success': false,
            'error': 'Camera permission denied. Please enable in settings or enter manually.',
          };
        }
      }

      // Check if context is available
      if (_context == null || !_context!.mounted) {
        return {
          'success': false,
          'error': 'Scanner not available. Please try again.',
        };
      }

      // Launch scanner screen
      print('[ScannerBridge] Launching scanner: ${mode.name}');
      final startTime = DateTime.now();

      final result = await Navigator.push<BarcodeResult>(
        _context!,
        MaterialPageRoute(
          builder: (context) => ScannerScreen(
            mode: mode,
            onDetected: (result) {
              Navigator.pop(context, result);
            },
            onCancelled: () {
              Navigator.pop(context, null);
            },
          ),
        ),
      );

      final loadTime = DateTime.now().difference(startTime);
      print('[ScannerBridge] Scanner closed after ${loadTime.inMilliseconds}ms');

      if (result == null) {
        return {
          'success': false,
          'error': 'Scan cancelled',
        };
      }

      // Record successful scan
      _recentScans.add(DateTime.now());

      return {
        'success': true,
        'barcode': result.rawValue,
        'format': _formatToString(result.format),
      };

    } on CameraException catch (e) {
      print('[ScannerBridge] Camera error: $e');
      return {
        'success': false,
        'error': 'Camera not available on this device',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Scan timeout. Please try again or enter manually.',
      };
    } catch (e) {
      print('[ScannerBridge] Scan error: $e');
      return {
        'success': false,
        'error': 'Scanner error: ${e.toString()}',
      };
    }
  }

  /// Check rate limiting
  bool _checkRateLimit() {
    final now = DateTime.now();

    // Remove scans older than rate limit period
    _recentScans.removeWhere(
      (scan) => now.difference(scan).inSeconds > _rateLimitPeriodSeconds,
    );

    if (_recentScans.length >= _maxScansPerPeriod) {
      print('[ScannerBridge] Rate limit exceeded: ${_recentScans.length} scans in ${_rateLimitPeriodSeconds}s');
      return false;
    }

    return true;
  }

  /// Convert BarcodeFormat enum to string
  String _formatToString(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        return 'EAN_13';
      case BarcodeFormat.ean8:
        return 'EAN_8';
      case BarcodeFormat.upcA:
        return 'UPC_A';
      case BarcodeFormat.upcE:
        return 'UPC_E';
      case BarcodeFormat.code128:
        return 'CODE_128';
      case BarcodeFormat.qrCode:
        return 'QR_CODE';
      default:
        return 'UNKNOWN';
    }
  }
}
