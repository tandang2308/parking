import 'package:latlong2/latlong.dart';

/// Map camera constants from SPEC-001.
abstract final class MapConstants {
  /// SPEC-001 BR-5: default centre, Bãi Trước (Front Beach), Vũng Tàu.
  static const LatLng defaultCentre = LatLng(10.3460, 107.0740);

  /// SPEC-001 BR-5: initial zoom (also "Go to Vũng Tàu", US-1.1 AC10).
  static const double initialZoom = 15;

  /// SPEC-001 US-1.1 AC2/AC8: zoom when centring on the user.
  static const double userZoom = 16;

  /// Minimum zoom (ADR-0009 validation gate renders zoom 13–18).
  static const double minZoom = 13;
}

/// SPEC-001 BR-12: Vũng Tàu service area bounding box, edges inclusive.
abstract final class ServiceArea {
  static const double minLat = 10.30;
  static const double maxLat = 10.45;
  static const double minLng = 107.03;
  static const double maxLng = 107.20;

  /// Whether [p] is inside the service area (a point on an edge is inside).
  static bool contains(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLng &&
      p.longitude <= maxLng;

  /// SPEC-001 BR-14 (D4): search point for position-based triggers —
  /// the position itself if inside the area, otherwise the default centre.
  static LatLng searchPointFor(LatLng position) =>
      contains(position) ? position : MapConstants.defaultCentre;
}
