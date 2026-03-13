import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../position/position_resolver.dart';

/// Bootstrap code for one-time session initialization
class BootstrapCode {
  final String code;
  final DateTime expiresAt;
  final String positionId;

  BootstrapCode({
    required this.code,
    required this.expiresAt,
    required this.positionId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Scoped web session tied to specific position
class ScopedSession {
  final String sessionId;
  final String positionId;
  final String orgId;
  final Map<String, dynamic> roleContext;
  final DateTime createdAt;
  final DateTime expiresAt;

  ScopedSession({
    required this.sessionId,
    required this.positionId,
    required this.orgId,
    required this.roleContext,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'positionId': positionId,
        'orgId': orgId,
        'roleContext': roleContext,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// Session validation result
class SessionValidation {
  final bool isValid;
  final String? reason;
  final ScopedSession? session;

  SessionValidation.valid(this.session)
      : isValid = true,
        reason = null;

  SessionValidation.invalid(this.reason)
      : isValid = false,
        session = null;
}

/// Session broker manages bootstrap codes and scoped web sessions
///
/// CRITICAL SECURITY BOUNDARY:
/// - Bootstrap codes are ONE-TIME-USE only
/// - Scoped sessions are position-limited (cannot access other positions)
/// - Shell token NEVER exposed to web layer
/// - Sessions have limited lifetime
class SessionBroker {
  final Uuid _uuid = const Uuid();

  // In-memory storage for Phase 1 (production would use secure backend)
  final Map<String, BootstrapCode> _bootstrapCodes = {};
  final Map<String, ScopedSession> _scopedSessions = {};

  /// Generates one-time bootstrap code for position
  ///
  /// This code is passed to runtime host to redeem for scoped session.
  /// SECURITY: Bootstrap expires in 60 seconds and can only be used once.
  Future<BootstrapCode> generateBootstrapCode(Position position) async {
    final code = _generateSecureCode();
    final bootstrap = BootstrapCode(
      code: code,
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      positionId: position.positionId,
    );

    _bootstrapCodes[code] = bootstrap;

    // Auto-cleanup expired codes after 2 minutes
    Future.delayed(const Duration(minutes: 2), () {
      _bootstrapCodes.remove(code);
    });

    return bootstrap;
  }

  /// Redeems bootstrap code for scoped session
  ///
  /// SECURITY: This is the critical conversion point:
  /// - Bootstrap code is validated and CONSUMED (one-time-use)
  /// - New scoped session is created with limited permissions
  /// - Shell token remains in Flutter layer ONLY
  Future<ScopedSession> redeemBootstrap(
    String bootstrapCode,
    Position position,
  ) async {
    // Validate bootstrap code exists
    final bootstrap = _bootstrapCodes[bootstrapCode];
    if (bootstrap == null) {
      throw Exception('Invalid bootstrap code');
    }

    // Validate not expired
    if (bootstrap.isExpired) {
      _bootstrapCodes.remove(bootstrapCode);
      throw Exception('Bootstrap code expired');
    }

    // Validate position match
    if (bootstrap.positionId != position.positionId) {
      throw Exception('Position mismatch');
    }

    // CRITICAL: Consume bootstrap code (one-time-use enforcement)
    _bootstrapCodes.remove(bootstrapCode);

    // Create scoped session
    final session = ScopedSession(
      sessionId: _uuid.v4(),
      positionId: position.positionId,
      orgId: position.orgId,
      roleContext: position.roleContext,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 8)), // 8-hour work shift
    );

    _scopedSessions[session.sessionId] = session;

    // Auto-cleanup expired session
    Future.delayed(const Duration(hours: 8, minutes: 5), () {
      _scopedSessions.remove(session.sessionId);
    });

    return session;
  }

  /// Validates scoped session for runtime host requests
  ///
  /// This is called by bridge methods to ensure requests are authorized
  Future<SessionValidation> validateSession(String sessionId) async {
    final session = _scopedSessions[sessionId];

    if (session == null) {
      return SessionValidation.invalid('Session not found');
    }

    if (session.isExpired) {
      _scopedSessions.remove(sessionId);
      return SessionValidation.invalid('Session expired');
    }

    return SessionValidation.valid(session);
  }

  /// Revokes scoped session (called during module unmount)
  Future<void> revokeSession(String sessionId) async {
    _scopedSessions.remove(sessionId);
  }

  /// Generates cryptographically secure bootstrap code
  String _generateSecureCode() {
    final random = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = '$random-$timestamp';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).substring(0, 32);
  }

  /// Get active session count (for monitoring/debugging)
  int get activeSessionCount => _scopedSessions.length;

  /// Get pending bootstrap count (for monitoring/debugging)
  int get pendingBootstrapCount => _bootstrapCodes.length;

  /// Clear all sessions (for testing/logout)
  void clearAll() {
    _bootstrapCodes.clear();
    _scopedSessions.clear();
  }
}
