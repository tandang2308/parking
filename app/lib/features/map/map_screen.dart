import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../config/tile_config.dart';
import 'base_tile_layer.dart';
import 'map_attribution.dart';
import 'map_constants.dart';

/// Full-screen map centred on the SPEC-001 BR-5 default centre.
///
/// Sprint 1 spike scope (ADR-0009 validation gate) only: no location, no
/// lots, no UI chrome yet (US-1.x stories come later).
class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.tileConfig,
    this.styleLoader = loadStyleFromNetwork,
  });

  final TileConfig tileConfig;
  final StyleLoader styleLoader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          initialCenter: MapConstants.defaultCentre,
          initialZoom: MapConstants.initialZoom,
          minZoom: MapConstants.minZoom,
          maxZoom: tileConfig.maxZoom,
        ),
        children: [
          buildBaseTileLayer(tileConfig, styleLoader: styleLoader),
          // SPEC-001 BR-13: attribution always visible, text from config.
          MapAttribution(
            key: const ValueKey('map-attribution'),
            text: tileConfig.attribution,
          ),
        ],
      ),
    );
  }
}
