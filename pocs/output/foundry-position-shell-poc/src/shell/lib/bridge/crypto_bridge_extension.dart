// ADR-002: Native Platform Crypto Bridge Extension
// Purpose: Provide cryptographic signature verification using native platform APIs

import 'package:flutter/services.dart';
import 'dart:typed_data';

class CryptoBridgeExtension {
  static const MethodChannel _channel = MethodChannel('com.foundry.shell/crypto');

  /// Verify RSA-2048 PKCS1-v1_5 signature using native platform crypto
  ///
  /// This method uses platform-native cryptographic APIs:
  /// - Android: java.security.Signature with SHA256withRSA
  /// - iOS: Security framework with SecKeyVerifySignature
  ///
  /// Parameters:
  /// - [publicKeyPem]: PEM-encoded RSA-2048 public key
  /// - [message]: Original message bytes (module file content)
  /// - [signature]: RSA signature bytes (256 bytes for RSA-2048)
  ///
  /// Returns:
  /// - true if signature is valid
  /// - false if signature is invalid or verification fails
  static Future<bool> verifyRSASignature({
    required String publicKeyPem,
    required Uint8List message,
    required Uint8List signature,
  }) async {
    try {
      final result = await _channel.invokeMethod('verifyRSASignature', {
        'publicKeyPem': publicKeyPem,
        'message': message,
        'signature': signature,
        'algorithm': 'SHA256withRSA',
      });
      return result as bool;
    } on PlatformException catch (e) {
      print('[CryptoBridge] Platform error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('[CryptoBridge] Verification failed: $e');
      return false;
    }
  }

  /// Test method to verify bridge connectivity
  /// Returns true if platform bridge is available
  static Future<bool> testBridgeConnection() async {
    try {
      final result = await _channel.invokeMethod('ping');
      return result == 'pong';
    } catch (e) {
      print('[CryptoBridge] Bridge connection test failed: $e');
      return false;
    }
  }
}
