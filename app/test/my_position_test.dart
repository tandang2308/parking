import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/config/tile_config.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/consent/consent_screen.dart';
import 'package:parkfinder/features/location/location_controller.dart';
import 'package:parkfinder/features/location/location_service.dart';
import 'package:parkfinder/main.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.1 widget tests (TC-1.1.2–1.1.16, 1.1.19 partial,
/// 1.1.24, 1.1.25, 1.1.26–1.1.31 automated parts).

Future<vt.Style> _pendingStyle(String _) => Completer<vt.Style>().future;

const _dot = ValueKey('user-location-dot');
const _fab = ValueKey('fab-my-location');
const _needed = ValueKey('banner-location-needed');
const _enable = ValueKey('banner-enable');
const _off = ValueKey('banner-location-off');
const _turnOn = ValueKey('banner-turn-on');
const _noFix = ValueKey('banner-no-fix');
const _adjust = ValueKey('banner-adjust');
const _outOfArea = ValueKey('banner-out-of-area');
const _goVungTau = ValueKey('banner-go-vung-tau');
const _dismiss = ValueKey('banner-dismiss');
const _locating = ValueKey('hint-locating');
const _guide = ValueKey('web-unblock-guide');

/// SPEC-001 §6 texts (exact).
const _en = (
  needed: 'Turn on location to see lots near you',
  enable: 'Enable',
  off: 'Location is off',
  turnOn: 'Turn on',
  noFix: "Can't get your location — adjust manually?",
  adjust: 'Adjust',
  locating: 'Locating…',
  outOfArea: 'ParkFinder currently covers Vũng Tàu only',
  goVungTau: 'Go to Vũng Tàu',
  guideTitle: 'Location is blocked',
  guide: "Location is blocked for this site. Open your browser's site "
      'settings, allow Location, then reload the page.',
  ok: 'OK',
  dismiss: 'Dismiss',
  myLocation: 'My location',
);
const _vi = (
  needed: 'Bật định vị để xem bãi xe gần bạn',
  enable: 'Bật',
  off: 'Định vị đang tắt',
  turnOn: 'Bật định vị',
  noFix: 'Không lấy được vị trí của bạn — chỉnh thủ công?',
  adjust: 'Chỉnh vị trí',
  locating: 'Đang định vị…',
  outOfArea: 'Hiện ParkFinder chỉ hỗ trợ Vũng Tàu',
  goVungTau: 'Đến Vũng Tàu',
  guideTitle: 'Vị trí đang bị chặn',
  guide: 'Trang này đang bị chặn truy cập vị trí. Hãy mở cài đặt trang web '
      'của trình duyệt, cho phép Vị trí, rồi tải lại trang.',
  ok: 'OK',
  dismiss: 'Đóng',
  myLocation: 'Vị trí của tôi',
);

final _searches = <({LatLng point, SearchTrigger trigger})>[];

/// Launches the app with [consent] stored (null = first launch).
Future<void> _launch(
  WidgetTester tester,
  FakeLocationService service, {
  ConsentResult? consent = ConsentResult.granted,
  FakeConsentStore? store,
}) async {
  _searches.clear();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ParkFinderApp(
      tileConfig: const TileConfig(),
      styleLoader: _pendingStyle,
      consentStore:
          store ?? FakeConsentStore(consent == null ? null : consentRecord(consent)),
      locationService: service,
      lotsRepository: FakeLotsRepository(),
      clock: () => testNow,
      onSearchCentreChanged: (point, trigger) =>
          _searches.add((point: point, trigger: trigger)),
    ),
  );
  await _settle(tester);
}

/// Lets futures, streams and the 400 ms camera animation complete.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _emit(
  WidgetTester tester,
  FakeLocationService service,
  LocationFix fix,
) async {
  service.emit(fix);
  await _settle(tester);
}

MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

void _expectCamera(WidgetTester tester, LatLng centre, double zoom) {
  final camera = _camera(tester);
  expect(camera.center.latitude, closeTo(centre.latitude, 1e-6));
  expect(camera.center.longitude, closeTo(centre.longitude, 1e-6));
  expect(camera.zoom, closeTo(zoom, 1e-6));
}

/// Walks valid lifecycle transitions: resumed ↔ inactive ↔ hidden.
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  final current = tester.binding.lifecycleState;
  final steps = switch ((current, state)) {
    (AppLifecycleState.resumed, AppLifecycleState.hidden) => [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ],
    (AppLifecycleState.hidden, AppLifecycleState.resumed) => [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ],
    _ => [state],
  };
  for (final step in steps) {
    tester.binding.handleAppLifecycleStateChanged(step);
  }
  await _settle(tester);
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void main() {
  setUp(() => _searches.clear());

  testWidgets('AC2 / TC-1.1.2: blue dot + accuracy circle, zoom 16, follow '
      'on (camera follows without tapping)', (tester) async {
    final service = FakeLocationService();
    await _launch(tester, service, consent: null);
    await tester.tap(find.byKey(const ValueKey('consent-allow')));
    await _settle(tester);
    expect(service.requestCalls, 1);

    await _emit(tester, service, fixAt(10.3460, 107.0740, accuracy: 20));

    expect(find.byKey(_dot), findsOneWidget);
    final circle = tester
        .widget<CircleLayer>(find.byKey(const ValueKey('user-accuracy-circle')))
        .circles
        .single;
    expect(circle.radius, 20);
    expect(circle.useRadiusInMeter, isTrue);
    _expectCamera(tester, const LatLng(10.3460, 107.0740), 16);
    expect(_searches.single.trigger, SearchTrigger.firstPosition);
    expect(find.byKey(_needed), findsNothing);

    // Moves 50 m north: camera follows.
    final moved = const Distance().offset(const LatLng(10.3460, 107.0740), 50, 0);
    await _emit(tester, service, fixAt(moved.latitude, moved.longitude));
    _expectCamera(tester, moved, 16);
  });

  testWidgets('AC3 / TC-1.1.3: declined → default centre, banner, no '
      'location call; Enable reopens S1', (tester) async {
    final service = FakeLocationService();
    await _launch(tester, service, consent: ConsentResult.declined);
    await tester.pump(const Duration(seconds: 15));

    expect(service.totalCalls, 0);
    _expectCamera(tester, const LatLng(10.3460, 107.0740), 15);
    expect(find.byKey(_needed), findsOneWidget);
    expect(find.byKey(_dot), findsNothing);
    expect(_searches.single.point, const LatLng(10.3460, 107.0740));

    await tester.tap(find.byKey(_fab)); // My location → same as Enable
    await _settle(tester);
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(service.totalCalls, 0);
  });

  testWidgets('AC4 / TC-1.1.4: denied once → banner; Enable re-requests and '
      'granting shows the dot', (tester) async {
    final service = FakeLocationService(
      requestResult: LocationPermissionStatus.denied,
    );
    await _launch(tester, service, consent: null);
    await tester.tap(find.byKey(const ValueKey('consent-allow')));
    await _settle(tester);
    expect(find.byKey(_needed), findsOneWidget);
    _expectCamera(tester, const LatLng(10.3460, 107.0740), 15);

    service.requestResult = LocationPermissionStatus.granted;
    await tester.tap(find.byKey(_enable));
    await _settle(tester);
    expect(service.requestCalls, 2);
    expect(find.byType(ConsentScreen), findsNothing);

    await _emit(tester, service, MockPoints.mp1);
    expect(find.byKey(_dot), findsOneWidget);
    expect(find.byKey(_needed), findsNothing);
  });

  testWidgets('AC5 / TC-1.1.5 Android: Enable opens app settings; dot '
      'appears on return without restart', (tester) async {
    final service = FakeLocationService(
      checkResult: LocationPermissionStatus.deniedForever,
    );
    await _launch(tester, service);
    expect(find.byKey(_needed), findsOneWidget);

    await tester.tap(find.byKey(_enable));
    await _settle(tester);
    expect(service.openAppSettingsCalls, 1);
    expect(find.byKey(_guide), findsNothing);

    await _lifecycle(tester, AppLifecycleState.hidden);
    service.checkResult = LocationPermissionStatus.granted;
    await _lifecycle(tester, AppLifecycleState.resumed);
    await _emit(tester, service, MockPoints.mp1);

    expect(find.byKey(_dot), findsOneWidget);
    expect(find.byKey(_needed), findsNothing);
  });

  testWidgets('AC5 / TC-1.1.31 Web: Enable → PERMISSION_DENIED → unblock '
      'guide; OK closes it', (tester) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService(
      isWeb: true,
      checkResult: LocationPermissionStatus.unknown,
      requestResult: LocationPermissionStatus.deniedForever,
    );
    await _launch(tester, service);
    service.emitError(const LocationPermissionDeniedError());
    await _settle(tester);
    expect(find.byKey(_needed), findsOneWidget);

    await tester.tap(find.byKey(_enable));
    await _settle(tester);
    expect(service.requestCalls, 1);
    expect(find.byKey(_guide), findsOneWidget);
    expect(find.text(_en.guideTitle), findsOneWidget);
    expect(find.text(_en.guide), findsOneWidget);

    await tester.tap(find.text(_en.ok));
    await _settle(tester);
    expect(find.byKey(_guide), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 / TC-1.1.6: GPS off → banner + Turn on; fix right after '
      'returning to the foreground', (tester) async {
    final service = FakeLocationService(serviceEnabled: false);
    await _launch(tester, service);
    expect(find.byKey(_off), findsOneWidget);

    await tester.tap(find.byKey(_turnOn));
    await _settle(tester);
    expect(service.openLocationSettingsCalls, 1);

    await _lifecycle(tester, AppLifecycleState.hidden);
    service.serviceEnabled = true;
    await _lifecycle(tester, AppLifecycleState.resumed);
    // Stream already running on return (fix depends only on the device).
    expect(service.isStreaming, isTrue);
    await _emit(tester, service, MockPoints.mp1);

    expect(find.byKey(_dot), findsOneWidget);
    expect(find.byKey(_off), findsNothing);
  });

  testWidgets('AC7 / AC8 / TC-1.1.7: pan turns follow off; My location '
      'recenters at zoom 16 and fires a new search', (tester) async {
    final service = FakeLocationService();
    await _launch(tester, service);
    await _emit(tester, service, MockPoints.mp1);
    expect(_searches, hasLength(1));

    await tester.drag(find.byType(FlutterMap), const Offset(-200, 0));
    await _settle(tester);
    final panned = _camera(tester).center;

    await _emit(tester, service, MockPoints.mp4);
    expect(_camera(tester).center, panned); // no follow
    expect(_searches, hasLength(1)); // moving never reloads

    await tester.tap(find.byKey(_fab));
    await _settle(tester);
    _expectCamera(tester, MockPoints.mp4.position, 16);
    expect(_searches.last.trigger, SearchTrigger.myLocation);
    expect(_searches.last.point, MockPoints.mp4.position);

    // Follow on again.
    final next = const Distance().offset(MockPoints.mp4.position, 40, 90);
    await _emit(tester, service, fixAt(next.latitude, next.longitude));
    _expectCamera(tester, next, 16);
  });

  testWidgets('AC9 / TC-1.1.8: no fix in 10 s → default centre + no-fix '
      'banner with Adjust (US-1.3 AC2)', (tester) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService();
    await _launch(tester, service);

    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(_noFix), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    expect(find.byKey(_noFix), findsOneWidget);
    expect(find.text(_en.noFix), findsOneWidget);
    expect(find.text(_en.adjust), findsOneWidget);
    _expectCamera(tester, const LatLng(10.3460, 107.0740), 15);
    expect(_searches.single.point, const LatLng(10.3460, 107.0740));

    // US-1.3 AC2: "Adjust" starts adjust mode; Cancel leaves it unchanged.
    await tester.tap(find.byKey(_adjust));
    await _settle(tester);
    expect(find.byKey(const ValueKey('hint-adjust')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('btn-adjust-cancel')));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // AC12 / TC-1.1.26: late fix on an untouched map = first fix.
    await _emit(tester, service, MockPoints.mp4);
    _expectCamera(tester, MockPoints.mp4.position, 16);
    expect(find.byKey(_noFix), findsNothing);
    expect(_searches, hasLength(2));
  });

  testWidgets('AC12 / TC-1.1.27: late fix after a pan → dot only',
      (tester) async {
    final service = FakeLocationService();
    await _launch(tester, service);
    await tester.pump(const Duration(seconds: 10));
    await _settle(tester);
    await tester.drag(find.byType(FlutterMap), const Offset(0, 150));
    await _settle(tester);
    final panned = _camera(tester).center;

    await _emit(tester, service, MockPoints.mp4);

    expect(find.byKey(_dot), findsOneWidget);
    expect(_camera(tester).center, panned);
    expect(_searches, hasLength(1));
  });

  testWidgets('AC9 / TC-1.1.11: last-known < 5 min (Android) → dot + '
      '"Locating…", no banner', (tester) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService(
      lastKnown: fixAt(10.3500, 107.0820,
          at: testNow.subtract(const Duration(minutes: 2))),
    );
    await _launch(tester, service);
    await tester.pump(const Duration(seconds: 10));
    await _settle(tester);

    expect(find.byKey(_dot), findsOneWidget);
    expect(find.byKey(_locating), findsOneWidget);
    expect(find.text(_en.locating), findsOneWidget);
    expect(find.byKey(_noFix), findsNothing);
    _expectCamera(tester, const LatLng(10.3500, 107.0820), 16);

    await _emit(tester, service, MockPoints.mp4);
    expect(find.byKey(_locating), findsNothing);
  });

  testWidgets('AC10 / TC-1.1.9 / TC-1.1.30: outside area → dot at fix, '
      'banner, Go to Vũng Tàu, × hides it for the session', (tester) async {
    final service = FakeLocationService();
    await _launch(tester, service);
    await _emit(tester, service, MockPoints.mp6);

    expect(find.byKey(_dot), findsOneWidget);
    _expectCamera(tester, MockPoints.mp6.position, 16);
    expect(_searches.single.point, const LatLng(10.3460, 107.0740));
    expect(find.byKey(_outOfArea), findsOneWidget);

    await tester.tap(find.byKey(_goVungTau));
    await _settle(tester);
    _expectCamera(tester, const LatLng(10.3460, 107.0740), 15);

    final moved = const Distance().offset(MockPoints.mp6.position, 50, 0);
    await _emit(tester, service, fixAt(moved.latitude, moved.longitude));
    _expectCamera(tester, const LatLng(10.3460, 107.0740), 15); // no jump

    await tester.tap(find.byKey(_dismiss));
    await _settle(tester);
    expect(find.byKey(_outOfArea), findsNothing);

    await tester.tap(find.byKey(_fab));
    await _settle(tester);
    expect(find.byKey(_outOfArea), findsNothing);
  });

  testWidgets('AC11 / TC-1.1.16: no Geolocation API → AC3 behaviour, no '
      'error', (tester) async {
    final service = FakeLocationService(
      isWeb: true,
      requestResult: LocationPermissionStatus.unavailable,
    );
    await _launch(tester, service, consent: null);
    await tester.tap(find.byKey(const ValueKey('consent-allow')));
    await _settle(tester);
    expect(find.byKey(_needed), findsOneWidget);
    await tester.tap(find.byKey(_enable));
    await _settle(tester);
    expect(find.byKey(_guide), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NFR-5 / TC-1.1.20: stream stops in background, resumes',
      (tester) async {
    final service = FakeLocationService();
    await _launch(tester, service);
    await _emit(tester, service, MockPoints.mp1);
    expect(service.isStreaming, isTrue);

    await _lifecycle(tester, AppLifecycleState.inactive);
    expect(service.isStreaming, isTrue); // e.g. permission dialog / shade
    await _lifecycle(tester, AppLifecycleState.hidden);
    expect(service.isStreaming, isFalse);
    await _lifecycle(tester, AppLifecycleState.resumed);
    expect(service.isStreaming, isTrue);
    expect(find.byKey(_dot), findsOneWidget);
  });

  group('§6 strings, NFR-8 (TC-1.1.24, TC-1.1.25)', () {
    for (final (locale, s) in [
      (const Locale('en'), _en),
      (const Locale('vi'), _vi),
    ]) {
      testWidgets('banners in ${locale.languageCode} match §6, no overflow '
          'at 320 px, labels and 48 dp targets', (tester) async {
        _setLocale(tester, locale);
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();

        // location off
        var service = FakeLocationService(serviceEnabled: false);
        await _launch(tester, service);
        expect(find.text(s.off), findsOneWidget);
        expect(find.text(s.turnOn), findsOneWidget);

        // location needed
        service = FakeLocationService(
          checkResult: LocationPermissionStatus.denied,
        );
        await _launch(tester, service);
        expect(find.text(s.needed), findsOneWidget);
        expect(find.text(s.enable), findsOneWidget);

        // no fix
        service = FakeLocationService();
        await _launch(tester, service);
        await tester.pump(const Duration(seconds: 10));
        await _settle(tester);
        expect(find.text(s.noFix), findsOneWidget);
        expect(find.text(s.adjust), findsOneWidget);

        // out of area (new app instance = new session)
        service = FakeLocationService();
        await _launch(tester, service);
        await _emit(tester, service, MockPoints.mp6);
        expect(find.text(s.outOfArea), findsOneWidget);
        expect(find.text(s.goVungTau), findsOneWidget);
        expect(tester.takeException(), isNull);

        expect(
          tester.getSemantics(find.byKey(_dismiss)),
          containsSemantics(tooltip: s.dismiss, isButton: true),
        );
        expect(
          tester.getSemantics(find.byKey(_fab)),
          containsSemantics(tooltip: s.myLocation, isButton: true),
        );
        for (final key in [_dismiss, _goVungTau, _fab]) {
          final rect = tester.getRect(find.byKey(key));
          expect(rect.height, greaterThanOrEqualTo(48), reason: '$key');
          expect(rect.width, greaterThanOrEqualTo(48), reason: '$key');
          expect(rect.right, lessThanOrEqualTo(320), reason: '$key');
        }

        // Web unblock guide
        service = FakeLocationService(
          isWeb: true,
          checkResult: LocationPermissionStatus.deniedForever,
          requestResult: LocationPermissionStatus.deniedForever,
        );
        await _launch(tester, service);
        await tester.tap(find.byKey(_enable));
        await _settle(tester);
        expect(find.text(s.guideTitle), findsOneWidget);
        expect(find.text(s.guide), findsOneWidget);
        expect(find.text(s.ok), findsOneWidget);
        expect(tester.takeException(), isNull);

        semantics.dispose();
      });
    }

    testWidgets('last-known hint in vi', (tester) async {
      _setLocale(tester, const Locale('vi'));
      final service = FakeLocationService(
        lastKnown: fixAt(10.35, 107.08,
            at: testNow.subtract(const Duration(minutes: 1))),
      );
      await _launch(tester, service);
      await tester.pump(const Duration(seconds: 10));
      await _settle(tester);
      expect(find.text(_vi.locating), findsOneWidget);
    });
  });
}
