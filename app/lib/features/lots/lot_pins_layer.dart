import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/generated/app_localizations.dart';
import 'lot_clustering.dart';
import 'lots_geo.dart';
import 'parking_lot.dart';

/// SPEC-001 BR-6 pin colours (red/amber are reserved for US-6.7).
abstract final class PinColors {
  static const Color motorbike = Color(0xFF2E7D32); // green
  static const Color car = Color(0xFF1565C0); // blue
  static const Color both = Color(0xFF6A1B9A); // purple
  static const Color cluster = Color(0xFF37474F); // neutral blue-grey

  static Color of(PinKind kind) => switch (kind) {
        PinKind.motorbike => motorbike,
        PinKind.car => car,
        PinKind.both => both,
      };
}

/// Lot pins and clusters (SPEC-001 US-1.2 AC2, AC7, AC8). Must be a child
/// of `FlutterMap`: it re-clusters on every camera change.
class LotPinsLayer extends StatelessWidget {
  const LotPinsLayer({
    super.key,
    required this.lots,
    required this.selectedId,
    required this.spiderfiedKey,
    required this.onLotTap,
    required this.onClusterTap,
  });

  final List<ParkingLot> lots;
  final String? selectedId;

  /// [LotCluster.key] of the fanned-out cluster (AC7), or `null`.
  final String? spiderfiedKey;
  final ValueChanged<ParkingLot> onLotTap;
  final void Function(LotCluster cluster, MapCamera camera) onClusterTap;

  /// NFR-8: touch targets ≥ 48 dp. The selected pin is enlarged (BR-6).
  static const double pinSize = 48;
  static const double selectedPinSize = 60;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final l10n = AppLocalizations.of(context);
    final clusters = LotClustering.cluster(
      lots,
      project: camera.projectAtZoom,
      zoom: camera.zoom,
    );

    final markers = <Marker>[];
    ParkingLot? selected;
    for (final c in clusters) {
      if (c.isSingle) {
        final lot = c.lots.single;
        if (lot.id == selectedId) {
          selected = lot; // drawn last, on top
        } else {
          markers.add(_pinMarker(lot, l10n, false, lot.position));
        }
      } else if (c.key == spiderfiedKey) {
        final centrePx = camera.projectAtZoom(c.centre);
        final offsets = LotClustering.spiderOffsets(c.lots.length);
        for (var i = 0; i < c.lots.length; i++) {
          final lot = c.lots[i];
          markers.add(_pinMarker(
            lot,
            l10n,
            lot.id == selectedId,
            camera.unprojectAtZoom(centrePx + offsets[i]),
          ));
        }
      } else {
        markers.add(Marker(
          key: ValueKey('lot-cluster-${c.key}'),
          point: c.centre,
          width: pinSize,
          height: pinSize,
          child: _ClusterIcon(
            count: c.lots.length,
            label: l10n.a11y_cluster(c.lots.length),
            onTap: () => onClusterTap(c, camera),
          ),
        ));
      }
    }
    if (selected != null) {
      markers.add(_pinMarker(selected, l10n, true, selected.position));
    }
    return MarkerLayer(markers: markers);
  }

  Marker _pinMarker(
    ParkingLot lot,
    AppLocalizations l10n,
    bool isSelected,
    LatLng point,
  ) {
    final size = isSelected ? selectedPinSize : pinSize;
    return Marker(
      key: ValueKey('lot-pin-${lot.id}'),
      point: point,
      width: size,
      height: size,
      child: LotPin(
        kind: lot.pinKind,
        selected: isSelected,
        label: l10n.a11y_pin(lot.name, vehicleTypesLabel(lot, l10n)),
        onTap: () => onLotTap(lot),
      ),
    );
  }
}

/// One lot pin: BR-6 icon + colour; enlarged when selected.
class LotPin extends StatelessWidget {
  const LotPin({
    super.key,
    required this.kind,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final PinKind kind;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PinColors.of(kind);
    final diameter = selected ? 44.0 : 32.0;
    final iconSize = selected ? 24.0 : 18.0;
    final Widget icon = switch (kind) {
      PinKind.motorbike => Icon(Icons.two_wheeler, size: iconSize, color: Colors.white),
      PinKind.car => Icon(Icons.directions_car, size: iconSize, color: Colors.white),
      PinKind.both => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.two_wheeler, size: iconSize * 0.7, color: Colors.white),
            Icon(Icons.directions_car, size: iconSize * 0.7, color: Colors.white),
          ],
        ),
    };
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: selected ? 3 : 2),
              boxShadow: const [
                BoxShadow(blurRadius: 3, color: Color(0x55000000)),
              ],
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _ClusterIcon extends StatelessWidget {
  const _ClusterIcon({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PinColors.cluster,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(blurRadius: 3, color: Color(0x55000000)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
