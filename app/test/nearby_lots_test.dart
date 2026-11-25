import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:parkfinder/config/tile_config.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/lots/lot_pins_layer.dart';
import 'package:parkfinder/features/lots/lot_placeholder_screen.dart';
import 'package:parkfinder/features/lots/lot_card.dart';
import 'package:parkfinder/features/lots/lots_geo.dart';
import 'package:parkfinder/features/lots/parking_lot.dart';
import 'package:parkfinder/features/map/map_constants.dart';
import 'package:parkfinder/l10n/generated/app_localizations.dart';
import 'package:parkfinder/main.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.2 widget tests: pins (AC2), loading (AC3), empty (AC4),
/// error + retry (AC5), "Search this area" (AC6), clusters/spiderfy (AC7),
/// card + `/lot/:id` (AC8), cap hint (AC9), default centre (AC10), outside
/// area (AC11), §6 strings vi/en, NFR-8 labels, 320 px layout.

Future<vt.Style> _pendingStyle(String _) => Completer<vt.Style>().future;

const _centre = MapConstants.defaultCentre;
const _fab = ValueKey('fab-my-location');
const _chip = ValueKey('chip-search-area');
const _loading = ValueKey('lots-loading');
const _cap = ValueKey('hint-cap');
const _errorBanner = ValueKey('banner-load-error');
const _retry = ValueKey('banner-retry');
const _expand = ValueKey('btn-expand');
const _card = ValueKey('lot-card-tap');

Key _pin(String id) => ValueKey('lot-pin-$id');

/// SPEC-001 §6 texts (exact).
const _en = (
  searchArea: 'Search this area',
  emptyRadius: 'No parking lots within 1 km',
  expand: 'Expand to 3 km',
  emptyNone: 'No parking lots found nearby yet',
  emptyArea: 'No parking lots in this area',
  error: "Can't load parking lots",
  retry: 'Retry',
  cap: 'Showing nearest 50 — zoom in to see more',
  types: 'Motorbike, Car',
  cluster: '2 parking lots',
);
const _vi = (
  searchArea: 'Tìm trong khu vực này',
  emptyRadius: 'Không có bãi xe trong bán kính 1 km',
  expand: 'Mở rộng đến 3 km',
  emptyNone: 'Chưa tìm thấy bãi xe nào gần đây',
  emptyArea: 'Không có bãi xe trong khu vực này',
  error: 'Không tải được bãi xe',
  retry: 'Thử lại',
  cap: 'Đang hiển thị 50 bãi gần nhất — phóng to để xem thêm',
  types: 'Xe máy, Ô tô',
  cluster: '2 bãi xe',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// Launches the app. Default: consent declined → default centre, zoom 15,
/// one BR-3 (a) search, no location API (US-1.2 AC10).
Future<void> _launch(
  WidgetTester tester,
  FakeLotsRepository repo, {
  FakeConnectivityMonitor? net,
  FakeLocationService? service,
  ConsentResult consent = ConsentResult.declined,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ParkFinderApp(
      tileConfig: const TileConfig(),
      styleLoader: _pendingStyle,
      consentStore: FakeConsentStore(consentRecord(consent)),
      locationService: service ?? FakeLocationService(),
      lotsRepository: repo,
      connectivity: net,
      clock: () => testNow,
    ),
  );
  await _settle(tester);
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

/// Three well-separated lots around the default centre (> 60 px at z15).
final _threeLots = [
  lotAt('moto', 10.3490, 107.0740, types: {VehicleType.motorbike}),
  lotAt('car', 10.3430, 107.0740, types: {VehicleType.car}),
  lotAt('both', 10.3460, 107.0700),
];

void main() {
  testWidgets('AC1 / AC10 / TC-1.2.10: no location → nearby_lots at the '
      'default centre, 1000 m; pins appear', (tester) async {
    final repo = FakeLotsRepository(lots: _threeLots);
    await _launch(tester, repo);

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.point, _centre);
    expect(repo.calls.single.radiusM, 1000);
    for (final id in ['moto', 'car', 'both']) {
      expect(find.byKey(_pin(id)), findsOneWidget);
    }
  });

  testWidgets('AC2 / TC-1.2.2: icon + colour per vehicle type; the '
      'selected pin is enlarged', (tester) async {
    final repo = FakeLotsRepository(lots: _threeLots);
    await _launch(tester, repo);

    LotPin pin(String id) => tester.widget<LotPin>(
        find.descendant(of: find.byKey(_pin(id)), matching: find.byType(LotPin)));
    expect(pin('moto').kind, PinKind.motorbike);
    expect(pin('car').kind, PinKind.car);
    expect(pin('both').kind, PinKind.both);
    expect(PinColors.of(PinKind.motorbike), const Color(0xFF2E7D32));
    expect(PinColors.of(PinKind.car), const Color(0xFF1565C0));
    expect(PinColors.of(PinKind.both), const Color(0xFF6A1B9A));
    expect(
      find.descendant(
          of: find.byKey(_pin('moto')), matching: find.byIcon(Icons.two_wheeler)),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byKey(_pin('car')), matching: find.byIcon(Icons.directions_car)),
      findsOneWidget,
    );
    final both = find.byKey(_pin('both'));
    expect(find.descendant(of: both, matching: find.byIcon(Icons.two_wheeler)),
        findsOneWidget);
    expect(
        find.descendant(of: both, matching: find.byIcon(Icons.directions_car)),
        findsOneWidget);

    expect(tester.getSize(find.byKey(_pin('car'))), const Size(48, 48));
    await tester.tap(find.byKey(_pin('car')));
    await _settle(tester);
    expect(pin('car').selected, isTrue);
    expect(tester.getSize(find.byKey(_pin('car'))), const Size(60, 60));
    expect(pin('moto').selected, isFalse);

    // Tapping the map clears the selection.
    await tester.tapAt(const Offset(700, 450));
    await _settle(tester);
    expect(pin('car').selected, isFalse);
    expect(repo.calls, hasLength(1)); // no reload (TC-1.2.15)
  });

  testWidgets('AC8 / TC-1.2.7: tap pin → card with name, types, BR-15 '
      'distance from the user; tap card → /lot/:id', (tester) async {
    final service = FakeLocationService();
    // 0.00315° north of MP-1 ≈ 350 m.
    final lot = lotAt('q1', 10.34915, 107.0740, name: 'Bãi giữ xe Quang Trung');
    final repo = FakeLotsRepository(lots: [lot]);
    _setLocale(tester, const Locale('en'));
    await _launch(tester, repo, service: service, consent: ConsentResult.granted);
    service.emit(MockPoints.mp1);
    await _settle(tester);

    await tester.tap(find.byKey(_pin('q1')));
    await _settle(tester);
    expect(find.text('Bãi giữ xe Quang Trung'), findsOneWidget);
    expect(find.text(_en.types), findsOneWidget);
    expect(find.text('350 m'), findsOneWidget);

    await tester.tap(find.byKey(_card));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<LotPlaceholderScreen>(find.byType(LotPlaceholderScreen));
    expect(screen.lotId, 'q1');
    expect(ModalRoute.of(tester.element(find.byType(LotPlaceholderScreen)))!
        .settings
        .name, '/lot/q1');
  });

  testWidgets('AC8 wide screen (Web 1910 px): card stays compact, distance '
      'next to the name', (tester) async {
    tester.view.physicalSize = const Size(1910, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lot = lotAt('w', 10.3470, 107.0740, name: 'Bãi đỗ xe');
    final repo = FakeLotsRepository(lots: [lot]);
    _setLocale(tester, const Locale('en'));
    await _launch(tester, repo);

    await tester.tap(find.byKey(_pin('w')));
    await _settle(tester);
    final card = tester.getRect(find.byKey(const ValueKey('lot-card-w')));
    expect(card.width, lessThanOrEqualTo(LotMiniCard.maxWidth));
    final distance =
        tester.getRect(find.byKey(const ValueKey('lot-card-distance')));
    expect(distance.right, lessThanOrEqualTo(card.right));
  });

  testWidgets('AC11 / TC-1.2.24 / TC-1.2.17 (BR-11): outside the area → '
      'search at the default centre, card distance from the user (km)',
      (tester) async {
    final service = FakeLocationService();
    final lot = lotAt('near', 10.3470, 107.0750);
    final repo = FakeLotsRepository(lots: [lot]);
    _setLocale(tester, const Locale('vi'));
    await _launch(tester, repo, service: service, consent: ConsentResult.granted);
    service.emit(MockPoints.mp6);
    await _settle(tester);
    expect(repo.calls.last.point, _centre);
    expect(repo.calls.last.radiusM, 1000);

    // "Go to Vũng Tàu" (US-1.1 AC10) and tap the lot.
    await tester.tap(find.byKey(const ValueKey('banner-go-vung-tau')));
    await _settle(tester);
    await tester.tap(find.byKey(_pin('near')));
    await _settle(tester);

    final vi = lookupAppLocalizations(const Locale('vi'));
    final expected =
        formatDistance(haversineMetres(MockPoints.mp6.position, lot.position), vi);
    expect(expected, endsWith(' km'));
    expect(expected, contains(','));
    final shown = tester
        .widget<Text>(find.byKey(const ValueKey('lot-card-distance')))
        .data;
    expect(shown, expected);
    // Not the distance from the search centre (≈ 150 m).
    expect(shown, isNot(formatDistance(haversineMetres(_centre, lot.position), vi)));
  });

  testWidgets('AC3 / TC-1.2.11: loading chip while in flight; previous pins '
      'stay; map stays usable', (tester) async {
    final service = FakeLocationService();
    final repo = FakeLotsRepository(hold: true);
    await _launch(tester, repo, service: service, consent: ConsentResult.granted);
    service.emit(MockPoints.mp1);
    await _settle(tester);
    expect(find.byKey(_loading), findsOneWidget);
    repo.complete(_threeLots);
    await _settle(tester);
    expect(find.byKey(_loading), findsNothing);
    expect(find.byKey(_pin('both')), findsOneWidget);

    await tester.drag(find.byType(FlutterMap), const Offset(-60, 0));
    await _settle(tester);
    await tester.tap(find.byKey(_fab)); // BR-3 (b)
    await _settle(tester);
    expect(find.byKey(_loading), findsOneWidget);
    expect(find.byKey(_pin('both')), findsOneWidget); // old pins kept
    // Map still pannable while loading.
    final before = _camera(tester).center;
    await tester.drag(find.byType(FlutterMap), const Offset(-80, 0));
    await _settle(tester);
    expect(_camera(tester).center, isNot(before));
    repo.complete(const []);
    await _settle(tester);
    expect(find.byKey(_loading), findsNothing);
  });

  group('§6 strings (TC-1.2.21)', () {
    for (final (locale, s) in [
      (const Locale('en'), _en),
      (const Locale('vi'), _vi),
    ]) {
      testWidgets('AC4 / TC-1.2.3 / TC-1.2.12: ${locale.languageCode} empty '
          'radius → Expand → none', (tester) async {
        _setLocale(tester, locale);
        final repo = FakeLotsRepository();
        await _launch(tester, repo);

        expect(find.text(s.emptyRadius), findsOneWidget);
        expect(find.text(s.expand), findsOneWidget);
        expect(find.byKey(_cap), findsNothing); // TC-1.2.23: 0 → no hint
        await tester.tap(find.byKey(_expand));
        await _settle(tester);
        expect(repo.calls.last, (point: _centre, radiusM: 3000));
        expect(find.text(s.emptyNone), findsOneWidget);
        expect(find.byKey(_expand), findsNothing);
        expect(find.text(s.emptyRadius), findsNothing);
        expect(find.byKey(_errorBanner), findsNothing);
      });

      testWidgets('AC5 / TC-1.2.4: ${locale.languageCode} error banner has '
          'top priority; Retry repeats; one auto retry on reconnect',
          (tester) async {
        _setLocale(tester, locale);
        final net = FakeConnectivityMonitor();
        addTearDown(net.dispose);
        final repo = FakeLotsRepository(error: const FormatException('x'));
        await _launch(tester, repo, net: net);

        // Consent declined → banner_location_needed would show, but the
        // error banner wins (§3) and only one banner is shown.
        expect(find.text(s.error), findsOneWidget);
        expect(find.text(s.retry), findsOneWidget);
        expect(find.byKey(const ValueKey('banner-location-needed')),
            findsNothing);

        await tester.tap(find.byKey(_retry));
        await _settle(tester);
        expect(repo.calls, hasLength(2));
        expect(repo.calls.last, (point: _centre, radiusM: 1000));
        expect(find.text(s.error), findsOneWidget);

        repo
          ..error = null
          ..lots = _threeLots;
        net.reconnect();
        await _settle(tester);
        expect(repo.calls, hasLength(3));
        expect(find.byKey(_errorBanner), findsNothing);
        expect(find.byKey(const ValueKey('banner-location-needed')),
            findsOneWidget);
        expect(find.byKey(_pin('moto')), findsOneWidget);
      });

      testWidgets('AC9 / TC-1.2.23: ${locale.languageCode} cap hint at 50',
          (tester) async {
        _setLocale(tester, locale);
        await _launch(tester, FakeLotsRepository(lots: _manyLots(50)));
        expect(find.text(s.cap), findsOneWidget);
        await _launch(tester, FakeLotsRepository(lots: _manyLots(49)));
        expect(find.byKey(_cap), findsNothing);
      });

      testWidgets('AC6 / AC4 / TC-1.2.5 / TC-1.2.26: ${locale.languageCode} '
          '"Search this area" after a pan; empty_area without Expand',
          (tester) async {
        _setLocale(tester, locale);
        final repo = FakeLotsRepository(lots: _threeLots);
        await _launch(tester, repo);
        expect(find.byKey(_chip), findsNothing);

        await tester.drag(find.byType(FlutterMap), const Offset(-100, 0));
        await _settle(tester);
        expect(find.byKey(_chip), findsNothing); // 12.5% of 800 px

        await tester.drag(find.byType(FlutterMap), const Offset(-250, 0));
        await _settle(tester);
        expect(find.text(s.searchArea), findsOneWidget);
        expect(repo.calls, hasLength(1)); // pan never loads

        repo.lots = const [];
        await tester.tap(find.byKey(_chip));
        await _settle(tester);
        expect(repo.calls, hasLength(2));
        final camera = _camera(tester);
        expect(repo.calls.last.point, camera.center);
        expect(repo.calls.last.radiusM, SearchAreaRule.radiusFor(camera));
        expect(find.byKey(_chip), findsNothing);
        expect(find.text(s.emptyArea), findsOneWidget);
        expect(find.byKey(_expand), findsNothing);
      });

      testWidgets('NFR-8 / TC-1.2.22: ${locale.languageCode} pin and cluster '
          'labels; 48 dp targets', (tester) async {
        _setLocale(tester, locale);
        final semantics = tester.ensureSemantics();
        await _launch(tester, FakeLotsRepository(lots: [
          lotAt('a', 10.3490, 107.0740, name: 'A'),
          lotAt('b', 10.3430, 107.0740, name: 'B'),
          lotAt('c', 10.3430, 107.0741, name: 'C'),
        ]));
        expect(find.bySemanticsLabel('A, ${s.types}'), findsOneWidget);
        expect(find.bySemanticsLabel(s.cluster), findsOneWidget);
        expect(tester.getSize(find.byKey(_pin('a'))).width,
            greaterThanOrEqualTo(48));
        semantics.dispose();
      });
    }
  });

  testWidgets('AC7 / TC-1.2.6 / TC-1.2.15: overlapping pins → cluster with a '
      'count; tap zooms in until they separate; no request', (tester) async {
    final repo = FakeLotsRepository(lots: [
      lotAt('a', 10.3460, 107.0740),
      lotAt('b', 10.3462, 107.0740), // ≈ 22 m: 4.7 px at z15, 38 px at z18
    ]);
    await _launch(tester, repo);
    final cluster = find.byKey(const ValueKey('lot-cluster-a|b'));
    expect(cluster, findsOneWidget);
    expect(find.descendant(of: cluster, matching: find.text('2')), findsOneWidget);
    expect(find.byKey(_pin('a')), findsNothing);

    await tester.tap(cluster);
    await _settle(tester);
    expect(_camera(tester).zoom, greaterThan(15));
    expect(find.byKey(_pin('a')), findsOneWidget);
    expect(find.byKey(_pin('b')), findsOneWidget);
    expect(repo.calls, hasLength(1));
  });

  testWidgets('AC7 / TC-1.2.30: identical coordinates stay clustered at '
      'zoom 18; tap spiderfies; each lot opens its own card', (tester) async {
    final repo = FakeLotsRepository(lots: [
      lotAt('c', 10.3460, 107.0740, name: 'Lot C'),
      lotAt('d', 10.3460, 107.0740, name: 'Lot D'),
    ]);
    await _launch(tester, repo);
    final cluster = find.byKey(const ValueKey('lot-cluster-c|d'));
    await tester.tap(cluster);
    await _settle(tester);
    expect(_camera(tester).zoom, closeTo(18, 1e-6));
    expect(cluster, findsOneWidget); // still clustered at max zoom

    await tester.tap(cluster);
    await _settle(tester);
    expect(cluster, findsNothing);
    expect(find.byKey(_pin('c')), findsOneWidget);
    expect(find.byKey(_pin('d')), findsOneWidget);
    expect((tester.getCenter(find.byKey(_pin('c'))) -
                tester.getCenter(find.byKey(_pin('d'))))
            .distance,
        greaterThanOrEqualTo(48));

    await tester.tap(find.byKey(_pin('c')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('lot-card-name')), findsOneWidget);
    expect(find.text('Lot C'), findsOneWidget);
    await tester.tap(find.byKey(_pin('d')));
    await _settle(tester);
    expect(find.text('Lot D'), findsOneWidget);
    expect(find.text('Lot C'), findsNothing);
    expect(repo.calls, hasLength(1));
  });

  testWidgets('AC5 / TC-1.2.4: error after a trigger keeps the pins',
      (tester) async {
    final service = FakeLocationService();
    final repo = FakeLotsRepository(lots: _threeLots);
    await _launch(tester, repo, service: service, consent: ConsentResult.granted);
    service.emit(fixAt(_centre.latitude, _centre.longitude));
    await _settle(tester);
    expect(find.byKey(_pin('both')), findsOneWidget);

    repo.error = const FormatException('offline');
    await tester.tap(find.byKey(_fab));
    await _settle(tester);
    expect(find.byKey(_errorBanner), findsOneWidget);
    expect(find.byKey(_pin('both')), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  for (final locale in const [Locale('vi'), Locale('en')]) {
    testWidgets('320 px (${locale.languageCode}): banner, cap hint, chip and '
        'card fit; attribution and FAB stay visible (BR-13)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _setLocale(tester, locale);

      final lots = [
        lotAt('t', 10.3470, 107.0740,
            name: 'Bãi giữ xe Trung tâm Thương mại Vũng Tàu Plaza'),
        ..._manyLots(49, lat: 10.40),
      ];
      final repo = FakeLotsRepository(lots: lots);
      await _launch(tester, repo);
      expect(find.byKey(_cap), findsOneWidget);
      expect(find.byKey(const ValueKey('banner-location-needed')),
          findsOneWidget);

      await tester.tap(find.byKey(_pin('t')));
      await _settle(tester);
      final card = find.byKey(const ValueKey('lot-card-t'));
      expect(card, findsOneWidget);
      expect(tester.takeException(), isNull);

      final cardRect = tester.getRect(card);
      final fabRect = tester.getRect(find.byKey(_fab));
      final attribution = tester.getRect(
          find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'));
      expect(cardRect.left, greaterThanOrEqualTo(0));
      expect(cardRect.right, lessThanOrEqualTo(320));
      expect(cardRect.overlaps(fabRect), isFalse);
      expect(cardRect.overlaps(attribution), isFalse);
      expect(fabRect.overlaps(attribution), isFalse);
      expect(attribution.right, lessThanOrEqualTo(320));

      // Error banner (top priority) + Retry also fit.
      repo.error = const FormatException('x');
      await tester.drag(find.byType(FlutterMap), const Offset(0, -250));
      await _settle(tester);
      await tester.tap(find.byKey(_chip));
      await _settle(tester);
      expect(find.byKey(_errorBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
      final retry = tester.getRect(find.byKey(_retry));
      expect(retry.right, lessThanOrEqualTo(320));
      expect(retry.height, greaterThanOrEqualTo(48));
    });
  }
}

/// [n] lots spread on a grid far enough apart to stay mostly visible.
List<ParkingLot> _manyLots(int n, {double lat = 10.3400}) => [
      for (var i = 0; i < n; i++)
        lotAt('m$i', lat + (i ~/ 10) * 0.002, 107.0650 + (i % 10) * 0.002),
    ];
