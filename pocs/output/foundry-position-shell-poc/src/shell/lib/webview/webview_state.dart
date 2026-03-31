// WebView State - Lifecycle states for parallel module execution
// Part of Parallel Modules Architecture

/// WebView lifecycle state
enum WebViewState {
  /// WebView not created yet
  notLoaded,

  /// WebView is being created/initialized
  loading,

  /// WebView created and running in background (not visible)
  background,

  /// WebView visible and in foreground
  foreground,

  /// WebView paused to save resources (optional optimization)
  paused,

  /// WebView disposed/destroyed
  disposed,
}

/// Extension for WebView state
extension WebViewStateExtension on WebViewState {
  /// Check if WebView is active (exists in memory)
  bool get isActive {
    return this == WebViewState.background ||
        this == WebViewState.foreground ||
        this == WebViewState.paused;
  }

  /// Check if WebView is visible
  bool get isVisible {
    return this == WebViewState.foreground;
  }

  /// Check if WebView can be used
  bool get isUsable {
    return this == WebViewState.background || this == WebViewState.foreground;
  }

  /// Get display string
  String get displayName {
    switch (this) {
      case WebViewState.notLoaded:
        return 'Not Loaded';
      case WebViewState.loading:
        return 'Loading...';
      case WebViewState.background:
        return 'Background';
      case WebViewState.foreground:
        return 'Active';
      case WebViewState.paused:
        return 'Paused';
      case WebViewState.disposed:
        return 'Disposed';
    }
  }

  /// Get emoji indicator
  String get emoji {
    switch (this) {
      case WebViewState.notLoaded:
        return '⚪';
      case WebViewState.loading:
        return '🔄';
      case WebViewState.background:
        return '⏸️';
      case WebViewState.foreground:
        return '▶️';
      case WebViewState.paused:
        return '⏯️';
      case WebViewState.disposed:
        return '❌';
    }
  }
}

/// WebView info - Metadata about a WebView instance
class WebViewInfo {
  final String moduleId;
  final String moduleName;
  final String url;
  final WebViewState state;
  final DateTime createdAt;
  final DateTime? lastAccessedAt;
  final int accessCount;

  const WebViewInfo({
    required this.moduleId,
    required this.moduleName,
    required this.url,
    required this.state,
    required this.createdAt,
    this.lastAccessedAt,
    this.accessCount = 0,
  });

  WebViewInfo copyWith({
    String? moduleId,
    String? moduleName,
    String? url,
    WebViewState? state,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    int? accessCount,
  }) {
    return WebViewInfo(
      moduleId: moduleId ?? this.moduleId,
      moduleName: moduleName ?? this.moduleName,
      url: url ?? this.url,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moduleId': moduleId,
      'moduleName': moduleName,
      'url': url,
      'state': state.displayName,
      'stateEmoji': state.emoji,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'accessCount': accessCount,
      'isActive': state.isActive,
      'isVisible': state.isVisible,
    };
  }
}
