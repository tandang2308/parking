import 'package:latlong2/latlong.dart';

import 'parking_lot.dart';

/// Source of nearby lots (SPEC-001 §5 `nearby_lots`).
abstract interface class LotsRepository {
  /// Lots within [radiusM] metres of [point], nearest first, at most
  /// [LotsRepository.maxLots] (BR-2). Throws [LotsLoadException] on failure.
  Future<List<ParkingLot>> nearbyLots({
    required LatLng point,
    required int radiusM,
  });

  /// SPEC-001 BR-2: the RPC returns at most 50 lots.
  static const int maxLots = 50;
}

/// Loading lots failed (no internet, HTTP/server error, timeout, config).
///
/// [reason] is a short technical tag for debug logs; it never contains
/// coordinates (NFR-6).
class LotsLoadException implements Exception {
  const LotsLoadException(this.reason);

  final String reason;

  @override
  String toString() => 'LotsLoadException($reason)';
}

/// SPEC-001 BR-10: coordinates are rounded to 4 decimals (~11 m) before
/// they leave the device.
double roundCoordinate(double value) =>
    double.parse(value.toStringAsFixed(4));

/// Used when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are not defined: the app
/// still starts, every load fails and the error banner is shown (US-1.2 AC5).
class UnconfiguredLotsRepository implements LotsRepository {
  const UnconfiguredLotsRepository();

  @override
  Future<List<ParkingLot>> nearbyLots({
    required LatLng point,
    required int radiusM,
  }) async =>
      throw const LotsLoadException('supabase-not-configured');
}
