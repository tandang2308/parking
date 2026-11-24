import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import '../../config/tile_config.dart';

/// Loads a MapLibre style. Injectable so tests never touch the network.
typedef StyleLoader = Future<vt.Style> Function(String styleUrl);

/// Default loader: fetches the style, TileJSON, sprites and glyphs over
/// HTTPS. On Android/iOS the style bundle is cached on disk by the package;
/// on web the browser HTTP cache applies.
Future<vt.Style> loadStyleFromNetwork(String styleUrl) =>
    vt.StyleReader(uri: styleUrl).read();

/// The single switch point between vector and raster base layers
/// (ADR-0009 decision 3). Everything else on the map is renderer-agnostic.
Widget buildBaseTileLayer(
  TileConfig config, {
  StyleLoader styleLoader = loadStyleFromNetwork,
}) {
  switch (config.renderer) {
    case TileRenderer.vector:
      return VectorBaseLayer(
        styleUrl: config.styleUrl,
        styleLoader: styleLoader,
      );
    case TileRenderer.raster:
      return RasterBaseLayer(urlTemplate: config.rasterUrlTemplate);
  }
}

/// On-device tile disk cache TTL for vector tiles (SPEC-001 NFR-3a: >= 7 days).
const Duration vectorTileDiskCacheTtl = Duration(days: 14);

/// Vector base layer: loads the style once, then renders
/// `flutter_map_vector_tiles`' [vt.VectorTileLayer].
class VectorBaseLayer extends StatefulWidget {
  const VectorBaseLayer({
    super.key,
    required this.styleUrl,
    this.styleLoader = loadStyleFromNetwork,
  });

  final String styleUrl;
  final StyleLoader styleLoader;

  @override
  State<VectorBaseLayer> createState() => _VectorBaseLayerState();
}

class _VectorBaseLayerState extends State<VectorBaseLayer> {
  vt.Style? _style;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stopwatch = Stopwatch()..start();
    try {
      final style = await widget.styleLoader(widget.styleUrl);
      if (!kReleaseMode) {
        // Spike aid (ADR-0009 gate): duration only, never coordinates.
        debugPrint('Map style loaded in ${stopwatch.elapsedMilliseconds} ms');
      }
      if (!mounted) {
        style.dispose();
        return;
      }
      setState(() => _style = style);
    } catch (error) {
      // No coordinates are ever part of this message (PDPL, SPEC-001 BR-10).
      debugPrint('Map style failed to load: $error');
    }
  }

  @override
  void dispose() {
    _style?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      // Style still loading (or failed): the map background shows through.
      return const SizedBox.shrink();
    }
    return vt.VectorTileLayer(
      theme: style.theme,
      tileProviders: style.providers,
      rasterSources: style.rasterSources,
      sprites: style.sprites,
      glyphs: style.glyphs,
      diskCacheTtl: vectorTileDiskCacheTtl,
    );
  }
}

/// Raster base layer (ADR-0009 fallback 4a). Requires `TILE_RASTER_URL`.
class RasterBaseLayer extends StatelessWidget {
  const RasterBaseLayer({super.key, required this.urlTemplate});

  final String urlTemplate;

  @override
  Widget build(BuildContext context) {
    if (urlTemplate.isEmpty) {
      debugPrint('TILE_RENDERER=raster but TILE_RASTER_URL is empty.');
      return const SizedBox.shrink();
    }
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: 'vn.parkfinder.parkfinder',
    );
  }
}
