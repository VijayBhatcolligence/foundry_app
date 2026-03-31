// Multi-Module Screen - Parallel execution UI
// Part of Parallel Modules Architecture
// Shows multiple WebViews with Stack + Visibility pattern (no destruction on switch)

import 'package:flutter/material.dart';
import '../config/modules_config.dart';
import '../webview/multi_webview_manager.dart';
import '../webview/webview_state.dart';

class MultiModuleScreen extends StatefulWidget {
  final String initialModuleId;

  const MultiModuleScreen({
    Key? key,
    required this.initialModuleId,
  }) : super(key: key);

  @override
  State<MultiModuleScreen> createState() => _MultiModuleScreenState();
}

class _MultiModuleScreenState extends State<MultiModuleScreen>
    with WidgetsBindingObserver {
  final MultiWebViewManager _manager = MultiWebViewManager();
  String? _currentModuleId;
  final Map<String, Widget> _webViewWidgets = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentModuleId = widget.initialModuleId;
    _loadInitialModule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle
    if (state == AppLifecycleState.paused) {
      // App going to background - could pause non-current WebViews here
      print('[MultiModuleScreen] App paused');
    } else if (state == AppLifecycleState.resumed) {
      print('[MultiModuleScreen] App resumed');
    }
  }

  /// Load initial module
  Future<void> _loadInitialModule() async {
    setState(() => _isLoading = true);

    try {
      print('[MultiModuleScreen] Loading initial module: ${widget.initialModuleId}');

      // Create WebView for initial module
      final webViewWidget = await _manager.getOrCreateWebView(widget.initialModuleId);
      _webViewWidgets[widget.initialModuleId] = webViewWidget;

      // Set as current
      _manager.switchToModule(widget.initialModuleId);

      setState(() => _isLoading = false);

      print('[MultiModuleScreen] ✅ Initial module loaded');
    } catch (e) {
      print('[MultiModuleScreen] ❌ Error loading initial module: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Switch to a different module
  Future<void> _switchModule(String moduleId) async {
    if (_currentModuleId == moduleId) {
      print('[MultiModuleScreen] Already on module $moduleId');
      return;
    }

    print('[MultiModuleScreen] Switching to module: $moduleId');

    try {
      // Check if WebView already exists
      if (!_webViewWidgets.containsKey(moduleId)) {
        // Create WebView on-demand (lazy loading)
        setState(() => _isLoading = true);

        print('[MultiModuleScreen] Creating WebView for $moduleId...');
        final webViewWidget = await _manager.getOrCreateWebView(moduleId);
        _webViewWidgets[moduleId] = webViewWidget;

        setState(() => _isLoading = false);
        print('[MultiModuleScreen] ✅ WebView created');
      }

      // Switch to module (updates state in manager)
      _manager.switchToModule(moduleId);

      // Update UI
      setState(() {
        _currentModuleId = moduleId;
      });

      print('[MultiModuleScreen] ✅ Switched to $moduleId');
      _manager.printStatus();
    } catch (e) {
      print('[MultiModuleScreen] ❌ Error switching module: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Show module picker dialog
  Future<void> _showModulePicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Module'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ModulesRegistry.modules.length,
            itemBuilder: (context, index) {
              final config = ModulesRegistry.modules[index];
              final isCurrent = config.id == _currentModuleId;
              final isLoaded = _manager.isModuleLoaded(config.id);

              return ListTile(
                leading: Text(
                  config.iconEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(config.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    // Show localhost URL
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        config.getUrl(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Port badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ':${config.port}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLoaded)
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    if (isCurrent)
                      const Icon(Icons.visibility, color: Colors.blue),
                  ],
                ),
                selected: isCurrent,
                onTap: () {
                  Navigator.pop(context, config.id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && selected != _currentModuleId) {
      await _switchModule(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentConfig = ModulesRegistry.getModule(_currentModuleId ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentConfig != null) ...[
                  Text(currentConfig.iconEmoji),
                  const SizedBox(width: 8),
                  Text(currentConfig.name),
                ] else
                  const Text('Module'),
              ],
            ),
            // Show localhost URL
            if (currentConfig != null)
              Text(
                currentConfig.getUrl(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
          ],
        ),
        actions: [
          // Active modules indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${_manager.registry.activeCount}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Switch module button
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: 'Switch Module',
            onPressed: _showModulePicker,
          ),
        ],
      ),
      body: _buildBody(),
      // Dev tools in debug mode
      floatingActionButton: _buildDebugFab(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading module...'),
          ],
        ),
      );
    }

    if (_webViewWidgets.isEmpty) {
      return const Center(
        child: Text('No modules loaded'),
      );
    }

    // CORE FEATURE: Stack with Visibility for parallel execution
    // All WebViews stay alive, we just show/hide them
    return Column(
      children: [
        // Localhost info banner
        _buildLocalhostBanner(),
        // WebView stack
        Expanded(
          child: Stack(
            children: _webViewWidgets.entries.map((entry) {
              final moduleId = entry.key;
              final widget = entry.value;
              final isVisible = moduleId == _currentModuleId;

              return Visibility(
                key: ValueKey(moduleId),
                visible: isVisible,
                maintainState: true, // CRITICAL: Keeps state when hidden
                child: widget,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Build localhost info banner
  Widget _buildLocalhostBanner() {
    final currentConfig = ModulesRegistry.getModule(_currentModuleId ?? '');
    if (currentConfig == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Globe icon
          const Icon(
            Icons.language,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          // URL
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentConfig.getUrl(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Origin: ${currentConfig.getOrigin()} (Isolated IndexedDB)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // Port badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Port ${currentConfig.port}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildDebugFab() {
    // Only show in debug mode
    if (const bool.fromEnvironment('dart.vm.product')) {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: () {
        _manager.printStatus();
        // Show debug dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Info'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Active WebViews: ${_manager.registry.activeCount}'),
                  Text('Max Concurrent: ${ModulesRegistry.maxConcurrentModules}'),
                  Text('Current: $_currentModuleId'),
                  const SizedBox(height: 16),
                  const Text('Loaded Modules:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._manager.registry.getAllInfo().map((info) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        '${info.state.emoji} ${info.moduleName} - ${info.state.displayName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _manager.disposeAll();
                  Navigator.pop(context);
                },
                child: const Text('Dispose Unused'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.bug_report),
      label: Text('${_manager.registry.activeCount}'),
    );
  }
}
