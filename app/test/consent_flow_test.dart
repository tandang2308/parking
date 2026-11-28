import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:parkfinder/config/tile_config.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/consent/consent_screen.dart';
import 'package:parkfinder/features/location/location_service.dart';
import 'package:parkfinder/main.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.4 widget tests (TC-1.4.1–TC-1.4.4, TC-1.4.7 automated part,
/// TC-1.4.8 flow, D3/D4 of MTG-2026-11-24-po-decisions-2).

Future<vt.Style> _pendingStyle(String _, String _) => Completer<vt.Style>().future;

const _allow = ValueKey('consent-allow');
const _notNow = ValueKey('consent-not-now');
const _banner = ValueKey('banner-location-needed');
const _enable = ValueKey('banner-enable');

/// SPEC-001 §6 texts (exact).
const _en = (
  title: 'Allow location access',
  body: 'ParkFinder uses your location only while the app is open, to show '
      'parking lots near you. Your location is not stored on our servers. '
      'You can turn this off at any time in your device or browser settings.',
  allow: 'Allow',
  notNow: 'Not now',
  banner: 'Turn on location to see lots near you',
  enable: 'Enable',
);
const _vi = (
  title: 'Cho phép truy cập vị trí',
  body: 'ParkFinder chỉ dùng vị trí của bạn khi bạn đang mở ứng dụng, để hiển '
      'thị các bãi xe gần bạn. Vị trí không được lưu trên máy chủ của chúng '
      'tôi. Bạn có thể tắt quyền này bất cứ lúc nào trong cài đặt của thiết bị '
      'hoặc trình duyệt.',
  allow: 'Cho phép',
  notNow: 'Để sau',
  banner: 'Bật định vị để xem bãi xe gần bạn',
  enable: 'Bật',
);

/// Launches (or relaunches) the app with [store] and [permissions].
Future<void> _launch(
  WidgetTester tester,
  FakeConsentStore store,
  FakeLocationService permissions, {
  int consentVersion = 1,
}) async {
  // Unmount any previous app so the relaunch starts with fresh state.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ParkFinderApp(
      tileConfig: const TileConfig(),
      styleLoader: _pendingStyle,
      consentStore: store,
      locationService: permissions,
      lotsRepository: FakeLotsRepository(),
      consentVersion: consentVersion,
    ),
  );
  await tester.pump(); // consent record loaded
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void _setSmallScreen(WidgetTester tester) {
  // LA device width in TC-1.4.7: 320 logical px.
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('AC1 consent first', () {
    testWidgets('first launch shows S1 before the map; no location call',
        (tester) async {
      _setLocale(tester, const Locale('en'));
      final store = FakeConsentStore();
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      // TC-1.4.1 step 2: observe ≥ 15 s without tapping.
      await tester.pump(const Duration(seconds: 15));

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all
      expect(store.saveCalls, 0);
    });

    testWidgets('no stored answer after closing without answering (TC-1.4.9)',
        (tester) async {
      final store = FakeConsentStore();
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      await _launch(tester, store, permissions); // relaunch, not answered

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(store.record, isNull);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all
    });
  });

  group('AC3 allow', () {
    testWidgets('stores granted + version + timestamp, requests permission, '
        'shows the map', (tester) async {
      final store = FakeConsentStore();
      final permissions = FakeLocationService();
      final before = DateTime.now().toUtc();

      await _launch(tester, store, permissions, consentVersion: 4);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all

      await tester.tap(find.byKey(_allow));
      await tester.pump();

      final record = store.record!;
      expect(record.result, ConsentResult.granted);
      expect(record.version, 4);
      expect(record.timestamp.isUtc, isTrue);
      expect(
        record.timestamp.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(permissions.requestCalls, 1);
      expect(find.byType(ConsentScreen), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(_banner), findsNothing);
    });

    testWidgets('Allow + OS denial → map with banner_location_needed '
        '(US-1.1 AC4), no crash', (tester) async {
      final store = FakeConsentStore();
      final permissions = FakeLocationService(
        requestResult: LocationPermissionStatus.denied,
      );

      await _launch(tester, store, permissions);
      await tester.tap(find.byKey(_allow));
      await tester.pump();
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(_banner), findsOneWidget);
      expect(store.record!.result, ConsentResult.granted);
      expect(tester.takeException(), isNull);
    });

    testWidgets('relaunch with granted → map directly, S1 not shown',
        (tester) async {
      final store = FakeConsentStore(consentRecord(ConsentResult.granted));
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);

      expect(find.byType(ConsentScreen), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(_banner), findsNothing);
    });
  });

  group('AC4/AC5 not now', () {
    testWidgets('stores declined, no permission request, map with banner; '
        'Enable reopens S1 (TC-1.4.3)', (tester) async {
      _setLocale(tester, const Locale('en'));
      final store = FakeConsentStore();
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      await tester.tap(find.byKey(_notNow));
      await tester.pump();

      expect(store.record!.result, ConsentResult.declined);
      expect(store.record!.version, 1);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(_banner), findsOneWidget);
      expect(find.text(_en.banner), findsOneWidget);
      expect(find.text(_en.enable), findsOneWidget);

      // Relaunch: S1 not shown automatically (AC5), map + banner directly.
      await _launch(tester, store, permissions);
      expect(find.byType(ConsentScreen), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(_banner), findsOneWidget);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all

      // "Enable" reopens S1, not the OS prompt.
      await tester.tap(find.byKey(_enable));
      await tester.pump();
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all
    });

    testWidgets('Enable → Allow stores granted and requests permission '
        '(TC-1.4.8)', (tester) async {
      final store = FakeConsentStore(consentRecord(ConsentResult.declined));
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      await tester.tap(find.byKey(_enable));
      await tester.pump();
      await tester.tap(find.byKey(_allow));
      await tester.pump();

      expect(store.record!.result, ConsentResult.granted);
      expect(
        store.record!.timestamp.isAfter(DateTime.utc(2026, 11, 24, 8)),
        isTrue,
      );
      expect(permissions.requestCalls, 1);
      expect(find.byKey(_banner), findsNothing);

      // Relaunch: S1 not shown.
      await _launch(tester, store, permissions);
      expect(find.byType(ConsentScreen), findsNothing);
    });

    testWidgets('Enable → Not now again keeps declined and the banner',
        (tester) async {
      final store = FakeConsentStore(consentRecord(ConsentResult.declined));
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      await tester.tap(find.byKey(_enable));
      await tester.pump();
      await tester.tap(find.byKey(_notNow));
      await tester.pump();

      expect(store.record!.result, ConsentResult.declined);
      expect(find.byKey(_banner), findsOneWidget);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all
    });
  });

  group('AC6 version change', () {
    for (final result in ConsentResult.values) {
      testWidgets('older stored version (${result.name}) → S1 again, '
          'no location call (TC-1.4.4)', (tester) async {
        final store = FakeConsentStore(consentRecord(result, version: 1));
        final permissions = FakeLocationService();

        await _launch(tester, store, permissions, consentVersion: 2);

        expect(find.byType(ConsentScreen), findsOneWidget);
        expect(find.byType(FlutterMap), findsNothing);
        expect(permissions.totalCalls, 0); // BR-9: no location API at all
      });
    }
  });

  group('storage unavailable (D4)', () {
    testWidgets('load failure → S1, no crash', (tester) async {
      final store = FakeConsentStore()..failLoad = true;
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('save failure on Allow → map + permission request, no crash',
        (tester) async {
      final store = FakeConsentStore()..failSave = true;
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      await tester.tap(find.byKey(_allow));
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(permissions.requestCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('save failure on Not now → map + banner, no request',
        (tester) async {
      final store = FakeConsentStore()..failSave = true;
      final permissions = FakeLocationService();

      await _launch(tester, store, permissions);
      await tester.tap(find.byKey(_notNow));
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(_banner), findsOneWidget);
      expect(permissions.totalCalls, 0); // BR-9: no location API at all
      expect(tester.takeException(), isNull);
    });
  });

  group('AC2 content, §6 strings, NFR-8 (TC-1.4.7)', () {
    final cases = {
      const Locale('en'): _en,
      const Locale('vi'): _vi,
    };

    cases.forEach((locale, s) {
      testWidgets('S1 and banner in ${locale.languageCode} match §6, '
          'no overflow at 320 px', (tester) async {
        _setLocale(tester, locale);
        _setSmallScreen(tester);
        final semantics = tester.ensureSemantics();
        final store = FakeConsentStore();
        final permissions = FakeLocationService();

        await _launch(tester, store, permissions);

        expect(find.text(s.title), findsOneWidget);
        expect(find.text(s.body), findsOneWidget);
        expect(find.text(s.allow), findsOneWidget);
        expect(find.text(s.notNow), findsOneWidget);
        // AC2: no privacy-policy link until US-5.2 (Q-B).
        expect(find.text('Privacy policy'), findsNothing);
        expect(find.text('Chính sách quyền riêng tư'), findsNothing);
        expect(tester.takeException(), isNull);

        // NFR-8: buttons have labels and ≥ 48 dp touch targets, on screen.
        for (final (key, label) in [(_allow, s.allow), (_notNow, s.notNow)]) {
          expect(
            tester.getSemantics(find.byKey(key)),
            containsSemantics(label: label, isButton: true, hasTapAction: true),
          );
          final rect = tester.getRect(find.byKey(key));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.bottom, lessThanOrEqualTo(568));
        }

        await tester.tap(find.byKey(_notNow));
        await tester.pump();

        expect(find.text(s.banner), findsOneWidget);
        expect(find.text(s.enable), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(_enable)),
          containsSemantics(label: s.enable, isButton: true),
        );
        final enableRect = tester.getRect(find.byKey(_enable));
        expect(enableRect.height, greaterThanOrEqualTo(48));
        expect(enableRect.width, greaterThanOrEqualTo(48));
        expect(enableRect.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);

        semantics.dispose();
      });
    });

    testWidgets('S1 body scrolls without overflow with large text at 320 px',
        (tester) async {
      _setLocale(tester, const Locale('vi'));
      _setSmallScreen(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _launch(
        tester,
        FakeConsentStore(),
        FakeLocationService(),
      );

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // Buttons stay reachable without scrolling.
      expect(
        tester.getRect(find.byKey(_notNow)).bottom,
        lessThanOrEqualTo(568),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('unsupported device language falls back to vi',
        (tester) async {
      _setLocale(tester, const Locale('fr'));
      await _launch(
        tester,
        FakeConsentStore(),
        FakeLocationService(),
      );
      expect(find.text(_vi.title), findsOneWidget);
    });

    testWidgets('en-US device uses en', (tester) async {
      _setLocale(tester, const Locale('en', 'US'));
      await _launch(
        tester,
        FakeConsentStore(),
        FakeLocationService(),
      );
      expect(find.text(_en.title), findsOneWidget);
    });
  });
}
