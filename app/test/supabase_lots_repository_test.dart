import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/features/lots/lots_repository.dart';
import 'package:parkfinder/features/lots/parking_lot.dart';
import 'package:parkfinder/features/lots/supabase_lots_repository.dart';
import 'package:supabase/supabase.dart';

/// SPEC-001 §5 RPC contract, BR-10 (TC-1.2.9 automated part): POST body
/// only, 4-decimal rounding, nothing in the URL. No real network.

void main() {
  final requests = <http.Request>[];
  SupabaseClient? client;

  SupabaseLotsRepository repoWith(MockClientHandler handler) {
    requests.clear();
    final c = client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return SupabaseLotsRepository(c);
  }

  tearDown(() async {
    await client?.dispose();
    client = null;
  });

  test('TC-1.2.9: POST /rest/v1/rpc/nearby_lots, coordinates rounded to 4 '
      'decimals in the body only', () async {
    final repo = repoWith((_) async => http.Response(
          jsonEncode([
            {
              'id': '5b1c',
              'name': 'Bãi giữ xe Quang Trung',
              'address': 'Quang Trung, Vũng Tàu',
              'lot_lat': 10.3466,
              'lot_lng': 107.0752,
              'vehicle_types': ['motorbike', 'car'],
              'is_verified': false,
              'distance_m': 145,
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: requests.last,
        ));

    final lots = await repo.nearbyLots(
      point: const LatLng(10.346012, 107.074056),
      radiusM: 1000,
    );

    final r = requests.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/rest/v1/rpc/nearby_lots');
    expect(r.url.query, isEmpty);
    expect(r.url.toString(), isNot(contains('10.34')));
    for (final h in r.headers.values) {
      expect(h, isNot(contains('10.34')));
      expect(h, isNot(contains('107.07')));
    }
    expect(jsonDecode(r.body), {
      'lat': 10.346,
      'lng': 107.0741,
      'radius_m': 1000,
      'vehicle_type': null,
    });

    expect(lots.single.name, 'Bãi giữ xe Quang Trung');
    expect(lots.single.pinKind, PinKind.both);
  });

  test('AC5: HTTP 500 → LotsLoadException', () async {
    final repo = repoWith((_) async => http.Response(
          jsonEncode({'message': 'boom', 'code': 'XX000'}),
          500,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ));
    await expectLater(
      repo.nearbyLots(point: const LatLng(10.346, 107.074), radiusM: 1000),
      throwsA(isA<LotsLoadException>()),
    );
  });

  test('AC5 / TC-1.2.13: HTTP 503 is not retried by the client library '
      '(POST)', () async {
    final repo = repoWith((_) async => http.Response(
          jsonEncode({'message': 'unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ));
    await expectLater(
      repo.nearbyLots(point: const LatLng(10.346, 107.074), radiusM: 1000),
      throwsA(isA<LotsLoadException>()),
    );
    expect(requests, hasLength(1));
  });

  test('AC5: offline (client exception) → LotsLoadException', () async {
    final repo = repoWith((_) async => throw http.ClientException('offline'));
    await expectLater(
      repo.nearbyLots(point: const LatLng(10.346, 107.074), radiusM: 1000),
      throwsA(isA<LotsLoadException>()),
    );
  });

  test('malformed response → LotsLoadException', () async {
    final repo = repoWith((_) async => http.Response(
          jsonEncode([
            {'id': 1},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ));
    await expectLater(
      repo.nearbyLots(point: const LatLng(10.346, 107.074), radiusM: 1000),
      throwsA(isA<LotsLoadException>()),
    );
  });

  test('missing config → every load fails (app still starts)', () async {
    await expectLater(
      const UnconfiguredLotsRepository()
          .nearbyLots(point: const LatLng(10.346, 107.074), radiusM: 1000),
      throwsA(isA<LotsLoadException>()),
    );
  });
}
