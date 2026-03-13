import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foundry_shell/auth/mock_auth_service.dart';
import 'package:foundry_shell/position/position_resolver.dart';
import 'package:foundry_shell/session/session_broker.dart';

/// Integration tests for module lifecycle
///
/// Tests:
/// 1. Module mount with position context
/// 2. Position context delivery to module
/// 3. Module unmount cleanup
/// 4. Session handling during lifecycle
void main() {
  group('Module Lifecycle Integration Tests', () {
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

    test('Complete module mount flow with position context', () async {
      // Setup: Authenticate and get position
      await authService.authenticateUser(
        username: 'warehouse_clerk',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);

      // Generate bootstrap for module
      final bootstrap = await sessionBroker.generateBootstrapCode(position);

      expect(bootstrap, isNotNull);
      expect(bootstrap.positionId, equals(position.positionId));

      // Simulate runtime host redeeming bootstrap
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      expect(session, isNotNull);
      expect(session.sessionId, isNotEmpty);
      expect(session.positionId, equals(position.positionId));
      expect(session.orgId, equals(position.orgId));

      // Module receives position context with session
      expect(session.roleContext, equals(position.roleContext));

      // Verify session is valid
      final validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);
      expect(validation.session!.sessionId, equals(session.sessionId));
    });

    test('Position context delivery includes all required data', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify position context in session
      expect(session.positionId, equals('WAREHOUSE-CLERK-01'));
      expect(session.orgId, equals('ORG001'));

      // Verify role context
      expect(session.roleContext['department'], equals('Warehouse Operations'));
      expect(session.roleContext['location'], equals('Building A - Zone 3'));
      expect(session.roleContext['permissions'], isA<List>());

      // Verify specific permissions are available to module
      final permissions = session.roleContext['permissions'] as List;
      expect(permissions, contains('inventory.view'));
      expect(permissions, contains('inventory.count'));
      expect(permissions, contains('shipment.receive'));
      expect(permissions, contains('shipment.verify'));

      // Verify position-specific metadata
      expect(session.roleContext['warehouseZone'], equals('ZONE-A3'));
      expect(session.roleContext['shiftSchedule'], equals('Morning (6AM-2PM)'));
      expect(session.roleContext['supervisor'], equals('Jane Smith'));
    });

    test('Module unmount revokes session cleanly', () async {
      // Setup
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify session is active
      var validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);

      final activeSessionsBefore = sessionBroker.activeSessionCount;
      expect(activeSessionsBefore, greaterThan(0));

      // Simulate module unmount - revoke session
      await sessionBroker.revokeSession(session.sessionId);

      // Verify session is revoked
      validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isFalse);
      expect(validation.reason, equals('Session not found'));

      // Verify session count decreased
      final activeSessionsAfter = sessionBroker.activeSessionCount;
      expect(activeSessionsAfter, equals(activeSessionsBefore - 1));
    });

    test('Module can access scoped session throughout lifecycle', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Simulate module lifecycle with session access

      // 1. Module initialization - session is valid
      var validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);

      // 2. Module active - session remains valid
      await Future.delayed(const Duration(milliseconds: 100));
      validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);

      // 3. Module making API calls - session still valid
      await Future.delayed(const Duration(milliseconds: 100));
      validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);

      // 4. Module unmount - revoke session
      await sessionBroker.revokeSession(session.sessionId);
      validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isFalse);
    });

    test('Position switch creates new session and revokes old', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position1 = await positionResolver.resolvePosition(username!);

      // Mount first module
      final bootstrap1 = await sessionBroker.generateBootstrapCode(position1);
      final session1 = await sessionBroker.redeemBootstrap(bootstrap1.code, position1);

      expect(session1.positionId, equals('WAREHOUSE-CLERK-01'));

      // Simulate position switch (unmount current, mount new)
      // In production, this would be a different position
      // For Phase 1, we simulate by creating new session

      // Revoke old session
      await sessionBroker.revokeSession(session1.sessionId);

      // Create new session for "new" position
      final bootstrap2 = await sessionBroker.generateBootstrapCode(position1);
      final session2 = await sessionBroker.redeemBootstrap(bootstrap2.code, position1);

      // Verify old session invalid, new session valid
      final validation1 = await sessionBroker.validateSession(session1.sessionId);
      expect(validation1.isValid, isFalse);

      final validation2 = await sessionBroker.validateSession(session2.sessionId);
      expect(validation2.isValid, isTrue);

      // Sessions should be different
      expect(session1.sessionId, isNot(equals(session2.sessionId)));
    });

    test('Module receives correct role context for position', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Verify role context matches position
      expect(session.roleContext, equals(position.roleContext));

      // Verify context is complete
      expect(session.roleContext.keys.length, greaterThan(5));

      // Verify expected fields
      final expectedFields = [
        'department',
        'location',
        'permissions',
        'warehouseZone',
        'shiftSchedule',
        'supervisor',
      ];

      for (final field in expectedFields) {
        expect(
          session.roleContext.containsKey(field),
          isTrue,
          reason: 'Role context should contain $field',
        );
      }
    });

    test('Module cannot access session after unmount', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Module is mounted and has access
      var validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isTrue);

      // Module unmounts
      await sessionBroker.revokeSession(session.sessionId);

      // Module attempts to use session after unmount - should fail
      validation = await sessionBroker.validateSession(session.sessionId);
      expect(validation.isValid, isFalse);

      // Any API call with revoked session should fail
      // (In production, backend would validate and reject)
    });

    test('Bootstrap to session flow is repeatable', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);

      // First mount
      final bootstrap1 = await sessionBroker.generateBootstrapCode(position);
      final session1 = await sessionBroker.redeemBootstrap(bootstrap1.code, position);
      expect(session1, isNotNull);

      // Unmount
      await sessionBroker.revokeSession(session1.sessionId);

      // Second mount (different session)
      final bootstrap2 = await sessionBroker.generateBootstrapCode(position);
      final session2 = await sessionBroker.redeemBootstrap(bootstrap2.code, position);
      expect(session2, isNotNull);

      // Sessions should be independent
      expect(session1.sessionId, isNot(equals(session2.sessionId)));

      // Unmount
      await sessionBroker.revokeSession(session2.sessionId);

      // Third mount
      final bootstrap3 = await sessionBroker.generateBootstrapCode(position);
      final session3 = await sessionBroker.redeemBootstrap(bootstrap3.code, position);
      expect(session3, isNotNull);

      // All sessions unique
      expect(session3.sessionId, isNot(equals(session1.sessionId)));
      expect(session3.sessionId, isNot(equals(session2.sessionId)));
    });

    test('Session validation returns complete session data', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Validate session
      final validation = await sessionBroker.validateSession(session.sessionId);

      expect(validation.isValid, isTrue);
      expect(validation.session, isNotNull);

      // Returned session should have all data
      final returnedSession = validation.session!;
      expect(returnedSession.sessionId, equals(session.sessionId));
      expect(returnedSession.positionId, equals(session.positionId));
      expect(returnedSession.orgId, equals(session.orgId));
      expect(returnedSession.roleContext, equals(session.roleContext));
      expect(returnedSession.createdAt, equals(session.createdAt));
      expect(returnedSession.expiresAt, equals(session.expiresAt));
    });

    test('Session JSON serialization preserves all data', () async {
      await authService.authenticateUser(
        username: 'test_user',
        password: 'password',
      );

      final username = await authService.getCurrentUsername();
      final position = await positionResolver.resolvePosition(username!);
      final bootstrap = await sessionBroker.generateBootstrapCode(position);
      final session = await sessionBroker.redeemBootstrap(bootstrap.code, position);

      // Serialize to JSON
      final json = session.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['sessionId'], equals(session.sessionId));
      expect(json['positionId'], equals(session.positionId));
      expect(json['orgId'], equals(session.orgId));
      expect(json['roleContext'], equals(session.roleContext));
      expect(json['createdAt'], isA<String>());
      expect(json['expiresAt'], isA<String>());

      // Verify dates are ISO format
      expect(json['createdAt'], contains('T'));
      expect(json['expiresAt'], contains('T'));
    });
  });
}
