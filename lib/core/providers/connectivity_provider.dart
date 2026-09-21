import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

/// Provider managing network connectivity state and broadcasting changes to UI widgets.
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;
  bool _isOnline;

  ConnectivityProvider({
    ConnectivityService? service,
    bool initialOnline = true,
  }) : _service = service ?? ConnectivityService.instance,
       _isOnline = initialOnline {
    _subscription = _service.onConnectivityChanged.listen((status) {
      if (_isOnline != status) {
        _isOnline = status;
        notifyListeners();
      }
    });
  }

  /// True if device currently has active network connectivity.
  bool get isOnline => _isOnline;

  /// Update online status manually (useful for tests and user simulation).
  void setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _service.setOnline(value);
      notifyListeners();
    }
  }

  /// Toggle connectivity state between online and offline.
  void toggleOnline() {
    setOnline(!_isOnline);
  }

  /// Force a refresh of the connectivity state.
  Future<void> checkConnectivity() async {
    final status = await _service.checkConnectivity();
    if (_isOnline != status) {
      _isOnline = status;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
