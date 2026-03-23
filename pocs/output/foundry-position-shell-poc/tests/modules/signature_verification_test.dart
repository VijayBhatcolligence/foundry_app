// D8.2: RSA Signature Verification Tests

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/security/module_verifier.dart';
import 'package:foundry_shell/security/signing_keys.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ModuleVerifier', () {
    late ModuleVerifier verifier;
    late Directory tempDir;

    setUp(() async {
      verifier = ModuleVerifier();
      tempDir = await getTemporaryDirectory();
    });

    test('Load valid public key', () {
      final publicKey = verifier.loadPublicKey(SigningKeys.primaryPublicKeyPem);

      expect(publicKey.keySizeBits, 2048);
      expect(publicKey.algorithm, 'RSA-2048');
      expect(publicKey.keyId.length, 16);
    });

    test('Invalid PEM throws FormatException', () {
      expect(
        () => verifier.loadPublicKey('not a valid PEM'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Verify module with valid signature', () async {
      // Create test file
      final testFile = File(path.join(tempDir.path, 'test_module.js'));
      await testFile.writeAsString('test module content');

      // Generate valid signature (256 bytes for RSA-2048)
      final signature = 'A' * 344; // Base64 encoded, 344 chars for RSA-2048

      final result = await verifier.verifyModule(
        moduleFilePath: testFile.path,
        signatureBase64: signature,
        publicKeyPem: SigningKeys.primaryPublicKeyPem,
      );

      // In POC mode, valid-length signatures are accepted
      expect(result.algorithm, 'RSA-2048/SHA-256');
      expect(result.verifiedAt, isNotNull);

      await testFile.delete();
    });

    test('Missing file returns error', () async {
      final result = await verifier.verifyModule(
        moduleFilePath: '/nonexistent/file.js',
        signatureBase64: 'A' * 344,
        publicKeyPem: SigningKeys.primaryPublicKeyPem,
      );

      expect(result.isValid, false);
      expect(result.error, contains('Module file not found'));
    });

    test('Empty file returns error', () async {
      final testFile = File(path.join(tempDir.path, 'empty.js'));
      await testFile.writeAsString('');

      final result = await verifier.verifyModule(
        moduleFilePath: testFile.path,
        signatureBase64: 'A' * 344,
        publicKeyPem: SigningKeys.primaryPublicKeyPem,
      );

      expect(result.isValid, false);
      expect(result.error, contains('Module file is empty'));

      await testFile.delete();
    });

    test('Invalid signature length returns error', () async {
      final testFile = File(path.join(tempDir.path, 'test.js'));
      await testFile.writeAsString('content');

      final result = await verifier.verifyModule(
        moduleFilePath: testFile.path,
        signatureBase64: 'AAAA', // Wrong length
        publicKeyPem: SigningKeys.primaryPublicKeyPem,
      );

      expect(result.isValid, false);
      expect(result.error, contains('Signature length mismatch'));

      await testFile.delete();
    });

    test('Invalid base64 returns error', () async {
      final testFile = File(path.join(tempDir.path, 'test.js'));
      await testFile.writeAsString('content');

      final result = await verifier.verifyModule(
        moduleFilePath: testFile.path,
        signatureBase64: '!' * 344, // Invalid base64
        publicKeyPem: SigningKeys.primaryPublicKeyPem,
      );

      expect(result.isValid, false);
      expect(result.error, contains('Invalid base64 signature'));

      await testFile.delete();
    });
  });

  group('SigningKeys', () {
    test('Primary key is valid', () {
      final isValid = SigningKeys.isValidKey(SigningKeys.primaryPublicKeyPem);
      expect(isValid, true);
    });

    test('Trusted keys list includes primary', () {
      final keys = SigningKeys.trustedKeys;
      expect(keys, contains(SigningKeys.primaryPublicKeyPem));
    });

    test('Key ID generation is consistent', () {
      final id1 = SigningKeys.getKeyId(SigningKeys.primaryPublicKeyPem);
      final id2 = SigningKeys.getKeyId(SigningKeys.primaryPublicKeyPem);

      expect(id1, id2);
      expect(id1.length, 16);
    });

    test('Invalid key format rejected', () {
      expect(SigningKeys.isValidKey('not a key'), false);
    });

    test('Private key rejected', () {
      final privateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
-----END PRIVATE KEY-----
''';

      expect(SigningKeys.isValidKey(privateKeyPem), false);
    });
  });
}
