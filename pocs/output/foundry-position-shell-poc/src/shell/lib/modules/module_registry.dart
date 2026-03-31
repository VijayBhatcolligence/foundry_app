// D1.2: Module Registry Service
// Purpose: Track available modules, versions, and installation state

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'module_manifest.dart';

class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._internal();
  factory ModuleRegistry() => instance;
  ModuleRegistry._internal();

  // In-memory registry storage: moduleId -> List<ModuleMetadata> sorted by version descending
  final Map<String, List<ModuleMetadata>> _registry = {};
  bool _isLoaded = false;
  Database? _database;

  // Returns null if module not found, otherwise latest compatible version
  Future<ModuleMetadata?> getLatestVersion(String moduleId) async {
    if (!_isLoaded) return null;

    final versions = _registry[moduleId];
    if (versions == null || versions.isEmpty) return null;

    // Return first version (already sorted descending)
    // TODO: Filter by shell compatibility when CompatibilityChecker is available
    return versions.first;
  }

  // Returns empty list if module not found or no cached versions
  Future<List<String>> getCachedVersions(String moduleId) async {
    final db = await _getDatabase();
    final results = await db.query(
      'installed_modules',
      columns: ['version'],
      where: 'module_id = ?',
      whereArgs: [moduleId],
      orderBy: 'installed_at DESC',
    );
    return results.map((row) => row['version'] as String).toList();
  }

  // Returns null if not installed/cached
  Future<String?> getInstalledVersion(String moduleId) async {
    final versions = await getCachedVersions(moduleId);
    return versions.isNotEmpty ? versions.first : null;
  }

  // Returns null if module not found in registry
  Future<ModuleMetadata?> getModuleMetadata(
      String moduleId, String version) async {
    if (!_isLoaded) return null;

    final versions = _registry[moduleId];
    if (versions == null) return null;

    try {
      return versions.firstWhere((m) => m.version == version);
    } catch (e) {
      return null;
    }
  }

  // Returns all modules in registry (empty list if registry not loaded)
  Future<List<ModuleMetadata>> getAvailableModules() async {
    if (!_isLoaded) return [];

    final allModules = <ModuleMetadata>[];
    for (final versions in _registry.values) {
      allModules.addAll(versions);
    }
    return allModules;
  }

  // Phase 3.5: Returns list of unique modules (latest version only) for selection UI
  Future<List<ModuleMetadata>> getModulesForSelection() async {
    if (!_isLoaded) return [];

    final displayModules = <ModuleMetadata>[];
    for (final moduleId in _registry.keys) {
      final latestVersion = await getLatestVersion(moduleId);
      if (latestVersion != null) {
        displayModules.add(latestVersion);
      }
    }

    // Sort by displayName for consistent UI
    displayModules.sort((a, b) => a.displayName.compareTo(b.displayName));
    return displayModules;
  }

  // Mark version as installed/cached
  Future<void> markVersionInstalled(String moduleId, String version) async {
    try {
      final db = await _getDatabase();
      await db.insert(
        'installed_modules',
        {
          'module_id': moduleId,
          'version': version,
          'installed_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Update isInstalled flag in registry
      if (_registry.containsKey(moduleId)) {
        for (var metadata in _registry[moduleId]!) {
          if (metadata.version == version) {
            metadata.isInstalled = true;
          }
        }
      }
    } catch (e) {
      throw StateError('Failed to update module installation state: $e');
    }
  }

  // Remove version from installed cache list
  Future<void> markVersionUninstalled(String moduleId, String version) async {
    try {
      final db = await _getDatabase();
      await db.delete(
        'installed_modules',
        where: 'module_id = ? AND version = ?',
        whereArgs: [moduleId, version],
      );

      // Update isInstalled flag in registry
      if (_registry.containsKey(moduleId)) {
        for (var metadata in _registry[moduleId]!) {
          if (metadata.version == version) {
            metadata.isInstalled = false;
          }
        }
      }
    } catch (e) {
      throw StateError('Failed to update module installation state: $e');
    }
  }

  // Load registry from remote manifest URL
  Future<RegistryLoadResult> loadRegistry(String registryUrl) async {
    final startTime = DateTime.now();

    try {
      // POC mode: Handle mock registry URL
      if (registryUrl.startsWith('mock://')) {
        print('[ModuleRegistry] POC mode: Using mock registry data');
        return _loadMockRegistry();
      }

      // HTTP request with 30-second timeout
      final response = await http
          .get(Uri.parse(registryUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return RegistryLoadResult(
          success: false,
          modulesLoaded: 0,
          error: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          loadedAt: DateTime.now(),
        );
      }

      // Check size limit: 5 MB
      if (response.bodyBytes.length > 5 * 1024 * 1024) {
        return RegistryLoadResult(
          success: false,
          modulesLoaded: 0,
          error: 'Registry too large',
          loadedAt: DateTime.now(),
        );
      }

      // Parse JSON
      final Map<String, dynamic> registryJson;
      try {
        registryJson = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return RegistryLoadResult(
          success: false,
          modulesLoaded: 0,
          error: 'Invalid JSON: $e',
          loadedAt: DateTime.now(),
        );
      }

      // Parse modules array
      final modulesJson = registryJson['modules'] as List<dynamic>? ?? [];

      // Clear existing registry
      _registry.clear();

      int loadedCount = 0;
      final installedModules = await _getAllInstalledModules();

      for (final moduleJson in modulesJson) {
        if (loadedCount >= 1000) {
          print('Warning: Registry contains more than 1000 modules, additional modules ignored');
          break;
        }

        try {
          final manifest = ModuleManifest.fromJson(moduleJson as Map<String, dynamic>);
          final validation = manifest.validate();

          if (!validation.isValid) {
            print('Warning: Invalid module metadata for ${manifest.moduleId}, skipping');
            continue;
          }

          final isInstalled = installedModules.any(
            (m) => m['module_id'] == manifest.moduleId && m['version'] == manifest.version,
          );

          final metadata = ModuleMetadata.fromManifest(manifest, isInstalled: isInstalled);

          // Add to registry
          _registry.putIfAbsent(manifest.moduleId, () => []);

          // Check for duplicate versions
          if (_registry[manifest.moduleId]!.any((m) => m.version == manifest.version)) {
            print('Warning: Duplicate version ${manifest.version} for ${manifest.moduleId}, keeping first occurrence');
            continue;
          }

          _registry[manifest.moduleId]!.add(metadata);
          loadedCount++;
        } catch (e) {
          print('Warning: Failed to parse module metadata, skipping: $e');
          continue;
        }
      }

      // Sort versions descending and keep only most recent 50
      for (final moduleId in _registry.keys) {
        _registry[moduleId]!.sort((a, b) => _compareVersions(b.version, a.version));
        if (_registry[moduleId]!.length > 50) {
          print('Warning: Module $moduleId has more than 50 versions, keeping only most recent 50');
          _registry[moduleId] = _registry[moduleId]!.take(50).toList();
        }
      }

      _isLoaded = true;

      return RegistryLoadResult(
        success: true,
        modulesLoaded: loadedCount,
        error: null,
        loadedAt: DateTime.now(),
      );
    } on http.ClientException catch (e) {
      return RegistryLoadResult(
        success: false,
        modulesLoaded: 0,
        error: 'Network error: $e',
        loadedAt: DateTime.now(),
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return RegistryLoadResult(
          success: false,
          modulesLoaded: 0,
          error: 'Timeout loading registry after 30 seconds',
          loadedAt: DateTime.now(),
        );
      }
      return RegistryLoadResult(
        success: false,
        modulesLoaded: 0,
        error: 'Error: $e',
        loadedAt: DateTime.now(),
      );
    }
  }

  // Returns true if registry has been loaded at least once
  bool get isRegistryLoaded => _isLoaded;

  // Private helper: Get database instance
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'module_registry.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE installed_modules (
            module_id TEXT NOT NULL,
            version TEXT NOT NULL,
            installed_at INTEGER NOT NULL,
            PRIMARY KEY (module_id, version)
          )
        ''');
      },
    );

    return _database!;
  }

  // Private helper: Get all installed modules from database
  Future<List<Map<String, dynamic>>> _getAllInstalledModules() async {
    final db = await _getDatabase();
    return await db.query('installed_modules');
  }

  // Private helper: Compare semantic versions
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }

  // Private helper: Load mock registry for POC
  Future<RegistryLoadResult> _loadMockRegistry() async {
    try {
      // Phase 4-5: Mock registry with 3 modules (sample-warehouse + 2 test modules)
      final mockRegistryJson = {
        'modules': [
          {
            'moduleId': 'sample-warehouse',
            'version': '1.0.0',
            'requiredShellVersion': '^1.0.0',
            'signature': 'A' * 344, // Mock RSA-2048 signature (344 base64 chars)
            'downloadUrl': 'https://mock.foundry.example/modules/sample-warehouse/1.0.0/module.js',
            'checksum': 'a' * 64, // Mock SHA-256 checksum
            'downloadSizeBytes': 1024000,
            'publishedAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
            'metadata': {
              'displayName': 'Warehouse Clerk',
              'description': 'Receive goods against purchase orders and scan item barcodes',
              'categoryId': 'warehouse',
              'author': 'Foundry Team',
            },
          },
          {
            'moduleId': 'test-inventory-checker',
            'version': '1.0.0',
            'requiredShellVersion': '^1.0.0',
            'signature': 'B' * 344,
            'downloadUrl': 'https://mock.foundry.example/modules/test-inventory-checker/1.0.0/module.js',
            'checksum': 'b' * 64,
            'downloadSizeBytes': 186368,
            'publishedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'metadata': {
              'displayName': 'Test: Inventory Checker',
              'description': 'Demonstrates hybrid architecture with product search, stock counts, and audit trail',
              'categoryId': 'testing',
              'author': 'Foundry Team',
            },
          },
          {
            'moduleId': 'test-quality-inspector',
            'version': '1.0.0',
            'requiredShellVersion': '^1.0.0',
            'signature': 'C' * 344,
            'downloadUrl': 'https://mock.foundry.example/modules/test-quality-inspector/1.0.0/module.js',
            'checksum': 'c' * 64,
            'downloadSizeBytes': 180224,
            'publishedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'metadata': {
              'displayName': 'Test: Quality Inspector',
              'description': 'Validates module isolation with defect lookup, inspection logs, and reports',
              'categoryId': 'testing',
              'author': 'Foundry Team',
            },
          },
        ],
      };

      // Parse mock data
      final modulesJson = mockRegistryJson['modules'] as List<dynamic>;
      _registry.clear();

      int loadedCount = 0;
      for (final moduleJson in modulesJson) {
        try {
          final manifest = ModuleManifest.fromJson(moduleJson as Map<String, dynamic>);
          final metadata = ModuleMetadata.fromManifest(manifest, isInstalled: false);

          _registry.putIfAbsent(manifest.moduleId, () => []);
          _registry[manifest.moduleId]!.add(metadata);
          loadedCount++;
        } catch (e) {
          print('Warning: Failed to parse mock module metadata: $e');
        }
      }

      // Sort versions descending
      for (final moduleId in _registry.keys) {
        _registry[moduleId]!.sort((a, b) => _compareVersions(b.version, a.version));
      }

      _isLoaded = true;

      print('[ModuleRegistry] Mock registry loaded: $loadedCount modules');

      return RegistryLoadResult(
        success: true,
        modulesLoaded: loadedCount,
        error: null,
        loadedAt: DateTime.now(),
      );
    } catch (e) {
      return RegistryLoadResult(
        success: false,
        modulesLoaded: 0,
        error: 'Mock registry load failed: $e',
        loadedAt: DateTime.now(),
      );
    }
  }
}

class ModuleMetadata {
  final String moduleId;
  final String version;
  final String requiredShellVersion;
  final String downloadUrl;
  final String checksum;
  final String signature;
  final int downloadSizeBytes;
  final DateTime publishedAt;
  bool isInstalled;
  final Map<String, dynamic> metadata;

  // Phase 3.5: Display metadata for module selection UI
  final String displayName;
  final String description;
  final String? categoryId;

  ModuleMetadata({
    required this.moduleId,
    required this.version,
    required this.requiredShellVersion,
    required this.downloadUrl,
    required this.checksum,
    required this.signature,
    required this.downloadSizeBytes,
    required this.publishedAt,
    required this.isInstalled,
    this.metadata = const {},
    required this.displayName,
    required this.description,
    this.categoryId,
  });

  factory ModuleMetadata.fromManifest(ModuleManifest manifest,
      {bool isInstalled = false}) {
    return ModuleMetadata(
      moduleId: manifest.moduleId,
      version: manifest.version,
      requiredShellVersion: manifest.requiredShellVersion,
      downloadUrl: manifest.downloadUrl,
      checksum: manifest.checksum,
      signature: manifest.signature,
      downloadSizeBytes: manifest.downloadSizeBytes,
      publishedAt: manifest.publishedAt,
      isInstalled: isInstalled,
      metadata: manifest.metadata,
      displayName: manifest.metadata['displayName'] as String? ?? manifest.moduleId,
      description: manifest.metadata['description'] as String? ?? '',
      categoryId: manifest.metadata['categoryId'] as String?,
    );
  }
}

class RegistryLoadResult {
  final bool success;
  final int modulesLoaded;
  final String? error;
  final DateTime loadedAt;

  RegistryLoadResult({
    required this.success,
    required this.modulesLoaded,
    this.error,
    required this.loadedAt,
  });
}
