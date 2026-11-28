import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'parking_lot.dart';

/// A group of lots drawn as one marker (SPEC-001 US-1.2 AC7, BR-4).
class LotCluster {
  LotCluster(this.lots);

  final List<ParkingLot> lots;

  bool get isSingle => lots.length == 1;

  /// Mean position of the members.
  LatLng get centre {
    var lat = 0.0, lng = 0.0;
    for (final l in lots) {
      lat += l.position.latitude;
      lng += l.position.longitude;
    }
    return LatLng(lat / lots.length, lng / lots.length);
  }

  /// Stable key: the member ids.
  String get key => (lots.map((l) => l.id).toList()..sort()).join('|');
}

/// SPEC-001 BR-4 clustering rules.
///
/// Implemented in-app because `flutter_map_marker_cluster` 8.2.2 requires
/// `latlong2 ^0.9.1`, while the app uses `latlong2 ^0.10.1`.
abstract final class LotClustering {
  /// Below this zoom, markers closer than [wideRadiusPx] are clustered.
  static const double detailZoom = 17;
  static const double wideRadiusPx = 60;

  /// At zoom ≥ [detailZoom] only markers that still overlap stay clustered.
  static const double overlapRadiusPx = 20;

  static double radiusForZoom(double zoom) =>
      zoom < detailZoom ? wideRadiusPx : overlapRadiusPx;

  /// Greedy clustering in screen pixels at [zoom]. [lots] are nearest
  /// first (RPC order); each unassigned lot seeds a cluster with every
  /// unassigned lot closer than the radius.
  static List<LotCluster> cluster(
    List<ParkingLot> lots, {
    required Offset Function(LatLng) project,
    required double zoom,
  }) {
    final radius = radiusForZoom(zoom);
    final points = [for (final l in lots) project(l.position)];
    final assigned = List<bool>.filled(lots.length, false);
    final result = <LotCluster>[];
    for (var i = 0; i < lots.length; i++) {
      if (assigned[i]) continue;
      assigned[i] = true;
      final members = [lots[i]];
      for (var j = i + 1; j < lots.length; j++) {
        if (!assigned[j] && (points[j] - points[i]).distance < radius) {
          assigned[j] = true;
          members.add(lots[j]);
        }
      }
      result.add(LotCluster(members));
    }
    return result;
  }

  /// AC7 "tapping the cluster zooms in until the pins separate": the zoom
  /// at which the members' pixel extent fills about half the viewport, at
  /// least one level deeper, at most [maxZoom].
  static ({LatLng centre, double zoom}) zoomTarget(
    LotCluster cluster,
    MapCamera camera, {
    required double maxZoom,
  }) {
    final pts = [for (final l in cluster.lots) camera.projectAtZoom(l.position)];
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    final extent = math.max(maxX - minX, maxY - minY);
    final size = camera.nonRotatedSize;
    final target = math.min(size.width, size.height) / 2;
    var zoom = extent > 0
        ? camera.zoom + math.log(target / extent) / math.ln2
        : maxZoom;
    if (!zoom.isFinite) zoom = maxZoom;
    zoom = math.min(maxZoom, math.max(camera.zoom + 1, zoom));
    return (centre: cluster.centre, zoom: zoom);
  }

  /// AC7 spiderfy: fan [count] members around [centrePx] so 48 dp touch
  /// targets do not overlap (NFR-8). Returns pixel offsets.
  static List<Offset> spiderOffsets(int count, {double targetPx = 48}) {
    final radius = math.max(40.0, count * targetPx / (2 * math.pi) + 8);
    return [
      for (var i = 0; i < count; i++)
        Offset.fromDirection(-math.pi / 2 + 2 * math.pi * i / count, radius),
    ];
  }
}
