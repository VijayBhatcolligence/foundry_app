// D3.2: Signing Keys Storage
// Purpose: Store and manage trusted public keys

import 'dart:convert';
import 'package:crypto/crypto.dart';

class SigningKeys {
  // Primary trusted public key for module signing (RSA-2048)
  // This is a placeholder key for demonstration - in production, use actual signing key
  static const String primaryPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy8Dbv8prpJ/0kKhlGeJY
ozo2t60EG8EcYVYCY6ykP+0ClZHbdPoZs5C7KJqCx0dKj3mPPMHF+F5z3wBQvJLy
8N5v3Q1WJOYXl3KcAC6yAQMkDOFt3rM8+qpSgLPNnP8XlI1B3T5qFdW8PZNqF/A5
zMt7dqYsKlZ+DH0lHQS9p3bJB3XGmPOvBwXvFB/RKcqKBxPKZcLQ9eoLl0bfD1Xl
zQqLjx3rJmYqbhN+hMQEKFm4b9hSYWGIp4MrHEQCJx9iCYxFCgTr0l0zH7bEGKCj
9qx3tH4bIqTmH3MfJWPZJqLXBVdLq2M5dYXNLKfCqZLZqGQAEPPLwEwXBOCHqQlY
FQIDAQAB
-----END PUBLIC KEY-----
''';

  // Key rotation: Secondary key for transition period
  static const String? secondaryPublicKeyPem = null;

  // Get list of all trusted public keys
  static List<String> get trustedKeys => [
        primaryPublicKeyPem,
        if (secondaryPublicKeyPem != null) secondaryPublicKeyPem!,
      ];

  // Validate key format and size
  static bool isValidKey(String keyPem) {
    try {
      // Check for PEM headers and footers
      if (!keyPem.contains('-----BEGIN PUBLIC KEY-----')) {
        return false;
      }
      if (!keyPem.contains('-----END PUBLIC KEY-----')) {
        return false;
      }

      // Check it's not a private key (must be public key only)
      if (keyPem.contains('PRIVATE KEY')) {
        return false;
      }

      // Extract base64 content between headers
      final pemLines = keyPem.split('\n');
      final base64Content = pemLines
          .where((line) =>
              !line.contains('-----BEGIN') &&
              !line.contains('-----END') &&
              line.trim().isNotEmpty)
          .join('');

      // Validate base64 content
      if (base64Content.isEmpty) {
        return false;
      }

      // Try to decode base64 to verify it's valid
      try {
        base64.decode(base64Content);
      } catch (e) {
        return false;
      }

      // Basic length check for RSA-2048 key
      // RSA-2048 public key in DER format is typically ~290-300 bytes
      final decodedBytes = base64.decode(base64Content);
      if (decodedBytes.length < 250 || decodedBytes.length > 400) {
        // Allow some flexibility but reject obviously wrong sizes
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get key identifier (first 16 chars of SHA-256 hash)
  static String getKeyId(String keyPem) {
    if (!isValidKey(keyPem)) {
      throw FormatException('Invalid PEM format');
    }

    final bytes = utf8.encode(keyPem);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }
}
