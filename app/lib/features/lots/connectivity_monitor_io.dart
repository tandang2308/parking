import 'dart:async';

import 'package:flutter/services.dart';

import 'connectivity_monitor.dart';

/// Android: the app's own `EventChannel` (MainActivity.kt) backed by
/// `ConnectivityManager.registerDefaultNetworkCallback`. It emits one event
/// when a network becomes available after none (SPEC-001 §3, US-1.2 AC5).
ConnectivityMonitor createPlatformConnectivityMonitor() =>
    ChannelConnectivityMonitor();

class ChannelConnectivityMonitor implements ConnectivityMonitor {
  ChannelConnectivityMonitor({EventChannel channel = defaultChannel}) {
    _sub = channel.receiveBroadcastStream().listen(
          (_) => _controller.add(null),
          // No native side (e.g. a desktop dev run) or a platform error: no
          // auto retry, manual Retry still works.
          onError: (Object _) {},
          cancelOnError: false,
        );
  }

  /// Name shared with `MainActivity.kt`.
  static const EventChannel defaultChannel =
      EventChannel('vn.parkfinder/connectivity');

  final StreamController<void> _controller = StreamController<void>.broadcast();
  StreamSubscription<dynamic>? _sub;

  @override
  Stream<void> get onReconnected => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
