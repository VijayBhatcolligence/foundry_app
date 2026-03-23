// Phase 5.1: Photo Capture Screen
// Purpose: Full-screen camera preview widget with capture and preview confirmation UI

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'photo_capture_service.dart';

/// Photo Capture Screen - Full-screen camera with capture/preview UI
class PhotoCaptureScreen extends StatefulWidget {
  final Function(String photoPath) onPhotoConfirmed;
  final Function() onCancelled;

  const PhotoCaptureScreen({
    Key? key,
    required this.onPhotoConfirmed,
    required this.onCancelled,
  }) : super(key: key);

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final PhotoCaptureService _captureService = PhotoCaptureService();

  bool _isLoading = true;
  bool _isCapturing = false;
  String? _errorMessage;
  CapturedPhoto? _capturedPhoto;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Initialize camera
  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _captureService.startCamera();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[PhotoCaptureScreen] Camera initialization error: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Capture photo
  Future<void> _handleCapture() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final capturedPhoto = await _captureService.capturePhoto();

      if (mounted) {
        setState(() {
          _capturedPhoto = capturedPhoto;
          _isCapturing = false;
        });
      }
    } catch (e) {
      print('[PhotoCaptureScreen] Capture error: $e');

      if (mounted) {
        setState(() {
          _isCapturing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Retake photo
  void _handleRetake() {
    setState(() {
      _capturedPhoto = null;
    });
  }

  /// Confirm photo
  void _handleConfirm() {
    if (_capturedPhoto != null) {
      widget.onPhotoConfirmed(_capturedPhoto!.file.path);
      _cleanup();
      Navigator.pop(context);
    }
  }

  /// Cancel capture
  void _handleCancel() {
    _cleanup();
    widget.onCancelled();
    Navigator.pop(context);
  }

  /// Cleanup camera resources
  void _cleanup() {
    _captureService.dispose();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleCancel();
        return false; // Prevent default pop behavior
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  /// Build body based on state
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_capturedPhoto != null) {
      return _buildPreviewView();
    }

    return _buildCameraView();
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Opening camera...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build camera preview view
  Widget _buildCameraView() {
    if (_captureService.controller == null || !_captureService.isInitialized) {
      return const Center(
        child: Text(
          'Camera not ready',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // Full-screen camera preview
        Positioned.fill(
          child: CameraPreview(_captureService.controller!),
        ),

        // Top bar with cancel button
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  tooltip: 'Cancel',
                ),
                const Spacer(),
              ],
            ),
          ),
        ),

        // Bottom bar with capture button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: _isCapturing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : GestureDetector(
                      onTap: _handleCapture,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build preview view
  Widget _buildPreviewView() {
    if (_capturedPhoto == null) {
      return const Center(child: Text('No photo'));
    }

    return Stack(
      children: [
        // Full-screen image preview
        Positioned.fill(
          child: Image.file(
            File(_capturedPhoto!.file.path),
            fit: BoxFit.contain,
          ),
        ),

        // Bottom bar with Retake and Confirm buttons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Retake button
                ElevatedButton.icon(
                  onPressed: _handleRetake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                // Confirm button
                ElevatedButton.icon(
                  onPressed: _handleConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
