import 'dart:async';

export 'connectivity_monitor_io.dart'
    if (dart.library.js_interop) 'connectivity_monitor_web.dart'
    show createPlatformConnectivityMonitor;

/// Reports connectivity changes from offline to online (SPEC-001 US-1.2 AC5,
/// §3 "Connectivity (auto retry)").
abstract interface class ConnectivityMonitor {
  /// Emits once per offline → online change.
  Stream<void> get onReconnected;

  void dispose();
}
