import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Mock authentication service simulating system browser OAuth flow
///
/// SECURITY BOUNDARY: Shell tokens are stored ONLY in secure storage
/// and NEVER exposed to the web layer or bridge API.
class MockAuthService {
  static const String _shellTokenKey = 'foundry_shell_token';
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  MockAuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Simulates system browser authentication flow
  /// Returns true if auth succeeds, false otherwise
  Future<bool> authenticateUser({
    required String username,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock validation (accept any non-empty credentials)
    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    // Generate shell token (simulating OAuth token exchange)
    final shellToken = _generateShellToken(username);

    // CRITICAL: Store shell token in secure storage ONLY
    await _secureStorage.write(key: _shellTokenKey, value: shellToken);

    return true;
  }

  /// Generates a mock shell token with user identity
  String _generateShellToken(String username) {
    final tokenData = {
      'sub': username,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'jti': _uuid.v4(),
      'type': 'shell_token',
      'scope': 'full_access', // Shell has full system access
    };

    // Create a mock JWT-like token
    final header = base64Url.encode(utf8.encode(json.encode({'alg': 'HS256', 'typ': 'JWT'})));
    final payload = base64Url.encode(utf8.encode(json.encode(tokenData)));
    final signature = _generateSignature('$header.$payload');

    return '$header.$payload.$signature';
  }

  /// Generate HMAC signature for mock token
  String _generateSignature(String data) {
    const secret = 'mock_shell_secret_key'; // In production, use secure key management
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(data));
    return base64Url.encode(digest.bytes);
  }

  /// Retrieves shell token from secure storage
  ///
  /// SECURITY: This method is INTERNAL only - never expose to bridge
  Future<String?> getShellToken() async {
    return await _secureStorage.read(key: _shellTokenKey);
  }

  /// Validates if shell token exists and is valid
  Future<bool> isAuthenticated() async {
    final token = await getShellToken();
    if (token == null) return false;

    // In production, validate token expiry, signature, etc.
    final parts = token.split('.');
    if (parts.length != 3) return false;

    try {
      final payload = json.decode(utf8.decode(base64Url.decode(parts[1])));
      return payload['type'] == 'shell_token';
    } catch (e) {
      return false;
    }
  }

  /// Clears authentication (logout)
  Future<void> logout() async {
    await _secureStorage.delete(key: _shellTokenKey);
  }

  /// Extract username from shell token
  Future<String?> getCurrentUsername() async {
    final token = await getShellToken();
    if (token == null) return null;

    try {
      final parts = token.split('.');
      final payload = json.decode(utf8.decode(base64Url.decode(parts[1])));
      return payload['sub'] as String?;
    } catch (e) {
      return null;
    }
  }
}
