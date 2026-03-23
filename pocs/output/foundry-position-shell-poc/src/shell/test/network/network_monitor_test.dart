// Phase 3: Network Monitor Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/network/network_monitor.dart';
import 'package:foundry_shell/network/network_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkMonitor', () {
    late NetworkMonitor monitor;

    setUp(() async {
      monitor = NetworkMonitor.instance;
      await monitor.initialize();
    });

    tearDown(() async {
      await monitor.dispose();
    });

    test('initializes with a network state', () {
      expect(monitor.currentState, isNotNull);
      expect(monitor.currentState, isIn([NetworkState.online, NetworkState.offline, NetworkState.reconnecting]));
    });

    test('provides stream of state changes', () {
      expect(monitor.stateChanges, isNotNull);
      expect(monitor.stateChanges, isA<Stream<NetworkState>>());
    });

    test('isOnline returns boolean', () async {
      final online = await monitor.isOnline();
      expect(online, isA<bool>());
    });

    test('getNetworkType returns network type', () async {
      final networkType = await monitor.getNetworkType();
      expect(networkType, isNotNull);
      expect(networkType, isA<NetworkType>());
    });

    test('state change events are emitted', () async {
      final stateChanges = <NetworkState>[];

      // Listen to state changes
      final subscription = monitor.stateChanges.listen((state) {
        stateChanges.add(state);
        print('State change event emitted: ${state.name}');
      });

      // Wait a bit to allow state changes
      await Future.delayed(const Duration(seconds: 2));

      await subscription.cancel();

      // Verify we can detect states
      expect(monitor.currentState, isIn([NetworkState.online, NetworkState.offline]));
    }, skip: 'Requires real network state changes');
  });

  group('NetworkState', () {
    test('has correct enum values', () {
      expect(NetworkState.values.length, 3);
      expect(NetworkState.values, contains(NetworkState.online));
      expect(NetworkState.values, contains(NetworkState.offline));
      expect(NetworkState.values, contains(NetworkState.reconnecting));
    });
  });

  group('NetworkStateChange', () {
    test('creates state change object', () {
      final change = NetworkStateChange(
        previousState: NetworkState.offline,
        currentState: NetworkState.online,
        timestamp: DateTime.now(),
      );

      expect(change.previousState, NetworkState.offline);
      expect(change.currentState, NetworkState.online);
      expect(change.timestamp, isNotNull);
    });

    test('serializes to JSON', () {
      final change = NetworkStateChange(
        previousState: NetworkState.offline,
        currentState: NetworkState.online,
        timestamp: DateTime.now(),
      );

      final json = change.toJson();

      expect(json['previousState'], 'offline');
      expect(json['currentState'], 'online');
      expect(json['timestamp'], isNotNull);
    });
  });
}
