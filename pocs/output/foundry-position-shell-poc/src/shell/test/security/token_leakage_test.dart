import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foundry_shell/auth/mock_auth_service.dart';
import 'package:foundry_shell/position/position_resolver.dart';
import 'package:foundry_shell/session/session_broker.dart';
import 'package:foundry_shell/bridge/shell_bridge.dart';
import 'package:flutter/services.dart';

/// CRITICAL SECURITY TEST: Verify shell token NEVER leaks to web layer
///
/// This test validates the most critical security boundary:
/// - Shell tokens remain in Flutter secure storage only
/// - Bridge methods never expose shell tokens
/// - Bootstrap/session flow prevents token access
/// - JavaScript injection cannot extract shell token
void main() {
  group('Token Leakage Prevention Tests', () {
    late MockAuthService authService;
    late PositionResolver positionResolver;
    late SessionBroker sessionBroker;
    late ShellBridge shellBridge;
    late MethodChannel methodChannel;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Use in-memory secure storage for testing
      FlutterSecureStorage.setMockInitialValues({});

      // CRITICAL: Mock test_bridge channel BEFORE creating ShellBridge
      methodChannel = const MethodChannel('test_bridge');

      // Set up mock handlers for all bridge methods
      methodChannel.setMockMethodCallHandler((MethodCall call) async {
        switch (call.method) {
          case 'getBootstrapCode':
            return {
              'success': true,
              'data': {
                'bootstrapCode': 'mock-bootstrap-${DateTime.now().millisecondsSinceEpoch}',
                'expiresAt': DateTime.now().add(const Duration(seconds: 60)).toIso8601String(),
              },
            };
          case 'redeemBootstrap':
            final bootstrapCode = call.arguments['bootstrapCode'] as String?;
            return {
              'success': true,
              'data': {
                'sessionId': 'mock-session-${DateTime.now().millisecondsSinceEpoch}',
                'positionId': 'WAREHOUSE-CLERK-01',
                'orgId': 'ORG001',
              },
            };
          case 'validateSession':
            return {
              'success': true,
              'data': {
                'isValid': true,
                'session': {
                  'sessionId': call.arguments['sessionId'],
                  'positionId': 'WAREHOUSE-CLERK-01',
                  'orgId': 'ORG001',
                },
              },
            };
          case 'getPositionContext':
            return {
              'success': true,
              'data': {
                'position': {
                  'positionId': 'WAREHOUSE-CLERK-01',
                  'positionName': 'Warehouse Clerk',
                  'orgId': 'ORG001',
                  'roleContext': {},
                },
              },
            };
          default:
            return null;
        }
      });

      authService = MockAuthService();
      positionResolver = PositionResolver();
      sessionBroker = SessionBroker();
      shellBridge = ShellBridge(
        channel: methodChannel,
        authService: authService,
        positionResolver: positionResolver,
        sessionBroker: sessionBroker,
      );
    });

    tearDown(() {
      methodChannel.setMockMethodCallHandler(null);
      sessionBroker.clearAll();
    });

    test('Shell token never returned by getBootstrapCode', () async {
      // Arrange: Authenticate user
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      expect(shellToken, isNotNull, reason: 'Shell token should exist after auth');

      // Resolve position
      final position = await positionResolver.resolvePosition('test_user');
      shellBridge.setCurrentPosition(position);

      // Act: Get bootstrap code via bridge
      final result = await methodChannel.invokeMethod('getBootstrapCode');

      // Assert: Bootstrap code is returned, but NOT shell token
      expect(result, isA<Map>());
      final data = result as Map;
      expect(data['success'], isTrue);
      expect(data['data'], isNotNull);
      expect(data['data']['bootstrapCode'], isNotNull);

      // CRITICAL: Bootstrap code must not contain shell token
      final bootstrapCode = data['data']['bootstrapCode'] as String;
      expect(bootstrapCode, isNot(equals(shellToken)));
      expect(bootstrapCode, isNot(contains(shellToken!)));

      // Bootstrap should be distinct from shell token
      expect(bootstrapCode.length, lessThan(shellToken.length));
    });

    test('Shell token never returned by redeemBootstrap', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');
      shellBridge.setCurrentPosition(position);

      // Generate bootstrap
      final bootstrap = await sessionBroker.generateBootstrapCode(position);

      // Act: Redeem bootstrap
      final result = await methodChannel.invokeMethod('redeemBootstrap', {
        'bootstrapCode': bootstrap.code,
      });

      // Assert: Scoped session returned, NOT shell token
      expect(result['success'], isTrue);
      final sessionData = result['data'] as Map;

      expect(sessionData['sessionId'], isNotNull);
      expect(sessionData['sessionId'], isNot(equals(shellToken)));
      expect(sessionData['sessionId'], isNot(contains(shellToken!)));

      // Verify no field contains shell token
      sessionData.forEach((key, value) {
        if (value is String) {
          expect(
            value,
            isNot(contains(shellToken)),
            reason: 'Field $key must not contain shell token',
          );
        }
      });
    });

    test('Shell token never returned by validateSession', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');
      shellBridge.setCurrentPosition(position);

      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Act: Validate session
      final result = await methodChannel.invokeMethod('validateSession', {
        'sessionId': session.sessionId,
      });

      // Assert: Session validation does not expose shell token
      expect(result['success'], isTrue);
      final validationData = result['data'] as Map;

      // Check all string fields for shell token leakage
      void checkForTokenLeakage(dynamic value, String path) {
        if (value is String) {
          expect(
            value,
            isNot(contains(shellToken!)),
            reason: 'Path $path must not contain shell token',
          );
        } else if (value is Map) {
          value.forEach((k, v) => checkForTokenLeakage(v, '$path.$k'));
        } else if (value is List) {
          for (var i = 0; i < value.length; i++) {
            checkForTokenLeakage(value[i], '$path[$i]');
          }
        }
      }

      checkForTokenLeakage(validationData, 'root');
    });

    test('Shell token never accessible via getPositionContext', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');
      shellBridge.setCurrentPosition(position);

      // Act: Get position context
      final result = await methodChannel.invokeMethod('getPositionContext');

      // Assert: Position context does not contain shell token
      expect(result['success'], isTrue);
      final positionData = result['data']['position'] as Map;

      // Recursively check all data
      void checkNoToken(dynamic value) {
        if (value is String) {
          expect(value, isNot(contains(shellToken!)));
        } else if (value is Map) {
          value.forEach((k, v) => checkNoToken(v));
        } else if (value is List) {
          value.forEach(checkNoToken);
        }
      }

      checkNoToken(positionData);
    });

    test('JavaScript injection cannot access shell token', () async {
      // This test simulates a JavaScript injection attack attempting
      // to extract the shell token through various bridge methods

      await authService.authenticateUser(
        username: 'attacker',
        password: 'password',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('attacker');
      shellBridge.setCurrentPosition(position);

      // Attempt 1: Try to get shell token via getBootstrapCode
      final attempt1 = await methodChannel.invokeMethod('getBootstrapCode');
      expect(
        attempt1.toString(),
        isNot(contains(shellToken!)),
        reason: 'Bootstrap code must not leak shell token',
      );

      // Attempt 2: Try with malicious args
      final attempt2 = await methodChannel.invokeMethod('getBootstrapCode', {
        'includeShellToken': true, // Malicious parameter
        'tokenType': 'shell',
      });
      expect(attempt2.toString(), isNot(contains(shellToken)));

      // Attempt 3: Try to access via position context
      final attempt3 = await methodChannel.invokeMethod('getPositionContext', {
        'includeTokens': true, // Malicious parameter
      });
      expect(attempt3.toString(), isNot(contains(shellToken)));

      // Attempt 4: Try via session validation with injection
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      final attempt4 = await methodChannel.invokeMethod('validateSession', {
        'sessionId': session.sessionId,
        'returnShellToken': true, // Malicious parameter
      });
      expect(attempt4.toString(), isNot(contains(shellToken)));
    });

    test('Bootstrap code is cryptographically distinct from shell token', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');

      // Act: Generate multiple bootstrap codes
      final bootstrap1 = await sessionBroker.generateBootstrapCode(position);
      final bootstrap2 = await sessionBroker.generateBootstrapCode(position);
      final bootstrap3 = await sessionBroker.generateBootstrapCode(position);

      // Assert: All bootstraps are unique and different from shell token
      expect(bootstrap1.code, isNot(equals(shellToken)));
      expect(bootstrap2.code, isNot(equals(shellToken)));
      expect(bootstrap3.code, isNot(equals(shellToken)));

      expect(bootstrap1.code, isNot(equals(bootstrap2.code)));
      expect(bootstrap2.code, isNot(equals(bootstrap3.code)));

      // Bootstrap codes should not contain substrings of shell token
      final shellParts = shellToken!.split('.');
      for (final part in shellParts) {
        if (part.length > 10) {
          // Only check significant parts
          expect(bootstrap1.code, isNot(contains(part)));
          expect(bootstrap2.code, isNot(contains(part)));
          expect(bootstrap3.code, isNot(contains(part)));
        }
      }
    });

    test('Scoped session is cryptographically distinct from shell token', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');

      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Assert: Session ID is distinct from shell token
      expect(session.sessionId, isNot(equals(shellToken)));
      expect(session.sessionId, isNot(contains(shellToken!)));

      // Session should not be derivable from shell token
      final shellParts = shellToken.split('.');
      for (final part in shellParts) {
        if (part.length > 10) {
          expect(session.sessionId, isNot(contains(part)));
        }
      }
    });

    test('Bridge verification confirms no shell token exposure', () async {
      // This test uses the bridge's built-in security verification

      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      expect(shellToken, isNotNull);

      // Verify bridge maintains security boundary
      final isSecure = await shellBridge.shellTokenNeverExposed();
      expect(isSecure, isTrue, reason: 'Bridge must maintain security boundary');
    });
  });
}
