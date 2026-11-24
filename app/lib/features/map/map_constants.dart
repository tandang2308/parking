import 'package:latlong2/latlong.dart';

/// Map camera constants from SPEC-001.
abstract final class MapConstants {
  /// SPEC-001 BR-5: default centre, Bãi Trước (Front Beach), Vũng Tàu.
  static const LatLng defaultCentre = LatLng(10.3460, 107.0740);

  /// SPEC-001 BR-5: initial zoom.
  static const double initialZoom = 15;

  /// Minimum zoom (ADR-0009 validation gate renders zoom 13–18).
  static const double minZoom = 13;
}
