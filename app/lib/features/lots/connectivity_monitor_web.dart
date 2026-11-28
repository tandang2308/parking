import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'connectivity_monitor.dart';

/// Web: the browser `online` event only (SPEC-001 §3, US-1.2 AC5).
ConnectivityMonitor createPlatformConnectivityMonitor() =>
    _BrowserOnlineMonitor();

class _BrowserOnlineMonitor implements ConnectivityMonitor {
  _BrowserOnlineMonitor() {
    web.window.addEventListener('online', _listener);
  }

  final StreamController<void> _controller = StreamController<void>.broadcast();
  late final JSFunction _listener =
      ((web.Event _) => _controller.add(null)).toJS;

  @override
  Stream<void> get onReconnected => _controller.stream;

  @override
  void dispose() {
    web.window.removeEventListener('online', _listener);
    _controller.close();
  }
}
