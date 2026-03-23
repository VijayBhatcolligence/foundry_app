// D2.1: Module Downloader Service
// Purpose: Download module files with progress tracking, checksum validation, and retry logic

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class ModuleDownloader {
  // Track in-progress downloads
  final Map<String, _DownloadState> _activeDownloads = {};
  final Map<String, _RetryState> _retryState = {};

  // Maximum concurrent downloads
  static const int _maxConcurrentDownloads = 2;
  int _activeDownloadCount = 0;

  // Download module to temporary location, verify checksum, return temp path
  Future<DownloadResult> downloadModule({
    required String downloadUrl,
    required String expectedChecksum,
    required int expectedSizeBytes,
    void Function(DownloadProgress)? onProgress,
  }) async {
    // Check if already downloading this URL
    if (_activeDownloads.containsKey(downloadUrl)) {
      final existingState = _activeDownloads[downloadUrl]!;
      // Wait for existing download to complete
      return await existingState.completer.future;
    }

    // Queue if too many concurrent downloads
    while (_activeDownloadCount >= _maxConcurrentDownloads) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _activeDownloadCount++;

    final downloadState = _DownloadState();
    _activeDownloads[downloadUrl] = downloadState;

    try {
      final result = await _downloadWithRetry(
        downloadUrl: downloadUrl,
        expectedChecksum: expectedChecksum,
        expectedSizeBytes: expectedSizeBytes,
        onProgress: onProgress,
      );

      downloadState.completer.complete(result);
      return result;
    } catch (e) {
      final errorResult = DownloadResult(
        success: false,
        error: e.toString(),
        bytesDownloaded: 0,
        duration: Duration.zero,
        checksumValid: false,
      );
      downloadState.completer.complete(errorResult);
      return errorResult;
    } finally {
      _activeDownloads.remove(downloadUrl);
      _activeDownloadCount--;
    }
  }

  Future<DownloadResult> _downloadWithRetry({
    required String downloadUrl,
    required String expectedChecksum,
    required int expectedSizeBytes,
    void Function(DownloadProgress)? onProgress,
    int attempt = 1,
  }) async {
    final startTime = DateTime.now();

    try {
      return await _performDownload(
        downloadUrl: downloadUrl,
        expectedChecksum: expectedChecksum,
        expectedSizeBytes: expectedSizeBytes,
        onProgress: onProgress,
        startTime: startTime,
      );
    } catch (e) {
      // Determine if we should retry
      final shouldRetry = attempt < 3 && _shouldRetryError(e);

      if (!shouldRetry) {
        final duration = DateTime.now().difference(startTime);
        return DownloadResult(
          success: false,
          error: e.toString(),
          bytesDownloaded: 0,
          duration: duration,
          checksumValid: false,
        );
      }

      // Exponential backoff: 2s, 4s, 8s
      final delay = Duration(seconds: 2 << (attempt - 1));
      await Future.delayed(delay);

      // Retry
      return await _downloadWithRetry(
        downloadUrl: downloadUrl,
        expectedChecksum: expectedChecksum,
        expectedSizeBytes: expectedSizeBytes,
        onProgress: onProgress,
        attempt: attempt + 1,
      );
    }
  }

  Future<DownloadResult> _performDownload({
    required String downloadUrl,
    required String expectedChecksum,
    required int expectedSizeBytes,
    void Function(DownloadProgress)? onProgress,
    required DateTime startTime,
  }) async {
    // Create temp directory
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFilePath = path.join(
      tempDir.path,
      'module_downloads',
      'module-$timestamp.tmp',
    );

    // Ensure directory exists
    await Directory(path.dirname(tempFilePath)).create(recursive: true);

    // Start download with timeout
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 300));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      // Check Content-Length if available
      final contentLength = response.contentLength ?? expectedSizeBytes;
      if ((contentLength - expectedSizeBytes).abs() > expectedSizeBytes * 0.01) {
        print('Warning: Content-Length ($contentLength) differs from expected size ($expectedSizeBytes)');
      }

      // Download to file with progress tracking
      final file = File(tempFilePath);
      final sink = file.openWrite();
      int bytesDownloaded = 0;
      var lastProgressUpdate = DateTime.now();
      var lastProgressBytes = 0;

      await for (final chunk in response.stream) {
        bytesDownloaded += chunk.length;

        // Check size limit with 10% tolerance
        if (bytesDownloaded > expectedSizeBytes * 1.1) {
          await sink.close();
          await file.delete();
          throw Exception('Download size exceeds expected size by >10%');
        }

        sink.add(chunk);

        // Report progress (every 256 KB or 500ms)
        if (onProgress != null) {
          final now = DateTime.now();
          final timeSinceLastUpdate = now.difference(lastProgressUpdate).inMilliseconds;
          final bytesSinceLastUpdate = bytesDownloaded - lastProgressBytes;

          if (bytesSinceLastUpdate >= 262144 || timeSinceLastUpdate >= 500) {
            final elapsed = now.difference(startTime);
            final bytesPerSecond = elapsed.inSeconds > 0
                ? (bytesDownloaded / elapsed.inSeconds).round()
                : 0;

            // Check for very slow download (<1 KB/s for 60 seconds)
            if (elapsed.inSeconds >= 60 && bytesPerSecond < 1024) {
              await sink.close();
              await file.delete();
              throw Exception('Download too slow: $bytesPerSecond bytes/sec');
            }

            onProgress(DownloadProgress(
              bytesDownloaded: bytesDownloaded,
              totalBytes: contentLength,
              percentComplete: (bytesDownloaded / contentLength * 100).clamp(0.0, 100.0),
              elapsed: elapsed,
              bytesPerSecond: bytesPerSecond,
            ));

            lastProgressUpdate = now;
            lastProgressBytes = bytesDownloaded;
          }
        }
      }

      await sink.close();

      // Verify checksum
      final fileBytes = await file.readAsBytes();
      final actualChecksum = sha256.convert(fileBytes).toString();
      final checksumValid = actualChecksum == expectedChecksum;

      if (!checksumValid) {
        await file.delete();
        final duration = DateTime.now().difference(startTime);
        return DownloadResult(
          success: false,
          error: 'Checksum mismatch',
          bytesDownloaded: bytesDownloaded,
          duration: duration,
          checksumValid: false,
        );
      }

      // Success
      final duration = DateTime.now().difference(startTime);
      return DownloadResult(
        success: true,
        tempFilePath: tempFilePath,
        bytesDownloaded: bytesDownloaded,
        duration: duration,
        checksumValid: true,
      );
    } on TimeoutException {
      throw Exception('Download timeout after 300 seconds');
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on FileSystemException catch (e) {
      if (e.message.contains('No space')) {
        throw Exception('Disk full');
      }
      throw Exception('File system error: $e');
    } finally {
      client.close();
    }
  }

  bool _shouldRetryError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Don't retry checksum errors
    if (errorStr.contains('checksum')) return false;

    // Don't retry disk full errors
    if (errorStr.contains('disk full')) return false;

    // Don't retry 4xx errors (client errors)
    if (errorStr.contains('http 4')) return false;

    // Retry network errors, timeouts, and 5xx errors
    return true;
  }

  // Cancel in-progress download by URL
  Future<void> cancelDownload(String downloadUrl) async {
    final state = _activeDownloads[downloadUrl];
    if (state != null) {
      state.cancelled = true;
      _activeDownloads.remove(downloadUrl);
    }
  }

  // Check if download is currently in progress for URL
  bool isDownloading(String downloadUrl) {
    return _activeDownloads.containsKey(downloadUrl);
  }

  // Get current progress for download by URL (returns null if not downloading)
  DownloadProgress? getProgress(String downloadUrl) {
    final state = _activeDownloads[downloadUrl];
    return state?.currentProgress;
  }
}

class _DownloadState {
  final completer = Completer<DownloadResult>();
  bool cancelled = false;
  DownloadProgress? currentProgress;
}

class _RetryState {
  int attempts = 0;
  String? lastError;
  DateTime? nextRetryAt;
}

class DownloadResult {
  final bool success;
  final String? tempFilePath;
  final String? error;
  final int bytesDownloaded;
  final Duration duration;
  final bool checksumValid;

  DownloadResult({
    required this.success,
    this.tempFilePath,
    this.error,
    required this.bytesDownloaded,
    required this.duration,
    required this.checksumValid,
  });
}

class DownloadProgress {
  final int bytesDownloaded;
  final int totalBytes;
  final double percentComplete;
  final Duration elapsed;
  final int bytesPerSecond;

  DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.percentComplete,
    required this.elapsed,
    required this.bytesPerSecond,
  });
}
