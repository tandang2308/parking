import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../config/tile_config.dart';
import 'base_tile_layer.dart';
import 'map_attribution.dart';
import 'map_constants.dart';

/// Full-screen map centred on the SPEC-001 BR-5 default centre.
///
/// No location and no lots yet (US-1.1 / US-1.2). An optional [banner] is
/// shown in the top banner area (SPEC-001 §3, S2).
class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.tileConfig,
    this.styleLoader = loadStyleFromNetwork,
    this.banner,
  });

  final TileConfig tileConfig;
  final StyleLoader styleLoader;

  /// Banner shown at the top of the map (max one at a time, SPEC-001 §3).
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final banner = this.banner;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
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
          if (banner != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: banner,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
