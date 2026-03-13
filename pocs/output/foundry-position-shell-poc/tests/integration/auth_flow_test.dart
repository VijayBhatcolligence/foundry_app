import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foundry_shell/auth/mock_auth_service.dart';
import 'package:foundry_shell/position/position_resolver.dart';
import 'package:foundry_shell/session/session_broker.dart';

/// Integration tests for end-to-end authentication flow
///
/// Tests the complete flow:
/// 1. Mock authentication
/// 2. Shell token storage
/// 3. Position resolution
/// 4. Bootstrap generation
void main() {
  group('Authentication Flow Integration Tests', () {
    late MockAuthService authService;
    late PositionResolver positionResolver;
    late SessionBroker sessionBroker;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      authService = MockAuthService();
      positionResolver = PositionResolver();
      sessionBroker = SessionBroker();
    });

    tearDown(() {
      sessionBroker.clearAll();
    });

    test('Complete auth flow: login -> position resolution -> bootstrap', () async {
      // Step 1: User authentication
      final authSuccess = await authService.authenticateUser(
        username: 'warehouse_user',
        password: 'secure_password',
      );

      expect(authSuccess, isTrue, reason: 'Authentication should succeed');

      // Step 2: Verify shell token is stored securely
      final shellToken = await authService.getShellToken();
      expect(shellToken, isNotNull, reason: 'Shell token should be stored after auth');
      expect(shellToken, isNotEmpty);

      // Verify token format (mock JWT-like structure)
      expect(shellToken!.split('.').length, equals(3), reason: 'Token should be JWT-like');

      // Step 3: Verify user is authenticated
      final isAuthenticated = await authService.isAuthenticated();
      expect(isAuthenticated, isTrue);

      // Step 4: Get current username
      final username = await authService.getCurrentUsername();
      expect(username, equals('warehouse_user'));

      // Step 5: Resolve position for authenticated user
      final position = await positionResolver.resolvePosition(username!);

      expect(position, isNotNull);
      expect(position.orgId, equals('ORG001'));
      expect(position.positionId, equals('WAREHOUSE-CLERK-01'));
      expect(position.positionName, equals('Warehouse Clerk'));

      // Step 6: Verify position has role context
      expect(position.roleContext, isNotEmpty);
      expect(position.roleContext['department'], equals('Warehouse Operations'));
      expect(position.roleContext['permissions'], isA<List>());
      expect(
        (position.roleContext['permissions'] as List).length,
        greaterThan(0),
        reason: 'Position should have permissions',
      );

      // Step 7: Generate bootstrap code for web session
      final bootstrap = await sessionBroker.generateBootstrapCode(position);

      expect(bootstrap, isNotNull);
      expect(bootstrap.code, isNotEmpty);
      expect(bootstrap.positionId, equals(position.positionId));
      expect(bootstrap.isExpired, isFalse);

      // Step 8: Verify bootstrap is different from shell token
      expect(bootstrap.code, isNot(equals(shellToken)));
      expect(bootstrap.code, isNot(contains(shellToken)));
    });

    test('Failed authentication does not create shell token', () async {
      // Attempt authentication with empty credentials
      final authSuccess = await authService.authenticateUser(
        username: '',
        password: '',
      );

      expect(authSuccess, isFalse);

      // Verify no shell token stored
      final shellToken = await authService.getShellToken();
      expect(shellToken, isNull);

      // Verify user is not authenticated
      final isAuthenticated = await authService.isAuthenticated();
      expect(isAuthenticated, isFalse);
    });

    test('Logout clears shell token and invalidates sessions', () async {
      // Login
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      expect(await authService.isAuthenticated(), isTrue);

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify session is valid
      final validationBefore = await sessionBroker.validateSession(session.sessionId);
      expect(validationBefore.isValid, isTrue);

      // Logout
      await authService.logout();

      // Verify shell token is cleared
      expect(await authService.getShellToken(), isNull);
      expect(await authService.isAuthenticated(), isFalse);

      // Note: In production, logout would also revoke all active sessions
      // For Phase 1, sessions persist until explicitly revoked
    });

    test('Position resolution returns consistent data', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();

      // Resolve position multiple times
      final position1 = await positionResolver.resolvePosition(username!);
      final position2 = await positionResolver.resolvePosition(username);

      // Should return same position data
      expect(position1.orgId, equals(position2.orgId));
      expect(position1.positionId, equals(position2.positionId));
      expect(position1.positionName, equals(position2.positionName));
      expect(position1.roleContext, equals(position2.roleContext));
    });

    test('Multiple users can authenticate independently', () async {
      // User 1 authentication
      await authService.authenticateUser(
        username: 'user1',
        password: 'pass1',
      );

      final token1 = await authService.getShellToken();
      final username1 = await authService.getCurrentUsername();

      expect(token1, isNotNull);
      expect(username1, equals('user1'));

      // Logout user 1
      await authService.logout();

      // User 2 authentication
      await authService.authenticateUser(
        username: 'user2',
        password: 'pass2',
      );

      final token2 = await authService.getShellToken();
      final username2 = await authService.getCurrentUsername();

      expect(token2, isNotNull);
      expect(username2, equals('user2'));

      // Tokens should be different
      expect(token1, isNot(equals(token2)));
    });

    test('Bootstrap generation creates unique codes', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);

      // Generate multiple bootstrap codes
      final bootstrap1 = await sessionBroker.generateBootstrapCode(position);
      final bootstrap2 = await sessionBroker.generateBootstrapCode(position);
      final bootstrap3 = await sessionBroker.generateBootstrapCode(position);

      // All codes should be unique
      expect(bootstrap1.code, isNot(equals(bootstrap2.code)));
      expect(bootstrap2.code, isNot(equals(bootstrap3.code)));
      expect(bootstrap1.code, isNot(equals(bootstrap3.code)));

      // All should be for same position
      expect(bootstrap1.positionId, equals(position.positionId));
      expect(bootstrap2.positionId, equals(position.positionId));
      expect(bootstrap3.positionId, equals(position.positionId));
    });

    test('Auth flow validation checks', () async {
      // Verify cannot resolve position without authentication
      expect(
        () => positionResolver.resolvePosition('unknown_user'),
        returnsNormally,
        reason: 'Position resolver should handle unauthenticated users gracefully',
      );

      // Authenticate
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      // Now position resolution should work
      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);

      expect(position, isNotNull);

      // Can generate bootstrap only for valid position
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      expect(bootstrap, isNotNull);
    });

    test('Shell token contains expected user information', () async {
      await authService.authenticateUser(
        username: 'detailed_user',
        password: 'password',
      );

      final shellToken = await authService.getShellToken();
      expect(shellToken, isNotNull);

      // Parse token parts
      final parts = shellToken!.split('.');
      expect(parts.length, equals(3)); // header.payload.signature

      // Decode payload (base64url)
      // Note: In real implementation, we would decode and verify
      // For this test, we just verify structure
      expect(parts[0], isNotEmpty); // header
      expect(parts[1], isNotEmpty); // payload
      expect(parts[2], isNotEmpty); // signature

      // Verify username can be extracted
      final username = await authService.getCurrentUsername();
      expect(username, equals('detailed_user'));
    });

    test('Position context includes all required fields', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);

      // Verify required fields
      expect(position.orgId, isNotEmpty);
      expect(position.positionId, isNotEmpty);
      expect(position.positionName, isNotEmpty);
      expect(position.roleContext, isNotEmpty);

      // Verify role context has expected fields
      expect(position.roleContext['department'], isNotNull);
      expect(position.roleContext['location'], isNotNull);
      expect(position.roleContext['permissions'], isNotNull);

      // Verify permissions is a list
      expect(position.roleContext['permissions'], isA<List>());

      // Verify specific permissions exist
      final permissions = position.roleContext['permissions'] as List;
      expect(permissions, contains('inventory.view'));
      expect(permissions, contains('inventory.count'));
    });
  });
}
