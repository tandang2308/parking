import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_monitor.dart';

/// Android: a connectivity change event (`connectivity_plus`, BSD-3) from
/// "none" to any network (SPEC-001 §3, US-1.2 AC5).
ConnectivityMonitor createPlatformConnectivityMonitor() =>
    _ConnectivityPlusMonitor(Connectivity());

class _ConnectivityPlusMonitor implements ConnectivityMonitor {
  _ConnectivityPlusMonitor(this._connectivity) {
    _sub = _connectivity.onConnectivityChanged.listen(
      _onChanged,
      onError: (Object _) {},
    );
    _connectivity.checkConnectivity().then(
      (r) => _online ??= _isOnline(r),
      onError: (Object _) => null,
    );
  }

  final Connectivity _connectivity;
  final StreamController<void> _controller = StreamController<void>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// `null` until the first state is known.
  bool? _online;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void _onChanged(List<ConnectivityResult> results) {
    final online = _isOnline(results);
    if (_online == false && online) _controller.add(null);
    _online = online;
  }

  @override
  Stream<void> get onReconnected => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
