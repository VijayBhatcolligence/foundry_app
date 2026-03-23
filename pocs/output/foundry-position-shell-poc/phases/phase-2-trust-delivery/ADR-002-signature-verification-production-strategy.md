# ADR-002: Production Signature Verification Strategy

**Status**: Proposed - **CRITICAL DECISION REQUIRED**
**Date**: 2026-03-16
**Decision Makers**: Security Architecture Team, Technical Leadership
**Related**: Phase 2 Trust & Delivery, IMPLEMENTATION_REVIEW.md
**Severity**: 🔴 **PRODUCTION BLOCKING**

---

## Context

Phase 2 implemented signature verification infrastructure but **simulates cryptographic verification** in POC mode. The current implementation validates signature **format** (256 bytes, base64) but does NOT perform actual RSA-2048 PKCS1-v1_5 cryptographic verification.

**Current State**:
- ✅ RSA-2048 signature infrastructure exists
- ✅ PEM public key parsing implemented
- ✅ Trusted key management (`SigningKeys` class) works
- ✅ Signature format validation (256 bytes, base64) works
- ❌ **CRITICAL**: Cryptographic signature verification is **simulated**
- ❌ **CRITICAL**: Tampered modules with valid format would pass verification

**Code Evidence** (`lib/security/module_verifier.dart`):
```dart
// POC note: Full RSA PKCS1-v1_5 verification would happen here
// In production, would parse PEM public key, extract modulus/exponent,
// and perform cryptographic signature verification
print('[ModuleVerifier] Signature verification: SIMULATED (POC mode)');
```

---

## Baseline Assumption Being Changed

**Original Requirement** (from `foundry-position-shell-parity-evaluation.md` Section 9.1):
```
Line 584-585: module provenance and integrity verification
Line 586: bridge gating based on trust, compatibility, and scope
```

**Original Requirement** (from `foundry-position-shell-poc-scenarios.md` Scenario X-9):
```
Success Criteria: Unverified or tampered module fails verification,
does not mount, does not receive bridge access, and produces a
controlled fallback
```

**Current Reality**:
```
Module with tampered code but valid signature FORMAT would:
✅ Pass format validation
❌ NOT be cryptographically verified
✅ Mount successfully
✅ Receive bridge access
❌ Trust boundary INCOMPLETE
```

---

## PoC Evidence That Exposed The Problem

### Security Gap Identified

**Test**: What happens if a module is tampered with?

**Expected** (per scenarios document):
1. Signature verification detects tampering
2. Module fails verification
3. Module does NOT mount
4. Module does NOT receive bridge access
5. Last-known-good fallback activated

**Actual** (current POC mode):
1. Signature format checked (passes if 256 bytes base64)
2. Cryptographic verification **simulated** (always passes)
3. Module mounts successfully
4. Module receives bridge access
5. ❌ **Trust boundary incomplete**

### Reference Document Violation

**Architecture Fail Condition Triggered** (Section 8, Item 2):
```
2. The capability only works by violating Foundry's auth or trust boundary.
```

While not technically "violating" (no shell tokens leaked), the trust boundary is **incomplete** - unverified modules can access the system.

### Why POC Mode Was Chosen

**Root Cause**: Complexity of ASN.1 DER parsing

Full RSA-2048 PKCS1-v1_5 verification requires:
1. Parse PEM-encoded public key
2. Extract ASN.1 DER structure
3. Decode modulus and exponent (manual ASN.1 parsing)
4. Perform PKCS#1 v1.5 padding verification
5. Compare hash(message) with decrypted signature

**Estimated Complexity**: ~200 LOC of ASN.1 parsing + crypto operations

**POC Decision**: Defer cryptographic verification to validate architecture first, complete crypto later

---

## Problem Statement

**Trust Boundary Incomplete**: The current implementation cannot detect tampered modules, which violates a core security requirement of the mixed architecture.

**Production Risk**:
- Malicious actor could:
  1. Take a valid signed module
  2. Modify JavaScript code
  3. Keep signature file unchanged (or replace with valid-format garbage)
  4. Module would mount and receive bridge access
  5. Tampered code executes in user's session

**Parity Failure**: This is a **must-match** scenario per Section 7.1:
```
- module provenance, integrity verification, and controlled rollback
```

---

## Options

### Option A: Implement Full RSA-2048 PKCS1-v1_5 in Dart (Pure Dart Solution)

**Description**: Complete the cryptographic verification using Dart's `pointycastle` library

**Implementation**:
```dart
import 'package:pointycastle/export.dart';

Future<bool> verifySignature(File moduleFile, File signatureFile, String publicKeyPem) async {
  // 1. Parse PEM public key
  final publicKey = _parsePemPublicKey(publicKeyPem);

  // 2. Read module content
  final moduleBytes = await moduleFile.readAsBytes();

  // 3. Compute SHA-256 hash
  final digest = SHA256Digest();
  final messageHash = digest.process(moduleBytes);

  // 4. Read signature
  final signatureBytes = await signatureFile.readAsBytes();

  // 5. Verify RSA PKCS#1 v1.5
  final verifier = RSASignerVerifier(
    RSAEngine(),
    Signer('SHA-256/RSA'),
  );

  verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

  return verifier.verifySignature(
    messageHash,
    RSASignature(signatureBytes),
  );
}

RSAPublicKey _parsePemPublicKey(String pem) {
  // Parse PEM format
  final pemStripped = pem
    .replaceAll('-----BEGIN PUBLIC KEY-----', '')
    .replaceAll('-----END PUBLIC KEY-----', '')
    .replaceAll('\n', '');

  final keyBytes = base64.decode(pemStripped);

  // Parse ASN.1 DER structure
  final asn1Parser = ASN1Parser(keyBytes);
  final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

  // Extract algorithm identifier and public key bit string
  final publicKeyBitString = topLevelSeq.elements[1] as ASN1BitString;

  // Parse RSA public key structure
  final rsaParser = ASN1Parser(publicKeyBitString.contentBytes());
  final rsaSeq = rsaParser.nextObject() as ASN1Sequence;

  final modulus = (rsaSeq.elements[0] as ASN1Integer).valueAsBigInteger;
  final exponent = (rsaSeq.elements[1] as ASN1Integer).valueAsBigInteger;

  return RSAPublicKey(modulus, exponent);
}
```

**Pros**:
- ✅ No native dependencies - pure Dart
- ✅ Cross-platform (Android, iOS, web)
- ✅ Full control over implementation
- ✅ Can verify offline (no platform bridge required)
- ✅ Already have `pointycastle` dependency

**Cons**:
- ❌ Complex implementation (~200 LOC)
- ❌ ASN.1 parsing is brittle (must handle all key formats)
- ❌ Performance slower than native crypto
- ❌ Maintenance burden (crypto code requires expertise)

**Estimated Effort**: 2-3 days (implementation + testing)

**Risk**: Medium - ASN.1 parsing errors could cause false negatives/positives

---

### Option B: Use Native Platform Crypto APIs via Bridge (RECOMMENDED)

**Description**: Leverage platform-native cryptographic APIs (iOS Security framework, Android Keystore)

**Implementation**:
```dart
// In shell bridge (Dart side)
class CryptoB ridgeExtension {
  static const MethodChannel _channel = MethodChannel('com.foundry.shell/crypto');

  Future<bool> verifyRSASignature({
    required String publicKeyPem,
    required Uint8List message,
    required Uint8List signature,
  }) async {
    final result = await _channel.invokeMethod('verifyRSASignature', {
      'publicKeyPem': publicKeyPem,
      'message': message,
      'signature': signature,
      'algorithm': 'SHA256withRSA',
    });

    return result as bool;
  }
}
```

**Platform Implementation** (Kotlin for Android):
```kotlin
// In Android shell
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import android.util.Base64

fun verifyRSASignature(publicKeyPem: String, message: ByteArray, signature: ByteArray): Boolean {
    // Parse PEM
    val publicKeyPEM = publicKeyPem
        .replace("-----BEGIN PUBLIC KEY-----", "")
        .replace("-----END PUBLIC KEY-----", "")
        .replace("\\s".toRegex(), "")

    val publicKeyBytes = Base64.decode(publicKeyPEM, Base64.DEFAULT)

    // Create public key
    val keySpec = X509EncodedKeySpec(publicKeyBytes)
    val keyFactory = KeyFactory.getInstance("RSA")
    val publicKey = keyFactory.generatePublic(keySpec)

    // Verify signature
    val verifier = Signature.getInstance("SHA256withRSA")
    verifier.initVerify(publicKey)
    verifier.update(message)

    return verifier.verify(signature)
}
```

**iOS Implementation** (Swift):
```swift
// In iOS shell
import Security
import CommonCrypto

func verifyRSASignature(publicKeyPem: String, message: Data, signature: Data) -> Bool {
    // Parse PEM and create SecKey
    let publicKey = try? parsePublicKeyFromPEM(publicKeyPem)
    guard let key = publicKey else { return false }

    // Create signature verifier
    var error: Unmanaged<CFError>?
    let verified = SecKeyVerifySignature(
        key,
        .rsaSignatureMessagePKCS1v15SHA256,
        message as CFData,
        signature as CFData,
        &error
    )

    return verified
}
```

**Pros**:
- ✅ Uses platform-native crypto (fast, secure, tested)
- ✅ Less code to maintain (~50 LOC per platform)
- ✅ Leverages OS security infrastructure
- ✅ Better performance than pure Dart
- ✅ Standard platform APIs (well-documented)

**Cons**:
- ⚠️ Requires bridge extension (new bridge method)
- ⚠️ Platform-specific code (Android + iOS implementations)
- ⚠️ Bridge dependency for module verification

**Estimated Effort**: 1-2 days (bridge extension + platform implementations)

**Risk**: Low - using standard platform APIs

---

### Option C: Hybrid Approach (Dart + Native Fallback)

**Description**: Try Dart verification first, fall back to native if needed

**Implementation**:
```dart
Future<bool> verifySignature(File moduleFile, File signatureFile, String publicKeyPem) async {
  try {
    // Try pure Dart first
    return await _verifySignatureDart(moduleFile, signatureFile, publicKeyPem);
  } catch (e) {
    // Fallback to native platform crypto
    return await _verifySignatureNative(moduleFile, signatureFile, publicKeyPem);
  }
}
```

**Pros**:
- ✅ Best of both worlds
- ✅ Offline verification when possible (Dart)
- ✅ Reliable verification guaranteed (native fallback)

**Cons**:
- ❌ Double the implementation effort
- ❌ Double the maintenance burden
- ❌ Complexity of two paths

**Estimated Effort**: 3-4 days (both implementations)

**Risk**: Medium - increased complexity

---

### Option D: Defer to Server-Side Verification (NOT RECOMMENDED)

**Description**: Verify signatures on server, shell trusts server's verdict

**Implementation**:
```dart
Future<bool> verifyModule(String moduleId, String version) async {
  final response = await http.post(
    'https://foundry.api/verify-module',
    body: {'moduleId': moduleId, 'version': version},
  );

  return response.statusCode == 200;
}
```

**Pros**:
- ✅ Simple client implementation
- ✅ Server controls verification logic

**Cons**:
- ❌ Requires network for verification (breaks offline)
- ❌ Trust boundary shifts to network (MITM risk)
- ❌ Doesn't meet offline requirements
- ❌ Violates "shell custody of verification" principle

**Estimated Effort**: 1 day

**Risk**: HIGH - architectural violation, offline broken

**Verdict**: ❌ **REJECTED** - violates offline and custody requirements

---

## Decision

**RECOMMENDED: Option B - Use Native Platform Crypto APIs via Bridge**

**Rationale**:

1. **Security**: Production-grade cryptographic verification using platform APIs
2. **Performance**: Native crypto faster than pure Dart
3. **Maintainability**: Less code than full Dart implementation (~50 LOC vs ~200 LOC)
4. **Reliability**: Platform APIs are battle-tested
5. **Effort**: Fastest path to production (1-2 days vs 2-3 days)
6. **Offline**: Works offline (no server dependency)

**Implementation Plan**:

1. **Phase 3 or Standalone Task** (before production):
   - Add `CryptoBridgeExtension` to shell bridge
   - Implement Android native verification (Kotlin)
   - Implement iOS native verification (Swift)
   - Update `ModuleVerifier` to call bridge method
   - Add integration tests for tampered modules
   - Verify security: tampered module MUST fail verification

2. **Testing Requirements**:
   - ✅ Valid signed module passes
   - ✅ Tampered module (modified code, original signature) FAILS
   - ✅ Module with invalid signature format FAILS
   - ✅ Module with no signature FAILS
   - ✅ Works offline (no network required)

3. **Acceptance Criteria**:
   - [ ] Native crypto bridge methods implemented (Android + iOS)
   - [ ] ModuleVerifier uses native verification (not simulated)
   - [ ] All tamper tests pass (module fails verification if tampered)
   - [ ] Performance: verification completes in < 1 second
   - [ ] Works offline

---

## Impact Assessment

### On Upstream Foundry Architecture

**Impact**: None - aligns with architecture

Signature verification is already required by upstream architecture. This ADR chooses the implementation approach (native vs pure Dart).

### On Runtime Contract Shape

**Impact**: None

Module signature verification is transparent to position modules. No contract changes.

### On Auth and Trust Boundary

**Impact**: **CRITICAL POSITIVE**

Completes the trust boundary:
- ✅ Shell verifies module provenance before mount
- ✅ Tampered modules rejected
- ✅ Only verified modules receive bridge access
- ✅ Trust boundary integrity restored

### On Compiler Target Expectations

**Impact**: None

Compiler-generated modules unaffected. Verification happens before module execution.

### On Delivery, Activation, and Rollback Model

**Impact**: Positive

Enables secure module updates:
- ✅ Downloaded modules verified before activation
- ✅ Tampered updates rejected
- ✅ Fallback to last-known-good if verification fails

---

## Classification

**Deviation Type**: **Fundamental limitation in POC mode** - MUST be resolved for production

**Production Blocking**: **YES** - Trust boundary incomplete without cryptographic verification

**Priority**: 🔴 **CRITICAL**

**Recommendation**: Implement Option B before production release

---

## Fail Condition Assessment

**Per Section 8 — Architecture Fail Conditions**:

```
2. The capability only works by violating Foundry's auth or trust boundary.
```

**Current Status**: ⚠️ **CONDITIONAL PASS**

- POC mode acceptable for testing architecture
- Production requires completion of cryptographic verification
- Chosen approach (Option B) maintains trust boundary
- Not a fundamental architecture failure, but an implementation gap

**Verdict**: Architecture viable, implementation must be completed

---

## Action Items

### Immediate (Before Production):

1. [ ] **Approve Option B** (or alternative)
2. [ ] **Create implementation task**:
   - Task: "Implement native crypto bridge for signature verification"
   - Priority: Critical (production blocking)
   - Estimated effort: 1-2 days
   - Assign to: [TBD]

3. [ ] **Update reference documents**:
   - `foundry-position-shell-parity-evaluation.md`: Note POC limitation, document production requirement
   - `foundry-position-shell-poc-scenarios.md`: Update Scenario X-9 status

4. [ ] **Add to production readiness checklist**:
   - [ ] Cryptographic signature verification implemented
   - [ ] Tamper tests passing
   - [ ] Performance < 1s
   - [ ] Works offline

### For POC Continuation:

1. [ ] **Document POC limitation** clearly in all demos
2. [ ] **Add warning** in QUICKSTART_GUIDE.md:
   ```
   ⚠️ POC MODE: Signature verification simulated
   Production requires cryptographic verification (ADR-002)
   ```

3. [ ] **Proceed with Phase 3** knowing signature completion is production-blocking

---

## Success Metrics

**Verification Tests** (must all pass before production):

```dart
// Test 1: Valid signed module
test('valid signed module passes verification', () async {
  final result = await moduleVerifier.verifyModule(validModule);
  expect(result.isValid, true);
});

// Test 2: Tampered module (CRITICAL)
test('tampered module fails verification', () async {
  final tamperedModule = modifyModuleCode(validModule);
  final result = await moduleVerifier.verifyModule(tamperedModule);
  expect(result.isValid, false); // MUST FAIL
  expect(result.error, contains('signature'));
});

// Test 3: Invalid signature format
test('invalid signature format fails', () async {
  final result = await moduleVerifier.verifyModule(invalidFormatModule);
  expect(result.isValid, false);
});

// Test 4: No signature
test('missing signature fails', () async {
  final result = await moduleVerifier.verifyModule(unsignedModule);
  expect(result.isValid, false);
});

// Test 5: Performance
test('verification completes in < 1s', () async {
  final start = DateTime.now();
  await moduleVerifier.verifyModule(validModule);
  final duration = DateTime.now().difference(start);
  expect(duration.inMilliseconds, lessThan(1000));
});
```

---

## Status

**Current**: Proposed - **CRITICAL DECISION REQUIRED**
**Next Step**: Security architecture team review
**Decision Date**: [Pending]
**Approved By**: [Pending]

**⚠️ PRODUCTION BLOCKING**: This ADR must be approved and implemented before production release

---

**ADR-002 COMPLETE**
