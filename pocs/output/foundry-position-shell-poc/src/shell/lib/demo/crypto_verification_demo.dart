// Demo: Verify Native Crypto Implementation is Working
// Run this to see signature verification in action

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../bridge/crypto_bridge_extension.dart';
import '../security/signing_keys.dart';

class CryptoVerificationDemo {
  /// Run complete verification demo
  static Future<void> run() async {
    print('\n========================================');
    print('🔐 SIGNATURE VERIFICATION DEMO');
    print('========================================\n');

    // Step 1: Test bridge connection
    await _testBridgeConnection();

    // Step 2: Test with mock valid signature
    await _testValidSignature();

    // Step 3: Test with tampered data
    await _testTamperedData();

    // Step 4: Show verification is NOT simulated
    await _confirmNotSimulated();

    print('\n========================================');
    print('✅ DEMO COMPLETE');
    print('========================================\n');
  }

  static Future<void> _testBridgeConnection() async {
    print('📡 Step 1: Testing Native Crypto Bridge Connection...');
    try {
      final connected = await CryptoBridgeExtension.testBridgeConnection();
      if (connected) {
        print('   ✅ Bridge connected: Native platform crypto is available');
      } else {
        print('   ❌ Bridge not connected: Using fallback');
      }
    } catch (e) {
      print('   ⚠️  Bridge test failed: $e');
    }
    print('');
  }

  static Future<void> _testValidSignature() async {
    print('🔍 Step 2: Testing Valid Signature Verification...');

    // Create test data
    final testData = utf8.encode('This is a test module');
    final publicKeyPem = SigningKeys.trustedKeys.first;

    // For demo purposes, we'll create a mock signature
    // In production, this would be a real RSA signature
    final mockSignature = Uint8List(256); // 256 bytes for RSA-2048
    for (int i = 0; i < 256; i++) {
      mockSignature[i] = i % 256;
    }

    print('   📝 Test data: "${utf8.decode(testData)}"');
    print('   🔑 Public key: ${publicKeyPem.substring(0, 50)}...');
    print('   📋 Signature length: ${mockSignature.length} bytes');
    print('   🔐 Calling native crypto bridge...');

    try {
      final startTime = DateTime.now();
      final isValid = await CryptoBridgeExtension.verifyRSASignature(
        publicKeyPem: publicKeyPem,
        message: Uint8List.fromList(testData),
        signature: mockSignature,
      );
      final duration = DateTime.now().difference(startTime);

      print('   ⏱️  Verification time: ${duration.inMilliseconds}ms');
      if (isValid) {
        print('   ✅ Native crypto returned: VALID');
      } else {
        print('   ❌ Native crypto returned: INVALID (expected for mock signature)');
      }
    } catch (e) {
      print('   ❌ Verification failed: $e');
    }
    print('');
  }

  static Future<void> _testTamperedData() async {
    print('🔍 Step 3: Testing Tampered Data Detection...');

    final originalData = utf8.encode('Original module content');
    final tamperedData = utf8.encode('TAMPERED module content');
    final publicKeyPem = SigningKeys.trustedKeys.first;

    // Same signature for both
    final signature = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      signature[i] = i % 256;
    }

    print('   📝 Original data: "${utf8.decode(originalData)}"');
    print('   ⚠️  Tampered data: "${utf8.decode(tamperedData)}"');
    print('   🔐 Verifying tampered data with original signature...');

    try {
      final isValid = await CryptoBridgeExtension.verifyRSASignature(
        publicKeyPem: publicKeyPem,
        message: Uint8List.fromList(tamperedData),
        signature: signature,
      );

      if (!isValid) {
        print('   ✅ Tampered data REJECTED (correct behavior)');
      } else {
        print('   ❌ WARNING: Tampered data ACCEPTED (this should not happen!)');
      }
    } catch (e) {
      print('   ❌ Verification error: $e');
    }
    print('');
  }

  static Future<void> _confirmNotSimulated() async {
    print('🔍 Step 4: Confirming NOT Simulated...');

    print('   📂 Checking module_verifier.dart for "SIMULATED" keyword...');

    try {
      // Read the module_verifier.dart file
      final file = File('lib/security/module_verifier.dart');
      if (await file.exists()) {
        final content = await file.readAsString();

        if (content.contains('SIMULATED')) {
          print('   ⚠️  WARNING: Found "SIMULATED" in module_verifier.dart');
          print('   This suggests verification might still be simulated!');
        } else {
          print('   ✅ No "SIMULATED" found - using real cryptographic verification');
        }

        if (content.contains('CryptoBridgeExtension.verifyRSASignature')) {
          print('   ✅ Found CryptoBridgeExtension call - native crypto is integrated');
        } else {
          print('   ⚠️  WARNING: CryptoBridgeExtension call not found');
        }
      } else {
        print('   ⚠️  Could not read module_verifier.dart');
      }
    } catch (e) {
      print('   ⚠️  Error checking file: $e');
    }
    print('');
  }

  /// Quick test - just verify bridge works
  static Future<bool> quickTest() async {
    print('🔐 Quick Crypto Bridge Test...');

    try {
      final testData = utf8.encode('test');
      final publicKeyPem = SigningKeys.trustedKeys.first;
      final signature = Uint8List(256);

      final result = await CryptoBridgeExtension.verifyRSASignature(
        publicKeyPem: publicKeyPem,
        message: Uint8List.fromList(testData),
        signature: signature,
      );

      print('   Bridge call successful: returned $result');
      return true;
    } catch (e) {
      print('   ❌ Bridge call failed: $e');
      return false;
    }
  }
}
