import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/config/supabase_config.dart';
import 'package:parkfinder/features/lots/lot_clustering.dart';
import 'package:parkfinder/features/lots/lot_placeholder_screen.dart';
import 'package:parkfinder/features/lots/lots_geo.dart';
import 'package:parkfinder/features/lots/lots_repository.dart';
import 'package:parkfinder/features/lots/parking_lot.dart';
import 'package:parkfinder/features/map/map_constants.dart';
import 'package:parkfinder/l10n/generated/app_localizations.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.2 unit tests: BR-15 formatter (TC-1.2.27), BR-11
/// haversine, BR-3 thresholds (TC-1.2.14), BR-14 search point (TC-1.2.33),
/// BR-10 rounding (TC-1.2.9), BR-4 clustering, BR-6 pin kind.

MapCamera _camera(LatLng centre, double zoom, {Size size = const Size(400, 800)}) =>
    MapCamera(
      crs: const Epsg3857(),
      center: centre,
      zoom: zoom,
      rotation: 0,
      nonRotatedSize: size,
    );

/// [camera]'s centre moved by [px] screen pixels.
LatLng _shifted(MapCamera camera, Offset px) =>
    camera.unprojectAtZoom(camera.projectAtZoom(camera.center) + px);

void main() {
  group('TC-1.2.27 BR-15 distance format', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final vi = lookupAppLocalizations(const Locale('vi'));
    const cases = <int, String>{
      0: '10 m',
      4: '10 m',
      14: '10 m',
      16: '20 m',
      344: '340 m',
      345: '350 m',
      346: '350 m',
      994: '990 m',
      995: '1.0 km',
      1000: '1.0 km',
      1234: '1.2 km',
      1500: '1.5 km',
      9940: '9.9 km',
      62900: '62.9 km',
      95300: '95.3 km',
    };
    for (final entry in cases.entries) {
      test('${entry.key} m → en "${entry.value}", vi with decimal comma', () {
        final m = entry.key.toDouble();
        expect(formatDistance(m, en), entry.value);
        expect(formatDistance(m, vi), entry.value.replaceAll('.', ','));
      });
    }
    test('vi examples from the spec', () {
      expect(formatDistance(1000, vi), '1,0 km');
      expect(formatDistance(1234, vi), '1,2 km');
      expect(formatDistance(95300, vi), '95,3 km');
      expect(formatDistance(350, vi), '350 m');
    });
  });

  group('BR-11 haversine', () {
    test('zero and a known short distance', () {
      const p = LatLng(10.3460, 107.0740);
      expect(haversineMetres(p, p), 0);
      // 0.001° latitude ≈ 111.2 m.
      expect(haversineMetres(p, const LatLng(10.3470, 107.0740)),
          closeTo(111.2, 0.5));
    });

    test('TC-1.2.24: MP-6 (HCMC) → MP-1 is about 63 km', () {
      final d = haversineMetres(
        MockPoints.mp6.position,
        MockPoints.mp1.position,
      );
      expect(d, inInclusiveRange(62000, 64000));
    });
  });

  group('TC-1.2.14 BR-3 "Search this area" thresholds', () {
    const viewport = Size(400, 800);
    bool exceeded({double dx = 0, double dy = 0, double zoom = 0}) =>
        SearchAreaRule.exceeded(
          centreShiftPx: Offset(dx, dy),
          viewport: viewport,
          zoomChange: zoom,
        );

    test('a) pan 20% width → no chip', () => expect(exceeded(dx: 80), isFalse));
    test('b) pan 35% width → chip', () => expect(exceeded(dx: -140), isTrue));
    test('c) pan 20% height → no chip', () => expect(exceeded(dy: 160), isFalse));
    test('d) pan 35% height → chip', () => expect(exceeded(dy: -280), isTrue));
    test('e) zoom +0.5 → no chip', () => expect(exceeded(zoom: 0.5), isFalse));
    test('f) zoom +1 / -1 → chip', () {
      expect(exceeded(zoom: 1), isTrue);
      expect(exceeded(zoom: -1), isTrue);
    });
    test('exactly 30% is not "more than 30%"', () {
      expect(exceeded(dx: 120), isFalse);
      expect(exceeded(dy: 240), isFalse);
    });

    test('exceededFor uses screen pixels of the current camera', () {
      final camera = _camera(MapConstants.defaultCentre, 16);
      final moved = _camera(_shifted(camera, const Offset(140, 0)), 16);
      expect(
        SearchAreaRule.exceededFor(moved,
            searchCentre: MapConstants.defaultCentre, searchZoom: 16),
        isTrue,
      );
      final small = _camera(_shifted(camera, const Offset(0, 100)), 16);
      expect(
        SearchAreaRule.exceededFor(small,
            searchCentre: MapConstants.defaultCentre, searchZoom: 16),
        isFalse,
      );
    });

    test('g) visible diagonal > 10 km → radius 5000', () {
      final camera = _camera(MapConstants.defaultCentre, 13);
      final b = camera.visibleBounds;
      expect(haversineMetres(b.northWest, b.southEast), greaterThan(10000));
      expect(SearchAreaRule.radiusFor(camera), 5000);
    });

    test('h) visible diagonal < 600 m → radius 300', () {
      final camera = _camera(MapConstants.defaultCentre, 18);
      final b = camera.visibleBounds;
      expect(haversineMetres(b.northWest, b.southEast), lessThan(600));
      expect(SearchAreaRule.radiusFor(camera), 300);
    });

    test('otherwise radius = half the visible diagonal', () {
      final camera = _camera(MapConstants.defaultCentre, 15);
      final b = camera.visibleBounds;
      final half = haversineMetres(b.northWest, b.southEast) / 2;
      expect(half, inExclusiveRange(300, 5000));
      expect(SearchAreaRule.radiusFor(camera), half.round());
    });
  });

  group('TC-1.2.33 BR-14 search point (position-based triggers)', () {
    test('inside → the position itself', () {
      const p = LatLng(10.35, 107.08);
      expect(ServiceArea.searchPointFor(p), p);
    });
    test('on an edge → inside (BR-12 inclusive)', () {
      for (final p in const [
        LatLng(10.30, 107.10),
        LatLng(10.45, 107.10),
        LatLng(10.40, 107.03),
        LatLng(10.40, 107.20),
        LatLng(10.45, 107.20),
      ]) {
        expect(ServiceArea.searchPointFor(p), p);
      }
    });
    test('outside → default centre', () {
      expect(ServiceArea.searchPointFor(MockPoints.mp6.position),
          MapConstants.defaultCentre);
      expect(ServiceArea.searchPointFor(const LatLng(10.4501, 107.10)),
          MapConstants.defaultCentre);
    });
    // (d) area search = map centre and (e) Retry/Expand = same point are
    // covered in lots_controller_test.dart.
  });

  group('TC-1.2.9 BR-10 rounding to 4 decimals', () {
    test('10.346012, 107.074056 → 10.3460, 107.0741', () {
      expect(roundCoordinate(10.346012), 10.346);
      expect(roundCoordinate(107.074056), 107.0741);
      expect(roundCoordinate(-33.123456), -33.1235);
    });
  });

  group('BR-4 clustering', () {
    Offset project(LatLng p) => Offset(p.longitude * 1e5, p.latitude * 1e5);

    test('below zoom 17: markers < 60 px apart are clustered', () {
      final lots = [
        lotAt('a', 0, 0),
        lotAt('b', 0, 0.00050), // 50 px
        lotAt('c', 0, 0.00070), // 70 px from a, 20 px from b
        lotAt('d', 0, 0.00200), // 200 px
      ];
      final clusters =
          LotClustering.cluster(lots, project: project, zoom: 16);
      expect(clusters.map((c) => c.lots.map((l) => l.id).join()).toList(),
          ['ab', 'c', 'd']);
    });

    test('at zoom ≥ 17 only markers < 20 px apart stay clustered', () {
      final lots = [
        lotAt('a', 0, 0),
        lotAt('b', 0, 0.00050), // 50 px
        lotAt('c', 0, 0.00051), // 1 px from b
        lotAt('d', 0, 0.00051), // identical to c
      ];
      final clusters =
          LotClustering.cluster(lots, project: project, zoom: 17);
      expect(clusters.map((c) => c.lots.map((l) => l.id).join()).toList(),
          ['a', 'bcd']);
    });

    test('cluster tap zoom target: deeper, capped at max zoom 18', () {
      final camera = _camera(MapConstants.defaultCentre, 15);
      final near = LotCluster([
        lotAt('a', 10.3460, 107.0740),
        lotAt('b', 10.3461, 107.0741),
      ]);
      final t = LotClustering.zoomTarget(near, camera, maxZoom: 18);
      expect(t.zoom, greaterThanOrEqualTo(16));
      expect(t.zoom, lessThanOrEqualTo(18));

      final identical = LotCluster([
        lotAt('a', 10.3460, 107.0740),
        lotAt('b', 10.3460, 107.0740),
      ]);
      expect(LotClustering.zoomTarget(identical, camera, maxZoom: 18).zoom, 18);
    });

    test('spiderfy offsets do not overlap 48 dp targets', () {
      for (final n in [2, 3, 8, 12]) {
        final offsets = LotClustering.spiderOffsets(n);
        expect(offsets, hasLength(n));
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            expect((offsets[i] - offsets[j]).distance,
                greaterThanOrEqualTo(48 - 1e-6));
          }
        }
      }
    });
  });

  group('BR-6 pin kind and RPC parsing', () {
    test('motorbike / car / both', () {
      expect(lotAt('a', 0, 0, types: {VehicleType.motorbike}).pinKind,
          PinKind.motorbike);
      expect(lotAt('a', 0, 0, types: {VehicleType.car}).pinKind, PinKind.car);
      expect(lotAt('a', 0, 0).pinKind, PinKind.both);
    });

    test('fromRpc parses the SPEC-001 §5 example row', () {
      final lot = ParkingLot.fromRpc({
        'id': '5b1c',
        'name': 'Bãi giữ xe Quang Trung',
        'address': 'Quang Trung, Vũng Tàu',
        'lot_lat': 10.3466,
        'lot_lng': 107.0752,
        'vehicle_types': ['motorbike', 'car'],
        'is_verified': false,
        'distance_m': 145,
      });
      expect(lot.id, '5b1c');
      expect(lot.position, const LatLng(10.3466, 107.0752));
      expect(lot.pinKind, PinKind.both);
      expect(lot.distanceM, 145);
      expect(() => ParkingLot.fromRpc({'id': 1}), throwsFormatException);
    });
  });

  group('config and routes', () {
    test('Supabase config is optional; missing values are detected', () {
      expect(const SupabaseConfig(url: '', anonKey: '').isConfigured, isFalse);
      expect(const SupabaseConfig(url: 'https://x.supabase.co', anonKey: '')
          .isConfigured, isFalse);
      expect(const SupabaseConfig(url: 'not a url', anonKey: 'k').isConfigured,
          isFalse);
      const ok = SupabaseConfig(url: 'https://x.supabase.co/', anonKey: 'k');
      expect(ok.isConfigured, isTrue);
      expect(ok.normalizedUrl, 'https://x.supabase.co');
      // No defines in the test run: the app falls back (AC5 error banner).
      expect(SupabaseConfig.fromEnvironment().isConfigured, isFalse);
    });

    test('/lot/:id route', () {
      expect(LotPlaceholderScreen.routeFor('abc'), '/lot/abc');
      expect(LotPlaceholderScreen.idFromRoute('/lot/abc'), 'abc');
      expect(LotPlaceholderScreen.idFromRoute('/lot/'), isNull);
      expect(LotPlaceholderScreen.idFromRoute('/'), isNull);
      expect(LotPlaceholderScreen.idFromRoute(null), isNull);
    });
  });
}
