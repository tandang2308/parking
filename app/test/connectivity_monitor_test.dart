import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkfinder/features/lots/connectivity_monitor_io.dart';

/// SPEC-001 US-1.2 AC5 (Android): the app's own EventChannel
/// `vn.parkfinder/connectivity` (MainActivity.kt) → onReconnected.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = ChannelConnectivityMonitor.defaultChannel;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null);
  });

  test('each native "network back" event → one onReconnected', () async {
    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (_, events) => sink = events),
    );
    final monitor = ChannelConnectivityMonitor();
    var count = 0;
    final sub = monitor.onReconnected.listen((_) => count++);
    await Future<void>.delayed(Duration.zero);
    expect(sink, isNotNull);

    sink!.success(null);
    await Future<void>.delayed(Duration.zero);
    expect(count, 1);
    sink!.success(null);
    await Future<void>.delayed(Duration.zero);
    expect(count, 2);

    await sub.cancel();
    monitor.dispose();
  });

  test('a platform error does not crash and emits nothing', () async {
    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (_, events) => sink = events),
    );
    final monitor = ChannelConnectivityMonitor();
    var count = 0;
    final sub = monitor.onReconnected.listen((_) => count++);
    await Future<void>.delayed(Duration.zero);
    sink!.error(code: 'UNAVAILABLE');
    await Future<void>.delayed(Duration.zero);
    expect(count, 0);
    await sub.cancel();
    monitor.dispose();
  });

  test('no native side (e.g. desktop dev run) → no crash', () async {
    final monitor = ChannelConnectivityMonitor(
      channel: const EventChannel('vn.parkfinder/does-not-exist'),
    );
    final sub = monitor.onReconnected.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    monitor.dispose();
  });
}
