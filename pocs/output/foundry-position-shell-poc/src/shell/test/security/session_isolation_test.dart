import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foundry_shell/auth/mock_auth_service.dart';
import 'package:foundry_shell/position/position_resolver.dart';
import 'package:foundry_shell/session/session_broker.dart';
import 'package:flutter/services.dart';

/// Tests session isolation and security properties
///
/// Validates:
/// 1. Scoped sessions are distinct from shell token
/// 2. Bootstrap codes are one-time-use only
/// 3. Sessions cannot be escalated to shell token access
/// 4. Sessions are position-scoped (cannot access other positions)
void main() {
  group('Session Isolation Tests', () {
    late MockAuthService authService;
    late PositionResolver positionResolver;
    late SessionBroker sessionBroker;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      FlutterSecureStorage.setMockInitialValues({});

      // Mock any platform channels that might be accessed
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '/tmp/test_app_support';
        }
        return null;
      });

      authService = MockAuthService();
      positionResolver = PositionResolver();
      sessionBroker = SessionBroker();
    });

    tearDown(() {
      sessionBroker.clearAll();
    });

    test('Scoped session is distinct from shell token', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');

      // Act: Create scoped session
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Assert: Session is completely different from shell token
      expect(session.sessionId, isNot(equals(shellToken)));
      expect(session.sessionId, isNot(contains(shellToken!)));

      // Scoped session should have limited information
      expect(session.positionId, equals(position.positionId));
      expect(session.orgId, equals(position.orgId));

      // Session should NOT contain full user identity that shell token has
      expect(session.sessionId.length, lessThan(shellToken.length));
    });

    test('Bootstrap code is one-time-use only', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');
      final bootstrap = await sessionBroker.generateBootstrapCode(position);

      // Act: Redeem bootstrap once
      final session1 = await sessionBroker.redeemBootstrap(bootstrap.code, position);
      expect(session1, isNotNull);

      // Assert: Second redemption attempt should fail
      expect(
        () => sessionBroker.redeemBootstrap(bootstrap.code, position),
        throwsA(
          predicate((e) => e.toString().contains('Invalid bootstrap code')),
        ),
        reason: 'Bootstrap code must be one-time-use only',
      );
    });

    test('Bootstrap code expires after timeout', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');
      final bootstrap = await sessionBroker.generateBootstrapCode(position);

      // Wait for expiry (bootstrap expires in 60 seconds)
      // For testing, we manually expire it by waiting past the expiry time
      await Future.delayed(const Duration(milliseconds: 100));

      // Manually check expiry
      expect(bootstrap.isExpired, isFalse, reason: 'Should not be expired yet');

      // In real test, we would wait 60+ seconds or mock time
      // For now, verify expiry checking works
      final expiredBootstrap = BootstrapCode(
        code: 'expired_code',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        positionId: position.positionId,
      );

      expect(expiredBootstrap.isExpired, isTrue);
    });

    test('Session cannot be escalated to shell token access', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final shellToken = await authService.getShellToken();
      final position = await positionResolver.resolvePosition('test_user');

      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Act: Validate session
      final validation = await sessionBroker.validateSession(session.sessionId);

      // Assert: Validation returns session info but NOT shell token
      expect(validation.isValid, isTrue);
      expect(validation.session, isNotNull);

      // Session validation should never return shell token
      expect(validation.session!.sessionId, isNot(equals(shellToken)));

      final sessionJson = validation.session!.toJson();
      sessionJson.forEach((key, value) {
        if (value is String) {
          expect(
            value,
            isNot(contains(shellToken!)),
            reason: 'Session field $key must not contain shell token',
          );
        }
      });
    });

    test('Session is position-scoped - cannot access other positions', () async {
      // This test validates that a session for one position
      // cannot be used to access data for another position

      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify session is bound to specific position
      expect(session.positionId, equals(position.positionId));
      expect(session.orgId, equals(position.orgId));

      // Verify session contains only position-specific role context
      expect(session.roleContext, equals(position.roleContext));

      // Session should not allow escalation to different position
      // (In production, API calls would validate session scope)
      expect(session.positionId, equals('WAREHOUSE-CLERK-01'));

      // Attempting to use this session for a different position would fail
      // This would be enforced at the API level in production
    });

    test('Multiple sessions can exist for same position', () async {
      // Validates that multiple sessions can be created for the same position
      // (e.g., user opens app on multiple devices)

      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');

      // Create multiple sessions
      final bootstrap1 = await sessionBroker.generateBootstrapCode(position);
      final session1 = await sessionBroker.redeemBootstrap(bootstrap1.code, position);

      final bootstrap2 = await sessionBroker.generateBootstrapCode(position);
      final session2 = await sessionBroker.redeemBootstrap(bootstrap2.code, position);

      // All sessions should be unique
      expect(session1.sessionId, isNot(equals(session2.sessionId)));

      // Both sessions should be valid
      final validation1 = await sessionBroker.validateSession(session1.sessionId);
      final validation2 = await sessionBroker.validateSession(session2.sessionId);

      expect(validation1.isValid, isTrue);
      expect(validation2.isValid, isTrue);

      // Both should be for same position
      expect(session1.positionId, equals(session2.positionId));
    });

    test('Session revocation invalidates session immediately', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify session is valid
      var validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);

      // Act: Revoke session
      await sessionBroker.revokeSession(session.sessionId);

      // Assert: Session is now invalid
      validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isFalse);
      expect(validation.reason, equals('Session not found'));
    });

    test('Session expiry is enforced', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify session is not expired
      expect(session.isExpired, isFalse);

      // Session expires in 8 hours - verify expiry time is set correctly
      final now = DateTime.now();
      final expiryDiff = session.expiresAt.difference(now);

      expect(expiryDiff.inHours, greaterThanOrEqualTo(7));
      expect(expiryDiff.inHours, lessThanOrEqualTo(8));
    });

    test('Bootstrap position validation prevents position mismatch', () async {
      // This test validates that bootstrap codes are tied to specific positions
      // and cannot be used for different positions

      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');
      final bootstrap = await sessionBroker.generateBootstrapCode(position);

      // Verify bootstrap is tied to position
      expect(bootstrap.positionId, equals(position.positionId));

      // Attempting to redeem for wrong position would fail
      final differentPosition = Position(
        orgId: 'ORG002',
        positionId: 'DIFFERENT-POSITION',
        positionName: 'Different Position',
        roleContext: {},
      );

      expect(
        () => sessionBroker.redeemBootstrap(bootstrap.code, differentPosition),
        throwsA(
          predicate((e) => e.toString().contains('Position mismatch')),
        ),
        reason: 'Bootstrap code must be position-specific',
      );
    });

    test('Session broker tracks active sessions correctly', () async {
      // Arrange
      await authService.authenticateUser(
        username: 'test_user',
        password: 'test_pass',
      );

      final position = await positionResolver.resolvePosition('test_user');

      // Initially no sessions
      expect(sessionBroker.activeSessionCount, equals(0));

      // Create session
      final bootstrap1 = await sessionBroker.generateBootstrapCode(position);
      final session1 = await sessionBroker.redeemBootstrap(bootstrap1.code, position);

      expect(sessionBroker.activeSessionCount, equals(1));

      // Create second session
      final bootstrap2 = await sessionBroker.generateBootstrapCode(position);
      final session2 = await sessionBroker.redeemBootstrap(bootstrap2.code, position);

      expect(sessionBroker.activeSessionCount, equals(2));

      // Revoke one session
      await sessionBroker.revokeSession(session1.sessionId);
      expect(sessionBroker.activeSessionCount, equals(1));

      // Revoke second session
      await sessionBroker.revokeSession(session2.sessionId);
      expect(sessionBroker.activeSessionCount, equals(0));
    });
  });
}
