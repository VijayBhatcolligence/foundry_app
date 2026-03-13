import 'dart:convert';

/// Represents an organizational position with associated metadata
class Position {
  final String orgId;
  final String positionId;
  final String positionName;
  final Map<String, dynamic> roleContext;

  Position({
    required this.orgId,
    required this.positionId,
    required this.positionName,
    required this.roleContext,
  });

  Map<String, dynamic> toJson() => {
        'orgId': orgId,
        'positionId': positionId,
        'positionName': positionName,
        'roleContext': roleContext,
      };

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        orgId: json['orgId'] as String,
        positionId: json['positionId'] as String,
        positionName: json['positionName'] as String,
        roleContext: json['roleContext'] as Map<String, dynamic>,
      );

  @override
  String toString() => json.encode(toJson());
}

/// Resolves user's organizational position after authentication
///
/// In production, this would query backend services to determine
/// which org/position the user belongs to based on their identity.
///
/// For Phase 1, we use mock data for warehouse clerk position.
class PositionResolver {
  /// Resolves position for authenticated user
  ///
  /// In production, this would:
  /// 1. Query user service with shell token
  /// 2. Determine org membership
  /// 3. Resolve active position
  /// 4. Fetch role context/permissions
  Future<Position> resolvePosition(String username) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock position resolution - warehouse clerk for demo
    return Position(
      orgId: 'ORG001',
      positionId: 'WAREHOUSE-CLERK-01',
      positionName: 'Warehouse Clerk',
      roleContext: {
        'department': 'Warehouse Operations',
        'location': 'Building A - Zone 3',
        'permissions': [
          'inventory.view',
          'inventory.count',
          'shipment.receive',
          'shipment.verify',
        ],
        'warehouseZone': 'ZONE-A3',
        'shiftSchedule': 'Morning (6AM-2PM)',
        'supervisor': 'Jane Smith',
      },
    );
  }

  /// Resolves multiple positions if user has access to multiple roles
  /// Returns list of available positions for position switching
  Future<List<Position>> resolveAvailablePositions(String username) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // For Phase 1, return single position
    // Phase 2+ would support multiple positions per user
    final primaryPosition = await resolvePosition(username);
    return [primaryPosition];
  }

  /// Validates if user has access to specific position
  Future<bool> canAccessPosition(
    String username,
    String positionId,
  ) async {
    final positions = await resolveAvailablePositions(username);
    return positions.any((p) => p.positionId == positionId);
  }
}
