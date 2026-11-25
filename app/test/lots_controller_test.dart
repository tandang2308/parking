import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/features/location/location_controller.dart';
import 'package:parkfinder/features/lots/lots_controller.dart';
import 'package:parkfinder/features/lots/lots_geo.dart';
import 'package:parkfinder/features/lots/parking_lot.dart';
import 'package:parkfinder/features/map/map_constants.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.2 lots controller: AC1, AC3–AC6, AC9, D5, retry rules,
/// stale responses (TC-1.2.3, 1.2.4, 1.2.5, 1.2.10, 1.2.12, 1.2.13,
/// 1.2.14, 1.2.15, 1.2.23, 1.2.26, 1.2.29, 1.2.31, 1.2.33 (d)/(e)).

const _centre = MapConstants.defaultCentre;
const _gps = LatLng(10.3500, 107.0820); // MP-4

MapCamera _camera(LatLng centre, double zoom) => MapCamera(
      crs: const Epsg3857(),
      center: centre,
      zoom: zoom,
      rotation: 0,
      nonRotatedSize: const Size(400, 800),
    );

MapCamera _panned(MapCamera c, Offset px) => _camera(
      c.unprojectAtZoom(c.projectAtZoom(c.center) + px),
      c.zoom,
    );

List<ParkingLot> _lots(int n) => [
      for (var i = 0; i < n; i++) lotAt('l$i', 10.34 + i * 1e-4, 107.07),
    ];

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeLotsRepository repo;
  late FakeConnectivityMonitor net;
  late LotsController c;

  setUp(() {
    repo = FakeLotsRepository(hold: true);
    net = FakeConnectivityMonitor();
    c = LotsController(repository: repo, connectivity: net);
  });

  tearDown(() {
    c.dispose();
    net.dispose();
  });

  test('AC1 / TC-1.2.10: a position trigger loads at the point, 1000 m', () async {
    c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
    expect(repo.calls.single.point, _centre);
    expect(repo.calls.single.radiusM, 1000);
    expect(c.currentRequest!.kind, LotsSearchKind.position);
    repo.complete(_lots(3));
    await _flush();
    expect(c.lots, hasLength(3));
    expect(c.isLoading, isFalse);
    expect(c.emptyState, isNull);
  });

  test('AC3 / TC-1.2.11: loading flag while in flight, old pins kept', () async {
    c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
    repo.complete(_lots(2));
    await _flush();

    c.onSearchTrigger(_gps, SearchTrigger.myLocation);
    expect(c.isLoading, isTrue);
    expect(c.lots, hasLength(2)); // previous pins stay
    repo.complete(_lots(5));
    await _flush();
    expect(c.isLoading, isFalse);
    expect(c.lots, hasLength(5));
  });

  group('AC4 empty states, D5', () {
    test('TC-1.2.3: 0 at 1 km → empty_radius; Expand → same point at 3000; '
        'next trigger back to 1000', () async {
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      repo.complete(const []);
      await _flush();
      expect(c.emptyState, LotsEmptyState.radius);

      c.expand();
      expect(repo.calls.last.point, _gps);
      expect(repo.calls.last.radiusM, 3000);
      expect(c.emptyState, isNull); // message gone while loading
      repo.complete(_lots(1));
      await _flush();
      expect(c.emptyState, isNull);
      expect(c.lots, hasLength(1));

      c.onSearchTrigger(_gps, SearchTrigger.myLocation);
      expect(repo.calls.last.radiusM, 1000);
      repo.complete(const []);
      await _flush();
      expect(c.emptyState, LotsEmptyState.radius);
    });

    test('TC-1.2.12: still 0 at 3 km → empty_none, no further expand',
        () async {
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      repo.complete(const []);
      await _flush();
      c.expand();
      repo.complete(const []);
      await _flush();
      expect(c.emptyState, LotsEmptyState.none);
      expect(c.hasError, isFalse);

      c.expand(); // no-op
      expect(repo.calls, hasLength(2));
    });

    test('TC-1.2.26: area search with 0 → empty_area, Expand is a no-op',
        () async {
      c.onCameraChanged(_camera(_centre, 16), hasGesture: false);
      c.searchThisArea();
      repo.complete(const []);
      await _flush();
      expect(c.emptyState, LotsEmptyState.area);
      c.expand();
      expect(repo.calls, hasLength(1));
    });

    test('empty results remove the old pins', () async {
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      repo.complete(_lots(2));
      await _flush();
      c.onSearchTrigger(_centre, SearchTrigger.myLocation);
      repo.complete(const []);
      await _flush();
      expect(c.lots, isEmpty);
    });
  });

  group('AC5 error, Retry, auto retry', () {
    test('TC-1.2.4: error keeps pins; Retry repeats the same request',
        () async {
      c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
      repo.complete(_lots(4));
      await _flush();

      c.onSearchTrigger(_gps, SearchTrigger.myLocation);
      repo.fail();
      await _flush();
      expect(c.hasError, isTrue);
      expect(c.lots, hasLength(4));
      expect(c.isLoading, isFalse);

      c.retry();
      expect(repo.calls.last, (point: _gps, radiusM: 1000));
      expect(c.hasError, isTrue); // banner stays until a success
      repo.complete(_lots(1));
      await _flush();
      expect(c.hasError, isFalse);
      expect(c.lots, hasLength(1));
    });

    test('TC-1.2.31: exactly one automatic retry on offline → online',
        () async {
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      repo.fail();
      await _flush();
      expect(repo.calls, hasLength(1));

      net.reconnect();
      await _flush();
      expect(repo.calls, hasLength(2));
      expect(repo.calls.last, (point: _gps, radiusM: 1000));
      repo.fail(); // auto retry fails (e.g. HTTP 500)
      await _flush();
      expect(c.hasError, isTrue);

      net.reconnect();
      await _flush();
      expect(repo.calls, hasLength(2)); // no further automatic retries

      c.retry(); // manual Retry still works
      repo.complete(_lots(2));
      await _flush();
      expect(repo.calls, hasLength(3));
      expect(c.hasError, isFalse);
    });

    test('TC-1.2.4 step 3/4: manual Retry offline fails, reconnect still '
        'retries once', () async {
      c.onSearchTrigger(_gps, SearchTrigger.myLocation);
      repo.fail();
      await _flush();
      c.retry();
      repo.fail();
      await _flush();
      net.reconnect();
      await _flush();
      expect(repo.calls, hasLength(3));
      repo.complete(_lots(1));
      await _flush();
      expect(c.hasError, isFalse);
    });

    test('TC-1.2.13: no automatic retry on HTTP errors without a '
        'connectivity change; none when not in error', () async {
      repo
        ..hold = false
        ..error = const FormatException('HTTP 500');
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      await _flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.calls, hasLength(1));
      expect(c.hasError, isTrue);

      repo.error = null;
      c.retry();
      await _flush();
      expect(c.hasError, isFalse);
      net.reconnect(); // not in error → nothing
      await _flush();
      expect(repo.calls, hasLength(2));
    });

    test('TC-1.2.29: Retry and auto retry after Expand repeat 3000 m; area '
        'search uses its own radius; a new trigger is 1000 m', () async {
      c.onCameraChanged(_camera(_gps, 15), hasGesture: false);
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      repo.complete(const []);
      await _flush();
      c.expand();
      repo.fail();
      await _flush();
      c.retry();
      expect(repo.calls.last, (point: _gps, radiusM: 3000));
      repo.fail();
      await _flush();
      net.reconnect();
      await _flush();
      expect(repo.calls.last, (point: _gps, radiusM: 3000));
      repo.complete(_lots(1));
      await _flush();

      final camera = _camera(_gps, 15);
      c.onCameraChanged(camera, hasGesture: true);
      c.searchThisArea();
      expect(repo.calls.last.radiusM, SearchAreaRule.radiusFor(camera));
      expect(repo.calls.last.radiusM, isNot(3000));
      repo.complete(_lots(1));
      await _flush();

      c.onSearchTrigger(_gps, SearchTrigger.myLocation);
      expect(repo.calls.last.radiusM, 1000);
    });
  });

  test('stale responses are ignored when a newer request started', () async {
    c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
    c.onSearchTrigger(_gps, SearchTrigger.myLocation);
    repo.complete(_lots(7), index: 1); // newer one first
    await _flush();
    expect(c.lots, hasLength(7));
    repo.complete(_lots(2), index: 0); // stale
    await _flush();
    expect(c.lots, hasLength(7));
    expect(c.currentRequest!.point, _gps);

    // A stale error does not show the banner either.
    c.onSearchTrigger(_centre, SearchTrigger.myLocation);
    c.onSearchTrigger(_gps, SearchTrigger.myLocation);
    repo.complete(_lots(3), index: 3);
    await _flush();
    repo.fail(index: 2);
    await _flush();
    expect(c.hasError, isFalse);
    expect(c.lots, hasLength(3));
  });

  group('AC9 / TC-1.2.23 cap hint', () {
    for (final (n, shown) in [(50, true), (49, false), (0, false)]) {
      test('$n lots → hint ${shown ? 'shown' : 'hidden'}', () async {
        c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
        repo.complete(_lots(n));
        await _flush();
        expect(c.showCapHint, shown);
      });
    }
  });

  group('AC6 "Search this area"', () {
    test('TC-1.2.5 / TC-1.2.15: chip after a pan > 30% width; pan/zoom never '
        'loads; tap → map centre, chip hides', () async {
      final start = _camera(_centre, 16);
      c.onCameraChanged(start, hasGesture: false);
      c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
      repo.complete(_lots(1));
      await _flush();

      final small = _panned(start, const Offset(80, 0)); // 20%
      c.onCameraChanged(small, hasGesture: true);
      expect(c.showSearchArea, isFalse);

      final far = _panned(start, const Offset(140, 0)); // 35%
      c.onCameraChanged(far, hasGesture: true);
      expect(c.showSearchArea, isTrue);
      expect(repo.calls, hasLength(1)); // no automatic load

      c.searchThisArea();
      expect(c.showSearchArea, isFalse);
      expect(repo.calls.last.point, far.center);
      expect(repo.calls.last.radiusM, SearchAreaRule.radiusFor(far));
      expect(c.currentRequest!.kind, LotsSearchKind.area);
    });

    test('TC-1.2.14 d/e/f: vertical pan and zoom thresholds', () async {
      final start = _camera(_centre, 16);
      c.onCameraChanged(start, hasGesture: false);
      c.onSearchTrigger(_centre, SearchTrigger.firstPosition);

      c.onCameraChanged(_panned(start, const Offset(0, 280)), hasGesture: true);
      expect(c.showSearchArea, isTrue);
      c.onCameraChanged(start, hasGesture: true); // back → chip hides
      expect(c.showSearchArea, isFalse);
      c.onCameraChanged(_camera(_centre, 16.5), hasGesture: true);
      expect(c.showSearchArea, isFalse);
      c.onCameraChanged(_camera(_centre, 17), hasGesture: true);
      expect(c.showSearchArea, isTrue);
    });

    test('programmatic camera moves (zoom-16 animation, follow) never show '
        'the chip', () async {
      c.onCameraChanged(_camera(_centre, 15), hasGesture: false);
      c.onSearchTrigger(_gps, SearchTrigger.firstPosition);
      // US-1.1 AC2 animation from zoom 15 at the default centre to 16.
      c.onCameraChanged(_camera(_centre, 15.5), hasGesture: false);
      c.onCameraChanged(_camera(_gps, 16), hasGesture: false);
      expect(c.showSearchArea, isFalse);
      // A small pan afterwards: still under the thresholds (zoom ref = 16).
      c.onCameraChanged(
          _panned(_camera(_gps, 16), const Offset(20, 0)), hasGesture: true);
      expect(c.showSearchArea, isFalse);
    });

    test('TC-1.2.33 (d): area search uses the map centre even outside the '
        'service area; (e) Retry keeps that point', () async {
      final outside = _camera(const LatLng(10.4800, 107.1000), 15);
      c.onCameraChanged(outside, hasGesture: true);
      c.searchThisArea();
      expect(repo.calls.last.point, const LatLng(10.4800, 107.1000));
      repo.fail();
      await _flush();
      c.retry();
      expect(repo.calls.last.point, const LatLng(10.4800, 107.1000));
    });

    test('a new trigger hides the chip and resets its reference', () async {
      final start = _camera(_centre, 16);
      c.onCameraChanged(start, hasGesture: false);
      c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
      final far = _panned(start, const Offset(200, 0));
      c.onCameraChanged(far, hasGesture: true);
      expect(c.showSearchArea, isTrue);
      c.onSearchTrigger(far.center, SearchTrigger.myLocation);
      expect(c.showSearchArea, isFalse);
    });
  });

  group('AC8 selection', () {
    test('select / clear; cleared when the lot is gone', () async {
      c.onSearchTrigger(_centre, SearchTrigger.firstPosition);
      final lots = _lots(3);
      repo.complete(lots);
      await _flush();
      c.select(lots[1]);
      expect(c.selectedLot!.id, 'l1');
      c.select(null);
      expect(c.selectedLot, isNull);

      c.select(lots[2]);
      c.onSearchTrigger(_gps, SearchTrigger.myLocation);
      repo.complete([lotAt('x', 10.35, 107.08)]);
      await _flush();
      expect(c.selectedLot, isNull);
    });
  });
}
