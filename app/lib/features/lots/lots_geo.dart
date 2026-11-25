import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/generated/app_localizations.dart';
import 'parking_lot.dart';

/// Mean Earth radius (IUGG), metres.
const double _earthRadiusM = 6371008.8;

/// SPEC-001 BR-11: client-side haversine distance in metres.
double haversineMetres(LatLng a, LatLng b) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// SPEC-001 BR-15 (D3): round to the nearest 10 m (minimum 10 m); below
/// 1000 m show metres, otherwise km with one decimal and the locale's
/// decimal separator (vi "1,2 km", en "1.2 km").
String formatDistance(double metres, AppLocalizations l10n) {
  final rounded = math.max(10, (metres / 10).round() * 10);
  if (rounded < 1000) return l10n.distance_m(rounded);
  // Whole tenths of a km, half up (integer maths, no float artefacts).
  final tenths = (rounded / 100).round();
  final km = NumberFormat('0.0', l10n.localeName).format(tenths / 10);
  return l10n.distance_km(km);
}

/// "Xe máy, Ô tô" / "Motorbike, Car" for the card and `a11y_pin`.
String vehicleTypesLabel(ParkingLot lot, AppLocalizations l10n) => [
      if (lot.vehicleTypes.contains(VehicleType.motorbike))
        l10n.vehicle_motorbike,
      if (lot.vehicleTypes.contains(VehicleType.car)) l10n.vehicle_car,
    ].join(', ');

/// SPEC-001 BR-3 "Search this area" thresholds.
abstract final class SearchAreaRule {
  /// Pan threshold, share of the viewport width / height.
  static const double panShare = 0.30;

  /// Zoom change (levels) that shows the chip.
  static const double zoomDelta = 1;

  /// Area-search radius clamp, metres.
  static const int minRadiusM = 300;
  static const int maxRadiusM = 5000;

  /// Whether the chip appears: the map centre moved (screen pixels) more
  /// than 30% of the viewport width horizontally or 30% of its height
  /// vertically from the last search centre, or the zoom changed ≥ 1.
  static bool exceeded({
    required Offset centreShiftPx,
    required Size viewport,
    required double zoomChange,
  }) =>
      centreShiftPx.dx.abs() > panShare * viewport.width ||
      centreShiftPx.dy.abs() > panShare * viewport.height ||
      zoomChange.abs() >= zoomDelta;

  /// [exceeded] for a camera vs. the last search centre / zoom.
  static bool exceededFor(
    MapCamera camera, {
    required LatLng searchCentre,
    required double searchZoom,
  }) =>
      exceeded(
        centreShiftPx: camera.projectAtZoom(camera.center) -
            camera.projectAtZoom(searchCentre),
        viewport: camera.nonRotatedSize,
        zoomChange: camera.zoom - searchZoom,
      );

  /// Half the visible diagonal, clamped to [300, 5000] m.
  static int radiusFor(MapCamera camera) {
    final b = camera.visibleBounds;
    final diagonal = haversineMetres(b.northWest, b.southEast);
    return (diagonal / 2).round().clamp(minRadiusM, maxRadiusM);
  }
}
