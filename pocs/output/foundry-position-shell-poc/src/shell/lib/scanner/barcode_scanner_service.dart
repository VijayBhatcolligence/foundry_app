// Phase 5: Barcode Scanner Service
// Purpose: Encapsulates mobile_scanner plugin integration and barcode detection logic

import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

/// Barcode format enum
enum BarcodeFormat {
  ean13,
  ean8,
  upcA,
  upcE,
  code128,
  qrCode,
  other,
}

/// Barcode scan result
class BarcodeResult {
  final String rawValue;
  final BarcodeFormat format;
  final DateTime timestamp;

  BarcodeResult({
    required this.rawValue,
    required this.format,
    required this.timestamp,
  });

  @override
  String toString() => 'BarcodeResult(value: $rawValue, format: $format, timestamp: $timestamp)';
}

/// Camera exception
class CameraException implements Exception {
  final String message;
  CameraException(this.message);

  @override
  String toString() => 'CameraException: $message';
}

/// Barcode Scanner Service - Encapsulates mobile_scanner integration
class BarcodeScannerService {
  ms.MobileScannerController? _controller;
  final StreamController<BarcodeResult> _resultController = StreamController<BarcodeResult>.broadcast();
  DateTime? _lastDetectionTime;
  static const int _detectionCooldownMs = 200;

  /// Stream of scan results
  Stream<BarcodeResult> get results => _resultController.stream;

  /// Check if torch is available
  Stream<bool> get isTorchAvailable async* {
    if (_controller != null) {
      yield _controller!.torchEnabled;
    } else {
      yield false;
    }
  }

  /// Start scanning with specified barcode formats
  Future<void> startScanning({
    required List<BarcodeFormat> formats,
    bool torchEnabled = false,
  }) async {
    try {
      print('[BarcodeScanner] Starting scanner with formats: $formats');

      // Convert our BarcodeFormat enum to mobile_scanner's BarcodeFormat
      final mobileScannerFormats = formats.map((f) => _convertFormat(f)).toList();

      _controller = ms.MobileScannerController(
        detectionSpeed: ms.DetectionSpeed.noDuplicates,
        facing: ms.CameraFacing.back,
        torchEnabled: torchEnabled,
      );

      // Start controller
      await _controller!.start();

      print('[BarcodeScanner] Scanner started successfully');
    } catch (e) {
      print('[BarcodeScanner] Failed to start scanner: $e');
      throw CameraException('Failed to initialize camera: $e');
    }
  }

  /// Stop scanning and release resources
  Future<void> stopScanning() async {
    try {
      print('[BarcodeScanner] Stopping scanner');
      await _controller?.stop();
      await _controller?.dispose();
      _controller = null;
      print('[BarcodeScanner] Scanner stopped');
    } catch (e) {
      print('[BarcodeScanner] Error stopping scanner: $e');
    }
  }

  /// Toggle flashlight
  Future<void> toggleTorch() async {
    try {
      if (_controller == null) {
        print('[BarcodeScanner] Cannot toggle torch: controller not initialized');
        return;
      }

      await _controller!.toggleTorch();
      print('[BarcodeScanner] Torch toggled: ${_controller!.torchEnabled}');
    } catch (e) {
      print('[BarcodeScanner] Error toggling torch: $e');
      // Don't throw - torch toggle is not critical
    }
  }

  /// Get the scanner controller
  ms.MobileScannerController? get controller => _controller;

  /// Process barcode detection from mobile_scanner
  void processBarcodes(ms.BarcodeCapture capture) {
    try {
      // Enforce cooldown period
      final now = DateTime.now();
      if (_lastDetectionTime != null) {
        final timeSinceLastDetection = now.difference(_lastDetectionTime!).inMilliseconds;
        if (timeSinceLastDetection < _detectionCooldownMs) {
          return; // Ignore detection during cooldown
        }
      }

      if (capture.barcodes.isEmpty) {
        return;
      }

      // Get first barcode (single scan mode)
      final barcode = capture.barcodes.first;

      if (barcode.rawValue == null || barcode.rawValue!.isEmpty) {
        return;
      }

      // Convert to our format
      final format = _convertMobileScannerFormat(barcode.format);

      // Filter out unsupported formats
      if (format == BarcodeFormat.other) {
        print('[BarcodeScanner] Ignoring unsupported format: ${barcode.format}');
        return;
      }

      final result = BarcodeResult(
        rawValue: barcode.rawValue!,
        format: format,
        timestamp: now,
      );

      _lastDetectionTime = now;

      print('[BarcodeScanner] Barcode detected: ${result.rawValue} (${result.format})');

      // Emit result
      _resultController.add(result);

    } catch (e) {
      print('[BarcodeScanner] Error processing barcode: $e');
    }
  }

  /// Convert our BarcodeFormat to mobile_scanner's BarcodeFormat
  ms.BarcodeFormat _convertFormat(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        return ms.BarcodeFormat.ean13;
      case BarcodeFormat.ean8:
        return ms.BarcodeFormat.ean8;
      case BarcodeFormat.upcA:
        return ms.BarcodeFormat.upcA;
      case BarcodeFormat.upcE:
        return ms.BarcodeFormat.upcE;
      case BarcodeFormat.code128:
        return ms.BarcodeFormat.code128;
      case BarcodeFormat.qrCode:
        return ms.BarcodeFormat.qrCode;
      default:
        return ms.BarcodeFormat.all;
    }
  }

  /// Convert mobile_scanner's BarcodeFormat to our BarcodeFormat
  BarcodeFormat _convertMobileScannerFormat(ms.BarcodeFormat format) {
    switch (format) {
      case ms.BarcodeFormat.ean13:
        return BarcodeFormat.ean13;
      case ms.BarcodeFormat.ean8:
        return BarcodeFormat.ean8;
      case ms.BarcodeFormat.upcA:
        return BarcodeFormat.upcA;
      case ms.BarcodeFormat.upcE:
        return BarcodeFormat.upcE;
      case ms.BarcodeFormat.code128:
        return BarcodeFormat.code128;
      case ms.BarcodeFormat.qrCode:
        return BarcodeFormat.qrCode;
      default:
        return BarcodeFormat.other;
    }
  }

  /// Dispose resources
  void dispose() {
    _resultController.close();
    _controller?.dispose();
  }
}
