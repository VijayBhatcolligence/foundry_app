// Modules Configuration - Port Registry and Module Definitions
// Part of Parallel Modules Architecture

/// Module Configuration
class ModuleConfig {
  final String id;
  final String name;
  final String description;
  final int port;
  final int priority; // 1 = highest priority (keep alive always)
  final bool keepAlive; // Always keep in memory
  final String assetPath;
  final String iconEmoji;

  const ModuleConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.port,
    this.priority = 5,
    this.keepAlive = false,
    required this.assetPath,
    this.iconEmoji = '📦',
  });

  /// Get module URL
  String getUrl() => 'http://localhost:$port/';

  /// Get module origin (for IndexedDB isolation)
  String getOrigin() => 'http://localhost:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'port': port,
        'priority': priority,
        'keepAlive': keepAlive,
        'assetPath': assetPath,
        'iconEmoji': iconEmoji,
        'url': getUrl(),
        'origin': getOrigin(),
      };
}

/// Module Registry - Centralized module definitions
class ModulesRegistry {
  /// All available modules
  static const List<ModuleConfig> modules = [
    ModuleConfig(
      id: 'test-quality-inspector',
      name: 'Quality Inspector',
      description: 'Defect lookup, inspection logs, report submission with photos',
      port: 8080,
      priority: 1,
      keepAlive: true,
      assetPath: 'assets/modules/test-quality-inspector',
      iconEmoji: '🔍',
    ),
    ModuleConfig(
      id: 'sample-warehouse',
      name: 'Warehouse Management',
      description: 'Receiving transactions, temperature checks, complaints',
      port: 8081,
      priority: 2,
      keepAlive: true,
      assetPath: 'assets/modules/sample-warehouse',
      iconEmoji: '📦',
    ),
    ModuleConfig(
      id: 'test-inventory-checker',
      name: 'Inventory Checker',
      description: 'Product search, stock counts, audit trail',
      port: 8082,
      priority: 3,
      keepAlive: false,
      assetPath: 'assets/modules/test-inventory-checker',
      iconEmoji: '📊',
    ),
  ];

  /// Get module by ID
  static ModuleConfig? getModule(String id) {
    try {
      return modules.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get module by port
  static ModuleConfig? getModuleByPort(int port) {
    try {
      return modules.firstWhere((m) => m.port == port);
    } catch (e) {
      return null;
    }
  }

  /// Get all module IDs
  static List<String> getAllModuleIds() {
    return modules.map((m) => m.id).toList();
  }

  /// Get all ports
  static List<int> getAllPorts() {
    return modules.map((m) => m.port).toList();
  }

  /// Get high priority modules (always keep alive)
  static List<ModuleConfig> getHighPriorityModules() {
    return modules.where((m) => m.keepAlive).toList();
  }

  /// Get modules sorted by priority
  static List<ModuleConfig> getModulesByPriority() {
    final sorted = List<ModuleConfig>.from(modules);
    sorted.sort((a, b) => a.priority.compareTo(b.priority));
    return sorted;
  }

  /// Check if port is allocated
  static bool isPortAllocated(int port) {
    return modules.any((m) => m.port == port);
  }

  /// Get next available port
  static int getNextAvailablePort([int startPort = 8080]) {
    final allocatedPorts = getAllPorts();
    int port = startPort;
    while (allocatedPorts.contains(port)) {
      port++;
    }
    return port;
  }

  /// Port range limits
  static const int minPort = 8080;
  static const int maxPort = 8100;

  /// Max concurrent active modules (for memory management)
  static const int maxConcurrentModules = 5;

  /// Module loading strategy
  static const bool lazyLoadWebViews = true; // Create WebView on-demand
  static const bool startAllServersOnLaunch = true; // Start all servers immediately
}
