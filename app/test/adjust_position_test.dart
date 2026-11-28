import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/config/tile_config.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/location/location_controller.dart';
import 'package:parkfinder/features/location/location_service.dart';
import 'package:parkfinder/features/lots/lots_geo.dart';
import 'package:parkfinder/features/map/map_constants.dart';
import 'package:parkfinder/l10n/generated/app_localizations.dart';
import 'package:parkfinder/main.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.3 widget tests (TC-1.3.1–1.3.18 automated parts): low-
/// accuracy banner (AC1), adjust mode entries (AC2), confirm (AC3), GPS
/// ignored / back to GPS (AC4), cancel (AC5), no GPS needed (AC6), memory
/// only (AC7), outside area (AC8), §6 strings vi/en, NFR-8.

Future<vt.Style> _pendingStyle(String _, String _) => Completer<vt.Style>().future;

const _fab = ValueKey('fab-my-location');
const _dot = ValueKey('user-location-dot');
const _lowAccuracy = ValueKey('banner-low-accuracy');
const _adjust = ValueKey('banner-adjust');
const _dismiss = ValueKey('banner-dismiss');
const _noFix = ValueKey('banner-no-fix');
const _outOfArea = ValueKey('banner-out-of-area');
const _hint = ValueKey('hint-adjust');
const _crosshair = ValueKey('adjust-crosshair');
const _confirm = ValueKey('btn-adjust-confirm');
const _cancel = ValueKey('btn-adjust-cancel');
const _menu = ValueKey('map-menu');
const _menuSetPosition = ValueKey('menu-set-position');
const _manualMarker = ValueKey('manual-position-marker');
const _toast = ValueKey('toast-using-gps');

/// SPEC-001 §6 texts (exact).
const _en = (
  lowAccuracy: 'Your location may be inaccurate',
  adjust: 'Adjust',
  confirm: 'Confirm',
  cancel: 'Cancel',
  setPosition: 'Set my position',
  hint: 'Move the map to your exact position',
  usingGps: 'Using GPS location',
  manualMarker: 'Your position (set manually)',
);
const _vi = (
  lowAccuracy: 'Vị trí có thể chưa chính xác',
  adjust: 'Chỉnh vị trí',
  confirm: 'Xác nhận',
  cancel: 'Hủy',
  setPosition: 'Đặt vị trí của tôi',
  hint: 'Di chuyển bản đồ đến đúng vị trí của bạn',
  usingGps: 'Đang dùng vị trí GPS',
  manualMarker: 'Vị trí của bạn (đặt thủ công)',
);

final _searches = <({LatLng point, SearchTrigger trigger})>[];

Future<void> _launch(
  WidgetTester tester, {
  required FakeLotsRepository repo,
  FakeLocationService? service,
  ConsentResult consent = ConsentResult.granted,
  FakeConsentStore? store,
}) async {
  _searches.clear();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ParkFinderApp(
      tileConfig: const TileConfig(),
      styleLoader: _pendingStyle,
      consentStore: store ?? FakeConsentStore(consentRecord(consent)),
      locationService: service ?? FakeLocationService(),
      lotsRepository: repo,
      clock: () => testNow,
      onSearchCentreChanged: (point, trigger) =>
          _searches.add((point: point, trigger: trigger)),
    ),
  );
  await _settle(tester);
}

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

void _expectNear(LatLng actual, LatLng expected, {double tol = 1e-6}) {
  expect(actual.latitude, closeTo(expected.latitude, tol));
  expect(actual.longitude, closeTo(expected.longitude, tol));
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void _expectAdjustMode(WidgetTester tester, {required bool on}) {
  final m = on ? findsOneWidget : findsNothing;
  expect(find.byKey(_crosshair), m);
  expect(find.byKey(_hint), m);
  expect(find.byKey(_confirm), m);
  expect(find.byKey(_cancel), m);
  // The FAB comes back when adjust mode ends.
  expect(find.byKey(_fab), on ? findsNothing : findsOneWidget);
}

Future<void> _openMenuSetPosition(WidgetTester tester) async {
  await tester.tap(find.byKey(_menu));
  await _settle(tester);
  await tester.tap(find.byKey(_menuSetPosition));
  await _settle(tester);
}

/// Drags the map and returns the new camera centre (= crosshair point).
Future<LatLng> _drag(WidgetTester tester, Offset by) async {
  await tester.drag(find.byType(FlutterMap), by);
  await _settle(tester);
  return _camera(tester).center;
}

void main() {
  testWidgets('AC1 / TC-1.3.1 / TC-1.3.14: low accuracy → banner + Adjust '
      '+ ×; closed → not again on new low-accuracy fixes', (tester) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService();
    await _launch(tester, repo: FakeLotsRepository(), service: service);
    await _emit(tester, service, MockPoints.mp3LowAccuracy);

    expect(find.byKey(_lowAccuracy), findsOneWidget);
    expect(find.text(_en.lowAccuracy), findsOneWidget);
    expect(find.text(_en.adjust), findsOneWidget);
    expect(find.byKey(_dismiss), findsOneWidget);

    await tester.tap(find.byKey(_dismiss));
    await _settle(tester);
    expect(find.byKey(_lowAccuracy), findsNothing);

    await _emit(tester, service, fixAt(10.3460, 107.0740, accuracy: 20));
    await _emit(tester, service, fixAt(10.3265, 107.0845, accuracy: 150));
    expect(find.byKey(_lowAccuracy), findsNothing);
  });

  testWidgets('AC1 / TC-1.3.8: accuracy 100 m → no banner; 101 m → banner', (
    tester,
  ) async {
    var service = FakeLocationService();
    await _launch(tester, repo: FakeLotsRepository(), service: service);
    await _emit(tester, service, fixAt(10.3460, 107.0740, accuracy: 100));
    expect(find.byKey(_lowAccuracy), findsNothing);

    service = FakeLocationService();
    await _launch(tester, repo: FakeLotsRepository(), service: service);
    await _emit(tester, service, fixAt(10.3460, 107.0740, accuracy: 101));
    expect(find.byKey(_lowAccuracy), findsOneWidget);
  });

  testWidgets('AC2 / AC3 / TC-1.3.2 / TC-1.3.10: Adjust → crosshair, hint, '
      'Confirm/Cancel; move + Confirm → manual marker, one 1 km request '
      'around it, card distance from it', (tester) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService();
    final repo = FakeLotsRepository();
    await _launch(tester, repo: repo, service: service);
    await _emit(tester, service, MockPoints.mp3LowAccuracy);
    final callsBefore = repo.calls.length;

    await tester.tap(find.byKey(_adjust));
    await _settle(tester);
    _expectAdjustMode(tester, on: true);
    expect(find.text(_en.hint), findsOneWidget);
    expect(find.text(_en.confirm), findsOneWidget);
    expect(find.text(_en.cancel), findsOneWidget);
    // The crosshair is fixed at the map centre.
    expect(
      tester.getCenter(find.byKey(_crosshair)),
      tester.getCenter(find.byType(FlutterMap)),
    );
    expect(repo.calls.length, callsBefore); // entering sends nothing

    final target = await _drag(tester, const Offset(-120, 80));
    // GPS keeps arriving: no camera jump in adjust mode.
    await _emit(tester, service, fixAt(10.3270, 107.0850, accuracy: 150));
    _expectNear(_camera(tester).center, target);

    // A lot ~ 200 m north of the manual position (returned by the request).
    final lot = lotAt('n', target.latitude + 0.0018, target.longitude);
    repo.lots = [lot];
    await tester.tap(find.byKey(_confirm));
    await _settle(tester);

    _expectAdjustMode(tester, on: false);
    expect(find.byKey(_manualMarker), findsOneWidget);
    expect(find.byKey(_dot), findsNothing);
    expect(find.byKey(const ValueKey('user-accuracy-circle')), findsNothing);
    expect(find.byKey(_lowAccuracy), findsNothing);
    expect(repo.calls.length, callsBefore + 1);
    _expectNear(repo.calls.last.point, target);
    expect(repo.calls.last.radiusM, 1000);
    expect(_searches.last.trigger, SearchTrigger.manualPosition);

    // AC3 / BR-11: card distance from the manual position.
    await tester.tap(find.byKey(const ValueKey('lot-pin-n')));
    await _settle(tester);
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('lot-card-distance'))).data,
      formatDistance(haversineMetres(target, lot.position), en),
    );
  });

  testWidgets('AC2 / TC-1.3.9: overflow menu "Set my position" → adjust '
      'mode at the screen centre', (tester) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService();
    await _launch(tester, repo: FakeLotsRepository(), service: service);
    await _emit(tester, service, MockPoints.mp1);
    final centre = _camera(tester).center;

    await tester.tap(find.byKey(_menu));
    await _settle(tester);
    expect(find.text(_en.setPosition), findsOneWidget);
    await tester.tap(find.byKey(_menuSetPosition));
    await _settle(tester);

    _expectAdjustMode(tester, on: true);
    _expectNear(_camera(tester).center, centre); // no camera move
    expect(find.byKey(_menu), findsNothing);
  });

  testWidgets('AC2 / TC-1.3.7 / TC-1.3.17b: long-press → adjust mode with '
      'the pressed point under the crosshair; again in adjust mode moves '
      'only', (tester) async {
    final service = FakeLocationService();
    final repo = FakeLotsRepository();
    await _launch(tester, repo: repo, service: service);
    await _emit(tester, service, MockPoints.mp1);
    final calls = repo.calls.length;

    final mapCentre = tester.getCenter(find.byType(FlutterMap));
    final pressAt = mapCentre + const Offset(100, -60);
    final pressed = _camera(tester).screenOffsetToLatLng(pressAt);
    await tester.longPressAt(pressAt);
    await _settle(tester);

    _expectAdjustMode(tester, on: true);
    _expectNear(_camera(tester).center, pressed, tol: 1e-5);

    final pressAt2 = mapCentre + const Offset(-80, 40);
    final pressed2 = _camera(tester).screenOffsetToLatLng(pressAt2);
    await tester.longPressAt(pressAt2);
    await _settle(tester);
    _expectAdjustMode(tester, on: true); // still one adjust mode
    _expectNear(_camera(tester).center, pressed2, tol: 1e-5);
    expect(repo.calls.length, calls); // no request
  });

  testWidgets('AC2 / TC-1.3.17a: Adjust on banner_no_fix starts adjust mode', (
    tester,
  ) async {
    final service = FakeLocationService();
    await _launch(tester, repo: FakeLotsRepository(), service: service);
    await tester.pump(const Duration(seconds: 10));
    await _settle(tester);
    expect(find.byKey(_noFix), findsOneWidget);

    await tester.tap(find.byKey(_adjust));
    await _settle(tester);
    _expectAdjustMode(tester, on: true);
  });

  testWidgets('AC5 / TC-1.3.4: Cancel (each entry) → marker, pins and '
      'requests unchanged', (tester) async {
    final service = FakeLocationService();
    // Next to MP-3, where the camera is.
    final lots = [lotAt('a', 10.3268, 107.0848)];
    final repo = FakeLotsRepository(lots: lots);
    await _launch(tester, repo: repo, service: service);
    await _emit(tester, service, MockPoints.mp3LowAccuracy);
    final calls = repo.calls.length;
    expect(find.byKey(const ValueKey('lot-pin-a')), findsOneWidget);

    Future<void> moveAndCancel(Offset by) async {
      _expectAdjustMode(tester, on: true);
      await _drag(tester, by);
      await tester.tap(find.byKey(_cancel));
      await _settle(tester);
      _expectAdjustMode(tester, on: false);
      expect(find.byKey(_dot), findsOneWidget);
      expect(find.byKey(_manualMarker), findsNothing);
      expect(find.byKey(const ValueKey('lot-pin-a')), findsOneWidget);
      expect(repo.calls.length, calls);
    }

    // Low-accuracy banner.
    await tester.tap(find.byKey(_adjust));
    await _settle(tester);
    await moveAndCancel(const Offset(150, 0));
    // Menu.
    await _openMenuSetPosition(tester);
    await moveAndCancel(const Offset(-150, 0));
    // Long-press.
    await tester.longPressAt(
      tester.getCenter(find.byType(FlutterMap)) + const Offset(40, 40),
    );
    await _settle(tester);
    await moveAndCancel(const Offset(-40, -40));
  });

  testWidgets('AC4 / TC-1.3.3: GPS moves while manual → no change, no '
      'reload; My location → toast, blue dot, zoom 16, one 1 km request', (
    tester,
  ) async {
    _setLocale(tester, const Locale('en'));
    final service = FakeLocationService();
    final repo = FakeLotsRepository();
    await _launch(tester, repo: repo, service: service);
    await _emit(tester, service, MockPoints.mp1);

    await _openMenuSetPosition(tester);
    final manual = await _drag(tester, const Offset(0, 120));
    await tester.tap(find.byKey(_confirm));
    await _settle(tester);
    final calls = repo.calls.length;
    final camera = _camera(tester).center;

    await _emit(tester, service, MockPoints.mp4);
    await _emit(tester, service, fixAt(10.3520, 107.0840));
    expect(find.byKey(_manualMarker), findsOneWidget);
    expect(find.byKey(_dot), findsNothing);
    _expectNear(_camera(tester).center, camera);
    expect(repo.calls.length, calls);
    _expectNear(_searches.last.point, manual);

    await tester.tap(find.byKey(_fab));
    await _settle(tester);
    expect(find.byKey(_toast), findsOneWidget);
    expect(find.text(_en.usingGps), findsOneWidget);
    expect(find.byKey(_dot), findsOneWidget);
    expect(find.byKey(_manualMarker), findsNothing);
    _expectNear(_camera(tester).center, const LatLng(10.3520, 107.0840));
    expect(_camera(tester).zoom, closeTo(16, 1e-6));
    expect(repo.calls.length, calls + 1);
    expect(repo.calls.last.radiusM, 1000);
    _expectNear(repo.calls.last.point, const LatLng(10.3520, 107.0840));

    // The toast disappears by itself.
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    expect(find.byKey(_toast), findsNothing);
  });

  testWidgets('AC4 / TC-1.3.15a: consent declined, manual active → My '
      'location reopens S1, manual kept, no toast', (tester) async {
    final service = FakeLocationService();
    await _launch(
      tester,
      repo: FakeLotsRepository(),
      service: service,
      consent: ConsentResult.declined,
    );
    await _openMenuSetPosition(tester);
    await tester.tap(find.byKey(_confirm));
    await _settle(tester);

    await tester.tap(find.byKey(_fab));
    await _settle(tester);
    expect(find.byKey(const ValueKey('consent-allow')), findsOneWidget);
    expect(find.byKey(_toast), findsNothing);
    expect(service.totalCalls, 0);

    // QA BUG-1 (2026-11-28): "Not now" must return to the same map with the
    // manual position kept — no new request, no location call.
    final searchesBefore = _searches.length;
    await tester.tap(find.byKey(const ValueKey('consent-not-now')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('consent-allow')), findsNothing);
    expect(find.byKey(_manualMarker), findsOneWidget);
    expect(_searches.length, searchesBefore);
    expect(service.totalCalls, 0);
  });

  testWidgets('AC6 / TC-1.3.5: permission denied → manual position via the '
      'menu; lots loaded around it; distance from it', (tester) async {
    final service = FakeLocationService(
      checkResult: LocationPermissionStatus.denied,
    );
    final lot = lotAt('x', 10.3520, 107.0830);
    final repo = FakeLotsRepository(lots: [lot]);
    await _launch(tester, repo: repo, service: service);
    expect(
      find.byKey(const ValueKey('banner-location-needed')),
      findsOneWidget,
    );

    // Without a position the card has no distance (D7) …
    await tester.tap(find.byKey(const ValueKey('lot-pin-x')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('lot-card-distance')), findsNothing);

    await _openMenuSetPosition(tester);
    expect(find.byKey(const ValueKey('lot-card-x')), findsNothing);
    final manual = await _drag(tester, const Offset(-60, 90));
    await tester.tap(find.byKey(_confirm));
    await _settle(tester);

    expect(find.byKey(_manualMarker), findsOneWidget);
    _expectNear(repo.calls.last.point, manual);
    expect(repo.calls.last.radiusM, 1000);
    // … and with the manual position it has.
    await tester.tap(find.byKey(const ValueKey('lot-pin-x')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('lot-card-distance')), findsOneWidget);
  });

  testWidgets('AC8 / TC-1.3.18: manual outside the area → out-of-area '
      'banner, request at the default centre', (tester) async {
    final service = FakeLocationService();
    final repo = FakeLotsRepository();
    await _launch(tester, repo: repo, service: service);
    await _emit(tester, service, MockPoints.mp1);

    // Long-press far north-west of the map (zoom out first).
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(10.5, 107.0), 15); // outside (lat > 10.45)
    await _settle(tester);
    await _openMenuSetPosition(tester);
    await tester.tap(find.byKey(_confirm));
    await _settle(tester);

    expect(find.byKey(_outOfArea), findsOneWidget);
    expect(repo.calls.last.point, MapConstants.defaultCentre);
    expect(repo.calls.last.radiusM, 1000);
    expect(find.byKey(_manualMarker), findsOneWidget);
  });

  testWidgets('AC7 / TC-1.3.6: manual position is memory only — cleared on '
      'restart; nothing written to the device store', (tester) async {
    final store = FakeConsentStore(consentRecord(ConsentResult.granted));
    final service = FakeLocationService();
    await _launch(
      tester,
      repo: FakeLotsRepository(),
      service: service,
      store: store,
    );
    await _openMenuSetPosition(tester);
    await tester.tap(find.byKey(_confirm));
    await _settle(tester);
    expect(find.byKey(_manualMarker), findsOneWidget);
    expect(store.saveCalls, 0);

    // Restart (new app instance, same device storage).
    final service2 = FakeLocationService();
    final repo2 = FakeLotsRepository();
    await _launch(tester, repo: repo2, service: service2, store: store);
    expect(find.byKey(_manualMarker), findsNothing);
    await _emit(tester, service2, MockPoints.mp1);
    expect(find.byKey(_dot), findsOneWidget);
    expect(repo2.calls.single.point, MockPoints.mp1.position);
  });

  group('§6 strings, NFR-8 (TC-1.3.13)', () {
    for (final (locale, s) in [
      (const Locale('en'), _en),
      (const Locale('vi'), _vi),
    ]) {
      testWidgets('${locale.languageCode}: banner, menu, hint, buttons, toast, '
          'marker label; 320 px, 48 dp', (tester) async {
        _setLocale(tester, locale);
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();

        final service = FakeLocationService();
        await _launch(tester, repo: FakeLotsRepository(), service: service);
        await _emit(tester, service, MockPoints.mp3LowAccuracy);
        expect(find.text(s.lowAccuracy), findsOneWidget);
        expect(find.text(s.adjust), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(_menu));
        await _settle(tester);
        expect(find.text(s.setPosition), findsOneWidget);
        await tester.tap(find.byKey(_menuSetPosition));
        await _settle(tester);
        expect(find.text(s.hint), findsOneWidget);
        expect(find.text(s.confirm), findsOneWidget);
        expect(find.text(s.cancel), findsOneWidget);
        for (final key in [_confirm, _cancel]) {
          final rect = tester.getRect(find.byKey(key));
          expect(rect.height, greaterThanOrEqualTo(48), reason: '$key');
          expect(rect.right, lessThanOrEqualTo(320), reason: '$key');
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(_confirm));
        await _settle(tester);
        expect(find.bySemanticsLabel(s.manualMarker), findsOneWidget);

        await tester.tap(find.byKey(_fab));
        await _settle(tester);
        expect(find.text(s.usingGps), findsOneWidget);
        expect(tester.takeException(), isNull);

        semantics.dispose();
      });
    }
  });
}
