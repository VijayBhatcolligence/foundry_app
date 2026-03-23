// D1.1: Module Manifest Structure
// Purpose: Parse and validate module metadata from JSON manifests

class ModuleManifest {
  final String moduleId;
  final String version;
  final String requiredShellVersion;
  final String signature;
  final String downloadUrl;
  final String checksum;
  final int downloadSizeBytes;
  final DateTime publishedAt;
  final Map<String, dynamic> metadata;

  ModuleManifest({
    required this.moduleId,
    required this.version,
    required this.requiredShellVersion,
    required this.signature,
    required this.downloadUrl,
    required this.checksum,
    required this.downloadSizeBytes,
    required this.publishedAt,
    this.metadata = const {},
  });

  factory ModuleManifest.fromJson(Map<String, dynamic> json) {
    // Check for required fields and throw FormatException if missing
    final requiredFields = [
      'moduleId',
      'version',
      'requiredShellVersion',
      'signature',
      'downloadUrl',
      'checksum',
      'downloadSizeBytes',
      'publishedAt',
    ];

    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        throw FormatException('Missing required field: $field');
      }
      if (json[field] == null) {
        throw FormatException('Field $field cannot be null');
      }
    }

    try {
      return ModuleManifest(
        moduleId: json['moduleId'] as String,
        version: json['version'] as String,
        requiredShellVersion: json['requiredShellVersion'] as String,
        signature: json['signature'] as String,
        downloadUrl: json['downloadUrl'] as String,
        checksum: json['checksum'] as String,
        downloadSizeBytes: json['downloadSizeBytes'] as int,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      );
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Invalid JSON format: ${e.toString()}');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'moduleId': moduleId,
      'version': version,
      'requiredShellVersion': requiredShellVersion,
      'signature': signature,
      'downloadUrl': downloadUrl,
      'checksum': checksum,
      'downloadSizeBytes': downloadSizeBytes,
      'publishedAt': publishedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Validation result with detailed error information
  ManifestValidationResult validate() {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate moduleId: ^[a-z][a-z0-9-]{2,63}$
    final moduleIdPattern = RegExp(r'^[a-z][a-z0-9-]{2,63}$');
    if (!moduleIdPattern.hasMatch(moduleId)) {
      errors.add('moduleId must match pattern ^[a-z][a-z0-9-]{2,63}\$');
    }

    // Validate version: semantic version format MAJOR.MINOR.PATCH
    final versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionPattern.hasMatch(version)) {
      errors.add('version must be valid semantic version (MAJOR.MINOR.PATCH)');
    }

    // Validate requiredShellVersion: should be valid semver range
    // Basic validation for common patterns: ^1.0.0, ~1.0.0, >=1.0.0, 1.0.0, etc.
    final rangePattern = RegExp(r'^[\^~>=<]?\d+\.\d+\.\d+');
    if (!rangePattern.hasMatch(requiredShellVersion)) {
      errors.add('requiredShellVersion must be valid semantic version range');
    }

    // Validate signature: 344 base64 characters for RSA-2048
    if (signature.length != 344) {
      errors.add('signature must be 344 base64 characters');
    }
    // Basic base64 validation
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
    if (!base64Pattern.hasMatch(signature)) {
      errors.add('signature must be valid base64');
    }

    // Validate checksum: 64 hexadecimal characters (SHA-256)
    final checksumPattern = RegExp(r'^[a-f0-9]{64}$');
    if (!checksumPattern.hasMatch(checksum)) {
      errors.add('checksum must be 64 hexadecimal characters');
    }

    // Validate downloadUrl: must be HTTPS
    try {
      final uri = Uri.parse(downloadUrl);
      if (uri.scheme != 'https') {
        errors.add('downloadUrl must use HTTPS scheme');
      }
      if (downloadUrl.length > 2048) {
        errors.add('downloadUrl exceeds maximum length of 2048 characters');
      }
    } catch (e) {
      errors.add('downloadUrl must be a valid URL');
    }

    // Validate downloadSizeBytes: 1 to 52428800 (50 MB)
    if (downloadSizeBytes < 1 || downloadSizeBytes > 52428800) {
      errors.add('downloadSizeBytes exceeds maximum 52428800 (50 MB)');
    }

    // Validate publishedAt: warn if in future
    if (publishedAt.isAfter(DateTime.now())) {
      warnings.add('publishedAt is in the future');
    }

    return ManifestValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

class ManifestValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ManifestValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}
