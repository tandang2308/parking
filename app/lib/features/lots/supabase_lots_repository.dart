import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lots_repository.dart';
import 'parking_lot.dart';

/// [LotsRepository] backed by the Supabase RPC `nearby_lots` (SPEC-001 §5).
///
/// `rpc()` sends `POST /rest/v1/rpc/nearby_lots` with the parameters in the
/// JSON body, never in the URL (BR-10). Coordinates are rounded to 4
/// decimals (BR-10) and never logged (NFR-6).
class SupabaseLotsRepository implements LotsRepository {
  SupabaseLotsRepository(this._client, {this.timeout = defaultTimeout});

  final SupabaseClient _client;

  /// A request without an answer after [timeout] counts as failed (AC5).
  final Duration timeout;

  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Builds the RPC parameters (BR-10 rounding). Visible for tests.
  static Map<String, dynamic> paramsFor(LatLng point, int radiusM) => {
        'lat': roundCoordinate(point.latitude),
        'lng': roundCoordinate(point.longitude),
        'radius_m': radiusM,
        // Filter UI is E2 (SPEC-002); null = all vehicle types.
        'vehicle_type': null,
      };

  @override
  Future<List<ParkingLot>> nearbyLots({
    required LatLng point,
    required int radiusM,
  }) async {
    final Object? data;
    try {
      data = await _client
          .rpc<dynamic>('nearby_lots', params: paramsFor(point, radiusM))
          .timeout(timeout);
    } on TimeoutException {
      throw const LotsLoadException('timeout');
    } on PostgrestException catch (e) {
      // HTTP/server error; the code only, no request body (NFR-6).
      throw LotsLoadException('postgrest-${e.code}');
    } catch (e) {
      // Offline / DNS / socket errors.
      throw LotsLoadException('network-${e.runtimeType}');
    }
    if (data is! List) throw const LotsLoadException('bad-response');
    try {
      return [
        for (final row in data) ParkingLot.fromRpc(row as Map<String, dynamic>),
      ];
    } catch (_) {
      throw const LotsLoadException('bad-response');
    }
  }
}
