import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device appears to have a network connection.
/// "Online" only means an interface is up; the engine still treats real
/// write failures as authoritative and retries with backoff.
abstract class ConnectivityMonitor {
  Future<bool> get isOnline;
  Stream<bool> get onChanged;
}

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isOnline async {
    try {
      return _hasConnection(await _connectivity.checkConnectivity());
    } catch (_) {
      return true; // Unknown: let real write failures decide.
    }
  }

  @override
  Stream<bool> get onChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();
}

/// Test double with manual control.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool online = true}) {
    _online = online;
  }

  late bool _online;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onChanged => _controller.stream;
}
