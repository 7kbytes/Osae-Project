import 'dart:async';

/// Service for monitoring and dispatching network connectivity state.
/// Supports simulation and stream subscriptions for offline/online transitions.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  static ConnectivityService get instance => _instance;

  ConnectivityService._internal() {
    _controller = StreamController<bool>.broadcast();
  }

  late final StreamController<bool> _controller;
  bool _isOnline = true;

  /// Whether device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Stream of connectivity state changes (true = online, false = offline).
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Updates the current connectivity status and broadcasts to all listeners.
  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(_isOnline);
    }
  }

  /// Toggles between online and offline status.
  void toggleConnectivity() {
    setOnline(!_isOnline);
  }

  /// Checks current connectivity (asynchronous check compatible with network plugins).
  Future<bool> checkConnectivity() async {
    return _isOnline;
  }

  /// Disposes stream controller when no longer required.
  void dispose() {
    _controller.close();
  }
}
