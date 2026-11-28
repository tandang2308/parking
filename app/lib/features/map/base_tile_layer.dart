import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../config/tile_config.dart';
import 'style_label_client.dart';

/// Loads a MapLibre style; [languageCode] is the app locale for the map
/// labels (SPEC-001 BR-17). Injectable so tests never touch the network.
typedef StyleLoader = Future<vt.Style> Function(
  String styleUrl,
  String languageCode,
);

/// Default loader: fetches the style, TileJSON, sprites and glyphs over
/// HTTPS. On Android/iOS the style bundle is cached on disk by the package;
/// on web the browser HTTP cache applies.
///
/// BR-17: the style document is rewritten for [languageCode] as it is
/// downloaded ([StyleLabelClient]). The package caches the document as
/// our client returned it, so each language gets its own style cache
/// folder: a locale change applies on the next style load, never a stale
/// copy in the previous language.
Future<vt.Style> loadStyleFromNetwork(
  String styleUrl,
  String languageCode,
) async {
  final client = StyleLabelClient(
    inner: http.Client(),
    styleUrl: styleUrl,
    languageCode: languageCode,
  );
  try {
    final style = await vt.StyleReader(
      uri: styleUrl,
      httpClient: client,
      // Web has no style disk cache (the package ignores cachePath there).
      cachePath: kIsWeb ? null : () => _styleCacheFolder(languageCode),
    ).read();
    return _ClientOwningStyle(style, client);
  } catch (_) {
    client.close();
    rethrow;
  }
}

Future<String> _styleCacheFolder(String languageCode) async =>
    '${(await getApplicationSupportDirectory()).path}'
    '/flutter_map_vector_tiles/style-$languageCode';

/// A caller-supplied client is not closed by the package: it stays in use
/// for glyph ranges while the map is shown, so it is closed with the style.
class _ClientOwningStyle extends vt.Style {
  _ClientOwningStyle(vt.Style style, this._client)
      : super(
          theme: style.theme,
          providers: style.providers,
          rasterSources: style.rasterSources,
          sprites: style.sprites,
          glyphs: style.glyphs,
          center: style.center,
          zoom: style.zoom,
          name: style.name,
          attributions: style.attributions,
        );

  final http.Client _client;

  @override
  void dispose() {
    super.dispose();
    _client.close();
  }
}

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
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The locale is only readable once dependencies are available. The
    // style is loaded once per layer: a later locale change applies on the
    // next map/style load (SPEC-001 BR-17).
    if (_loadStarted) return;
    _loadStarted = true;
    _load(Localizations.maybeLocaleOf(context)?.languageCode ?? 'vi');
  }

  Future<void> _load(String languageCode) async {
    final stopwatch = Stopwatch()..start();
    try {
      final style = await widget.styleLoader(widget.styleUrl, languageCode);
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
