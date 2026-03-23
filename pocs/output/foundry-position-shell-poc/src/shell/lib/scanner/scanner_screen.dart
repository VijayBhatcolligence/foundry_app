// Phase 5: Scanner Screen UI
// Purpose: Full-screen camera preview with scanner UI overlay, flashlight toggle, and cancel button

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'barcode_scanner_service.dart';

/// Scan mode enum
enum ScanMode {
  barcode,
  qrCode,
}

/// Scanner Screen - Full-screen camera view with scanner UI
class ScannerScreen extends StatefulWidget {
  final ScanMode mode;
  final Function(BarcodeResult) onDetected;
  final Function() onCancelled;

  const ScannerScreen({
    Key? key,
    required this.mode,
    required this.onDetected,
    required this.onCancelled,
  }) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final BarcodeScannerService _scannerService = BarcodeScannerService();
  bool _isInitialized = false;
  bool _isDetecting = false;
  String _statusText = 'Initializing camera...';
  Timer? _timeoutTimer;
  bool _torchEnabled = false;
  StreamSubscription<BarcodeResult>? _scanSubscription;

  static const int _timeoutSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitDown,
    ]);

    _timeoutTimer?.cancel();
    _scanSubscription?.cancel();
    _scannerService.stopScanning();
    _scannerService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for camera pause/resume
    if (state == AppLifecycleState.paused) {
      _scannerService.controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerService.controller?.start();
    }
  }

  /// Initialize scanner
  Future<void> _initializeScanner() async {
    try {
      print('[ScannerScreen] Initializing scanner: ${widget.mode.name}');
      final startTime = DateTime.now();

      // Determine formats based on mode
      final formats = widget.mode == ScanMode.barcode
          ? [
              BarcodeFormat.ean13,
              BarcodeFormat.ean8,
              BarcodeFormat.upcA,
              BarcodeFormat.upcE,
              BarcodeFormat.code128,
            ]
          : [BarcodeFormat.qrCode];

      await _scannerService.startScanning(formats: formats);

      final loadTime = DateTime.now().difference(startTime);
      print('[ScannerScreen] Camera opened in ${loadTime.inMilliseconds}ms');

      // Listen to scan results
      _scanSubscription = _scannerService.results.listen((result) {
        _handleBarcodeDetected(result);
      });

      setState(() {
        _isInitialized = true;
        _statusText = widget.mode == ScanMode.barcode
            ? 'Scan product barcode'
            : 'Scan location QR code';
      });

      // Start timeout timer
      _startTimeoutTimer();

    } catch (e) {
      print('[ScannerScreen] Scanner initialization failed: $e');
      setState(() {
        _statusText = 'Camera initialization failed';
      });

      // Show error dialog
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _showErrorDialog('Camera Error', 'Failed to initialize camera. Please check permissions and try again.');
      }
    }
  }

  /// Start timeout timer
  void _startTimeoutTimer() {
    _timeoutTimer = Timer(Duration(seconds: _timeoutSeconds), () {
      if (mounted && !_isDetecting) {
        _handleTimeout();
      }
    });
  }

  /// Handle barcode detection
  void _handleBarcodeDetected(BarcodeResult result) {
    if (_isDetecting) {
      return; // Already processing a detection
    }

    setState(() {
      _isDetecting = true;
      _statusText = 'Barcode detected!';
    });

    print('[ScannerScreen] Barcode detected: ${result.rawValue}');

    // Cancel timeout
    _timeoutTimer?.cancel();

    // Stop scanner
    _scannerService.stopScanning();

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    // Call detection callback
    widget.onDetected(result);
  }

  /// Handle timeout
  void _handleTimeout() {
    print('[ScannerScreen] Scanner timeout after ${_timeoutSeconds}s');

    // Show toast message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan timeout. Please try again or enter manually.'),
        duration: Duration(seconds: 2),
      ),
    );

    // Close scanner
    widget.onCancelled();
  }

  /// Handle cancel button
  void _handleCancel() {
    print('[ScannerScreen] Scan cancelled by user');
    _timeoutTimer?.cancel();
    _scannerService.stopScanning();
    widget.onCancelled();
  }

  /// Toggle flashlight
  Future<void> _handleTorchToggle() async {
    await _scannerService.toggleTorch();
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  /// Show error dialog
  Future<void> _showErrorDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleCancel();
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _initializeScanner();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isInitialized && _scannerService.controller != null)
            ms.MobileScanner(
              controller: _scannerService.controller!,
              onDetect: (capture) {
                _scannerService.processBarcodes(capture);
              },
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Scanner overlay
          if (_isInitialized)
            CustomPaint(
              painter: ScannerOverlayPainter(),
              child: Container(),
            ),

          // Top bar with title and cancel button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.mode == ScanMode.barcode ? 'Scan Barcode' : 'Scan QR Code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Cancel button
                  IconButton(
                    onPressed: _handleCancel,
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar with status and controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flashlight toggle
                    if (_isInitialized)
                      FloatingActionButton(
                        onPressed: _handleTorchToggle,
                        backgroundColor: _torchEnabled ? Colors.amber : Colors.white24,
                        child: Icon(
                          _torchEnabled ? Icons.flash_on : Icons.flash_off,
                          color: _torchEnabled ? Colors.black : Colors.white,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Status text
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Help text
                    Text(
                      'Position the ${widget.mode == ScanMode.barcode ? 'barcode' : 'QR code'} within the frame',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scanner overlay painter - Draws scanning reticle
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Calculate reticle size and position
    final reticleWidth = size.width * 0.7;
    final reticleHeight = size.height * 0.3;
    final left = (size.width - reticleWidth) / 2;
    final top = (size.height - reticleHeight) / 2;

    final rect = Rect.fromLTWH(left, top, reticleWidth, reticleHeight);

    // Draw corner brackets
    const cornerLength = 30.0;

    // Top-left
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );

    // Draw scanning line animation would go here
    // (Omitted for simplicity - static reticle is sufficient)
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
