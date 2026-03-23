// Phase 3: Network State Model
// Purpose: Enum and helper classes for network state representation

enum NetworkState {
  online,      // internet reachable
  offline,     // no connectivity
  reconnecting // transitioning from offline to online
}

enum NetworkType {
  wifi,
  cellular,
  ethernet,
  vpn,
  none
}

class NetworkStateChange {
  final NetworkState previousState;
  final NetworkState currentState;
  final DateTime timestamp;

  NetworkStateChange({
    required this.previousState,
    required this.currentState,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'previousState': previousState.name,
      'currentState': currentState.name,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'NetworkStateChange(${previousState.name} → ${currentState.name} at ${timestamp.toIso8601String()})';
  }
}
