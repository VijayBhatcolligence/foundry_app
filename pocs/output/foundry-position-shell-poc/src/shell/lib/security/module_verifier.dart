// D3.1: Module Signature Verifier
// Purpose: Verify RSA-2048 signatures on module files
// ADR-002: Using native platform crypto APIs for production-grade verification

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';
import 'package:crypto/crypto.dart';
import '../modules/module_manifest.dart';
import '../bridge/crypto_bridge_extension.dart';

class ModuleVerifier {
  // Verify module file signature using trusted public key
  Future<VerificationResult> verifyModule({
    required String moduleFilePath,
    required String signatureBase64,
    required String publicKeyPem,
  }) async {
    try {
      // Check if file exists
      final file = File(moduleFilePath);
      if (!await file.exists()) {
        return VerificationResult(
          isValid: false,
          error: 'Module file not found',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Check if file is empty
      final fileSize = await file.length();
      if (fileSize == 0) {
        return VerificationResult(
          isValid: false,
          error: 'Module file is empty',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Check file size limit (50 MB)
      if (fileSize > 52428800) {
        return VerificationResult(
          isValid: false,
          error: 'Module file exceeds maximum size',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Validate signature format
      if (signatureBase64.length != 344) {
        return VerificationResult(
          isValid: false,
          error: 'Signature length mismatch',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Decode signature
      Uint8List signature;
      try {
        signature = base64.decode(signatureBase64);
      } catch (e) {
        return VerificationResult(
          isValid: false,
          error: 'Invalid base64 signature',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Load public key
      final PublicKey publicKey;
      try {
        publicKey = loadPublicKey(publicKeyPem);
      } catch (e) {
        return VerificationResult(
          isValid: false,
          error: 'Invalid public key: $e',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Read file bytes for verification
      final fileBytes = await file.readAsBytes();

      // Verify signature with timeout (native crypto computes hash internally)
      final isValid = await Future.any([
        Future.delayed(const Duration(seconds: 5), () => false),
        _verifySignature(fileBytes, signature, publicKey),
      ]);

      if (!isValid) {
        return VerificationResult(
          isValid: false,
          error: 'Signature verification failed',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      return VerificationResult(
        isValid: true,
        verifiedAt: DateTime.now(),
        algorithm: 'RSA-2048/SHA-256',
      );
    } on TimeoutException {
      return VerificationResult(
        isValid: false,
        error: 'Verification timeout after 5 seconds',
        verifiedAt: DateTime.now(),
        algorithm: 'RSA-2048/SHA-256',
      );
    } on FileSystemException catch (e) {
      return VerificationResult(
        isValid: false,
        error: 'File error: $e',
        verifiedAt: DateTime.now(),
        algorithm: 'RSA-2048/SHA-256',
      );
    } catch (e) {
      return VerificationResult(
        isValid: false,
        error: 'Cryptographic error: $e',
        verifiedAt: DateTime.now(),
        algorithm: 'RSA-2048/SHA-256',
      );
    }
  }

  // Verify manifest signature
  Future<VerificationResult> verifyManifest({
    required ModuleManifest manifest,
    required String publicKeyPem,
  }) async {
    try {
      // Construct data to verify: moduleId|version|downloadUrl|checksum
      final dataToVerify = '${manifest.moduleId}|${manifest.version}|${manifest.downloadUrl}|${manifest.checksum}';
      final dataBytes = utf8.encode(dataToVerify);

      // Decode signature
      Uint8List signature;
      try {
        signature = base64.decode(manifest.signature);
      } catch (e) {
        return VerificationResult(
          isValid: false,
          error: 'Invalid base64 signature',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Load public key
      final PublicKey publicKey;
      try {
        publicKey = loadPublicKey(publicKeyPem);
      } catch (e) {
        return VerificationResult(
          isValid: false,
          error: 'Invalid public key: $e',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      // Verify signature using native platform crypto (computes hash internally)
      final isValid = await _verifySignature(dataBytes, signature, publicKey);

      if (!isValid) {
        return VerificationResult(
          isValid: false,
          error: 'Signature verification failed',
          verifiedAt: DateTime.now(),
          algorithm: 'RSA-2048/SHA-256',
        );
      }

      return VerificationResult(
        isValid: true,
        verifiedAt: DateTime.now(),
        algorithm: 'RSA-2048/SHA-256',
      );
    } catch (e) {
      return VerificationResult(
        isValid: false,
        error: 'Cryptographic error: $e',
        verifiedAt: DateTime.now(),
        algorithm: 'RSA-2048/SHA-256',
      );
    }
  }

  // Load trusted public key and validate format
  PublicKey loadPublicKey(String publicKeyPem) {
    try {
      // Extract base64 content between PEM headers
      final lines = publicKeyPem.split('\n');
      final base64Content = lines
          .where((line) =>
              !line.contains('-----BEGIN') &&
              !line.contains('-----END') &&
              line.trim().isNotEmpty)
          .join('');

      // Decode base64
      final keyBytes = base64.decode(base64Content);

      // Parse RSA public key using PointyCastle
      final parser = ASN1Parser(keyBytes);
      final topLevelSeq = parser.nextObject() as ASN1Sequence;

      // Basic validation - should be a sequence
      if (topLevelSeq.elements == null || topLevelSeq.elements!.length < 2) {
        throw const FormatException('Invalid PEM format');
      }

      // For RSA-2048, the modulus should be 256 bytes
      // This is a simplified check - full validation would parse the ASN.1 structure
      if (keyBytes.length < 250 || keyBytes.length > 400) {
        throw const FormatException('Key must be RSA-2048');
      }

      // Generate key ID
      final keyId = sha256.convert(utf8.encode(publicKeyPem)).toString().substring(0, 16);

      return PublicKey(
        keyId: keyId,
        pem: publicKeyPem,
        keySizeBits: 2048,
        algorithm: 'RSA-2048',
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Invalid PEM format: $e');
    }
  }

  // Private helper: Verify RSA signature using native platform crypto
  // ADR-002 Option B: Native platform crypto via bridge
  // Native crypto APIs compute SHA-256 hash internally
  Future<bool> _verifySignature(List<int> messageBytes, Uint8List signature, PublicKey publicKey) async {
    try {
      // Validate signature length (RSA-2048 produces 256-byte signatures)
      if (signature.length != 256) {
        return false;
      }

      // Use native platform crypto for verification
      // This calls Android java.security.Signature (SHA256withRSA)
      // or iOS SecKeyVerifySignature (.rsaSignatureMessagePKCS1v15SHA256)
      // Both compute SHA-256 hash internally before verifying
      final isValid = await CryptoBridgeExtension.verifyRSASignature(
        publicKeyPem: publicKey.pem,
        message: Uint8List.fromList(messageBytes),
        signature: signature,
      );

      return isValid;
    } catch (e) {
      print('[ModuleVerifier] Crypto bridge error: $e');
      return false;
    }
  }
}

class VerificationResult {
  final bool isValid;
  final String? error;
  final DateTime verifiedAt;
  final String algorithm;

  VerificationResult({
    required this.isValid,
    this.error,
    required this.verifiedAt,
    required this.algorithm,
  });
}

class PublicKey {
  final String keyId;
  final String pem;
  final int keySizeBits;
  final String algorithm;

  PublicKey({
    required this.keyId,
    required this.pem,
    required this.keySizeBits,
    required this.algorithm,
  });
}
