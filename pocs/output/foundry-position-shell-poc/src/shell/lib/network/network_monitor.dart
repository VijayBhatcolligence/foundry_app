// Phase 3: Network Monitor Service
// Purpose: Detects network connectivity changes and exposes current network state

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'network_state.dart';

class NetworkMonitor {
  static final NetworkMonitor instance = NetworkMonitor._internal();
  factory NetworkMonitor() => instance;
  NetworkMonitor._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkState> _stateController = StreamController<NetworkState>.broadcast();

  NetworkState _currentState = NetworkState.offline;
  NetworkType _currentType = NetworkType.none;

  StreamSubscription? _connectivitySubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastStateChangeTime;

  // Debounce settings: minimum 500ms between emitted events
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  NetworkState get currentState => _currentState;
  Stream<NetworkState> get stateChanges => _stateController.stream;

  Future<void> initialize() async {
    // Check initial state
    await _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _handleConnectivityChange(result);
    });

    // Start heartbeat when online (30 second intervals)
    _startHeartbeat();
  }

  Future<bool> isOnline() async {
    return _currentState == NetworkState.online;
  }

  Future<NetworkType> getNetworkType() async {
    return _currentType;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
    await _stateController.close();
  }

  // Private: Check connectivity and update state
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(result);
    } catch (e) {
      print('[NetworkMonitor] Error checking connectivity: $e');
    }
  }

  // Private: Handle connectivity change from connectivity_plus
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    // Map connectivity result to network type
    NetworkType newType;
    switch (result) {
      case ConnectivityResult.wifi:
        newType = NetworkType.wifi;
        break;
      case ConnectivityResult.mobile:
        newType = NetworkType.cellular;
        break;
      case ConnectivityResult.ethernet:
        newType = NetworkType.ethernet;
        break;
      case ConnectivityResult.vpn:
        newType = NetworkType.vpn;
        break;
      case ConnectivityResult.none:
      default:
        newType = NetworkType.none;
        break;
    }

    _currentType = newType;

    // Connectivity package may report online but internet is unreachable
    // Ping 1.1.1.1 to verify actual internet connectivity
    NetworkState newState;
    if (newType == NetworkType.none) {
      newState = NetworkState.offline;
    } else {
      // Verify internet reachability
      final hasInternet = await _pingInternetGateway();
      if (hasInternet) {
        // If transitioning from offline to online, mark as reconnecting briefly
        if (_currentState == NetworkState.offline) {
          newState = NetworkState.reconnecting;
          // Schedule transition to online after brief reconnecting state
          Future.delayed(const Duration(milliseconds: 500), () {
            _updateState(NetworkState.online);
          });
        } else {
          newState = NetworkState.online;
        }
      } else {
        newState = NetworkState.offline;
      }
    }

    await _updateState(newState);
  }

  // Private: Update state with debouncing
  Future<void> _updateState(NetworkState newState) async {
    if (_currentState == newState) return;

    // Debounce: check if enough time has passed since last state change
    final now = DateTime.now();
    if (_lastStateChangeTime != null) {
      final timeSinceLastChange = now.difference(_lastStateChangeTime!);
      if (timeSinceLastChange < _debounceDuration) {
        // Too soon, skip this change
        return;
      }
    }

    final previousState = _currentState;
    _currentState = newState;
    _lastStateChangeTime = now;

    print('[NetworkMonitor] State changed: ${previousState.name} → ${newState.name}');

    // Emit state change event
    _stateController.add(newState);

    // Restart heartbeat based on new state
    if (newState == NetworkState.online) {
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }
  }

  // Private: Ping internet gateway to verify connectivity
  Future<bool> _pingInternetGateway() async {
    try {
      // Try to reach Cloudflare DNS (1.1.1.1) with 5 second timeout
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // Lookup failed, no internet
      return false;
    }
  }

  // Private: Start heartbeat timer (30 second intervals)
  void _startHeartbeat() {
    _stopHeartbeat(); // Cancel existing timer if any

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentState == NetworkState.online) {
        // Verify we're still online
        final hasInternet = await _pingInternetGateway();
        if (!hasInternet) {
          await _updateState(NetworkState.offline);
        }
      }
    });
  }

  // Private: Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
