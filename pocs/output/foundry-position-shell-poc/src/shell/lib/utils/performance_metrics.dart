// Phase 3: Performance Measurement Utility
// Purpose: Measure and log cache load performance to verify < 200ms threshold

import 'dart:async';

class PerformanceMetrics {
  // Storage for metrics: operation name -> list of durations (max 100)
  static final Map<String, List<Duration>> _metrics = {};
  static const int _maxStoredMetrics = 100;

  /// Measure execution time of an async operation
  static Future<T> measure<T>(String operationName, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      logMetric(operationName, stopwatch.elapsed);

      return result;
    } catch (e) {
      // Log duration even on error, then re-throw
      stopwatch.stop();
      logMetric(operationName, stopwatch.elapsed);
      rethrow;
    }
  }

  /// Log a metric duration
  static void logMetric(String name, Duration duration) {
    // Store in memory
    _metrics.putIfAbsent(name, () => []);
    _metrics[name]!.add(duration);

    // Keep only last 100 measurements
    if (_metrics[name]!.length > _maxStoredMetrics) {
      _metrics[name]!.removeAt(0);
    }

    // Handle measurement overflow (> 1 hour)
    if (duration.inMilliseconds > 3600000) {
      print('[PERF] WARNING: $name: ${duration.inMilliseconds}ms (exceeds 1 hour, possible timer overflow)');
      return;
    }

    // Log to console in debug mode
    print('[PERF] $name: ${duration.inMilliseconds}ms');
  }

  /// Get all stored metrics
  static Map<String, List<Duration>> getAllMetrics() {
    return Map.unmodifiable(_metrics);
  }

  /// Get average duration for an operation
  static Duration? getAverageDuration(String operationName) {
    final durations = _metrics[operationName];
    if (durations == null || durations.isEmpty) return null;

    final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    final avgMs = totalMs ~/ durations.length;
    return Duration(milliseconds: avgMs);
  }

  /// Get latest duration for an operation
  static Duration? getLatestDuration(String operationName) {
    final durations = _metrics[operationName];
    if (durations == null || durations.isEmpty) return null;
    return durations.last;
  }

  /// Clear all stored metrics
  static void clearMetrics() {
    _metrics.clear();
  }

  /// Clear metrics for specific operation
  static void clearMetricsFor(String operationName) {
    _metrics.remove(operationName);
  }
}
