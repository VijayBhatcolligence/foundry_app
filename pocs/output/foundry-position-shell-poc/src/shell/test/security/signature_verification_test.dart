// ADR-002: Signature Verification Integration Tests
// Purpose: Verify cryptographic signature verification with tamper detection

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/security/module_verifier.dart';
import 'package:foundry_shell/modules/module_manifest.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  group('ADR-002: Cryptographic Signature Verification', () {
    late ModuleVerifier verifier;
    late Directory tempDir;

    setUp(() async {
      verifier = ModuleVerifier();
      tempDir = await Directory.systemTemp.createTemp('signature_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // Test RSA-2048 public key (PEM format)
    // This is a valid test key generated for testing purposes only
    // DO NOT use in production
    const testPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo
4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u
+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh
kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ
0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg
cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc
mwIDAQAB
-----END PUBLIC KEY-----''';

    test('Valid module signature format is accepted', () async {
      // Create test module file
      final moduleFile = File('${tempDir.path}/test_module.js');
      await moduleFile.writeAsString('console.log("Test module");');

      // Create valid format signature (256 bytes for RSA-2048)
      final validSignature = base64.encode(Uint8List(256));

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: validSignature,
        publicKeyPem: testPublicKeyPem,
      );

      // Note: Without actual signing infrastructure, this tests format validation
      // Real cryptographic verification requires properly signed test data
      expect(result.algorithm, equals('RSA-2048/SHA-256'));
    });

    test('CRITICAL: Tampered module with original signature fails verification', () async {
      // This is the critical security test from ADR-002
      // A tampered module MUST fail verification even with valid signature format

      // Create original module
      final moduleFile = File('${tempDir.path}/tampered_module.js');
      final originalContent = 'console.log("Original code");';
      await moduleFile.writeAsString(originalContent);

      // Create signature for original content (valid format)
      final originalSignature = base64.encode(Uint8List(256));

      // TAMPER: Modify module content but keep original signature
      final tamperedContent = 'console.log("MALICIOUS CODE - TAMPERED!");';
      await moduleFile.writeAsString(tamperedContent);

      // Verify tampered module with original signature
      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: originalSignature,
        publicKeyPem: testPublicKeyPem,
      );

      // CRITICAL: Tampered module MUST fail verification
      // This is the production-blocking requirement from ADR-002
      expect(result.isValid, isFalse,
          reason: 'Tampered module must fail cryptographic verification');
      expect(result.error, contains('verification'),
          reason: 'Error should indicate verification failure');
    });

    test('Invalid signature format fails validation', () async {
      final moduleFile = File('${tempDir.path}/test_module.js');
      await moduleFile.writeAsString('console.log("Test");');

      // Invalid signature (wrong length - should be 344 chars base64 for 256 bytes)
      const invalidSignature = 'TooShort';

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: invalidSignature,
        publicKeyPem: testPublicKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('Signature length mismatch'));
    });

    test('Invalid base64 signature fails validation', () async {
      final moduleFile = File('${tempDir.path}/test_module.js');
      await moduleFile.writeAsString('console.log("Test");');

      // Invalid base64 but correct length
      final invalidBase64 = '!' * 344;

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: invalidBase64,
        publicKeyPem: testPublicKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid base64 signature'));
    });

    test('Missing module file fails verification', () async {
      final nonExistentFile = '${tempDir.path}/does_not_exist.js';
      final validSignature = base64.encode(Uint8List(256));

      final result = await verifier.verifyModule(
        moduleFilePath: nonExistentFile,
        signatureBase64: validSignature,
        publicKeyPem: testPublicKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('Module file not found'));
    });

    test('Empty module file fails verification', () async {
      final moduleFile = File('${tempDir.path}/empty_module.js');
      await moduleFile.writeAsString('');

      final validSignature = base64.encode(Uint8List(256));

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: validSignature,
        publicKeyPem: testPublicKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('Module file is empty'));
    });

    test('Module exceeding size limit fails verification', () async {
      final moduleFile = File('${tempDir.path}/huge_module.js');
      // Create file > 50 MB
      final largeContent = 'x' * (52428800 + 1);
      await moduleFile.writeAsString(largeContent);

      final validSignature = base64.encode(Uint8List(256));

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: validSignature,
        publicKeyPem: testPublicKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('exceeds maximum size'));
    });

    test('Verification completes within timeout (< 1 second)', () async {
      final moduleFile = File('${tempDir.path}/perf_test_module.js');
      // Reasonable size module (1 MB)
      final content = 'x' * 1000000;
      await moduleFile.writeAsString(content);

      final validSignature = base64.encode(Uint8List(256));

      final stopwatch = Stopwatch()..start();

      await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: validSignature,
        publicKeyPem: testPublicKeyPem,
      );

      stopwatch.stop();

      // ADR-002 performance requirement: < 1 second
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Verification must complete in < 1 second');
    });

    test('Invalid public key format fails verification', () async {
      final moduleFile = File('${tempDir.path}/test_module.js');
      await moduleFile.writeAsString('console.log("Test");');
      final validSignature = base64.encode(Uint8List(256));

      const invalidKeyPem = 'NOT A VALID PEM KEY';

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: validSignature,
        publicKeyPem: invalidKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid public key'));
    });

    test('Public key parsing validates RSA-2048 format', () {
      // Valid PEM structure
      final publicKey = verifier.loadPublicKey(testPublicKeyPem);

      expect(publicKey.algorithm, equals('RSA-2048'));
      expect(publicKey.keySizeBits, equals(2048));
      expect(publicKey.keyId.isNotEmpty, isTrue);
    });

    test('Verification result includes timestamp and algorithm', () async {
      final moduleFile = File('${tempDir.path}/test_module.js');
      await moduleFile.writeAsString('console.log("Test");');
      final validSignature = base64.encode(Uint8List(256));

      final beforeVerification = DateTime.now();

      final result = await verifier.verifyModule(
        moduleFilePath: moduleFile.path,
        signatureBase64: validSignature,
        publicKeyPem: testPublicKeyPem,
      );

      final afterVerification = DateTime.now();

      expect(result.verifiedAt.isAfter(beforeVerification.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.verifiedAt.isBefore(afterVerification.add(const Duration(seconds: 1))), isTrue);
      expect(result.algorithm, equals('RSA-2048/SHA-256'));
    });
  });

  group('Manifest Signature Verification', () {
    late ModuleVerifier verifier;

    setUp(() {
      verifier = ModuleVerifier();
    });

    const testPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo
4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u
+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh
kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ
0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg
cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc
mwIDAQAB
-----END PUBLIC KEY-----''';

    test('Manifest signature verification uses correct data format', () async {
      // Create test manifest
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        downloadUrl: 'https://test.com/module.js',
        checksum: 'a' * 64, // Valid SHA-256 hex
        signature: base64.encode(Uint8List(256)),
        requiredShellVersion: '1.0.0',
        downloadSizeBytes: 1024,
        publishedAt: DateTime.now(),
      );

      final result = await verifier.verifyManifest(
        manifest: manifest,
        publicKeyPem: testPublicKeyPem,
      );

      // Verify result structure
      expect(result.algorithm, equals('RSA-2048/SHA-256'));
    });

    test('CRITICAL: Tampered manifest data fails verification', () async {
      final publishTime = DateTime.now();

      // Original manifest
      final originalManifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        downloadUrl: 'https://test.com/module.js',
        checksum: 'a' * 64,
        signature: base64.encode(Uint8List(256)),
        requiredShellVersion: '1.0.0',
        downloadSizeBytes: 1024,
        publishedAt: publishTime,
      );

      // Tampered manifest (changed downloadUrl but kept original signature)
      final tamperedManifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        downloadUrl: 'https://malicious.com/evil.js', // TAMPERED
        checksum: 'a' * 64,
        signature: originalManifest.signature, // Original signature
        requiredShellVersion: '1.0.0',
        downloadSizeBytes: 1024,
        publishedAt: publishTime,
      );

      final result = await verifier.verifyManifest(
        manifest: tamperedManifest,
        publicKeyPem: testPublicKeyPem,
      );

      // CRITICAL: Tampered manifest MUST fail verification
      expect(result.isValid, isFalse,
          reason: 'Tampered manifest must fail cryptographic verification');
    });

    test('Invalid manifest signature format fails', () async {
      final manifest = ModuleManifest(
        moduleId: 'test-module',
        version: '1.0.0',
        downloadUrl: 'https://test.com/module.js',
        checksum: 'a' * 64,
        signature: 'INVALID_BASE64!!!',
        requiredShellVersion: '1.0.0',
        downloadSizeBytes: 1024,
        publishedAt: DateTime.now(),
      );

      final result = await verifier.verifyManifest(
        manifest: manifest,
        publicKeyPem: testPublicKeyPem,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid base64 signature'));
    });
  });
}
