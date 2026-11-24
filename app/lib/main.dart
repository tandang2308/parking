import 'package:flutter/material.dart';

import 'config/tile_config.dart';
import 'features/map/base_tile_layer.dart';
import 'features/map/map_screen.dart';

void main() {
  runApp(ParkFinderApp(tileConfig: TileConfig.fromEnvironment()));
}

class ParkFinderApp extends StatelessWidget {
  const ParkFinderApp({
    super.key,
    required this.tileConfig,
    this.styleLoader = loadStyleFromNetwork,
  });

  final TileConfig tileConfig;
  final StyleLoader styleLoader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Brand name, not translated. Localisation (vi + en) is set up with
      // the first story that adds user-facing strings.
      title: 'ParkFinder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: MapScreen(tileConfig: tileConfig, styleLoader: styleLoader),
    );
  }
}
