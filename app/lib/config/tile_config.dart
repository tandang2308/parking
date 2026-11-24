/// Map tile configuration (ADR-0009 decision 3: provider is config, not code).
///
/// Values come from `--dart-define` at build/run time, e.g.
/// `flutter run --dart-define=TILE_RENDERER=raster --dart-define=TILE_RASTER_URL=...`.
/// No API keys are needed for the default provider (OpenFreeMap).
library;

/// Which base-layer widget renders the map tiles.
enum TileRenderer {
  /// MapLibre-style vector tiles via `flutter_map_vector_tiles`.
  vector,

  /// Plain raster `{z}/{x}/{y}` tiles via flutter_map's `TileLayer`
  /// (ADR-0009 fallback 4a).
  raster;

  /// Parses a `TILE_RENDERER` value; anything unknown falls back to [vector].
  static TileRenderer parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'raster':
        return TileRenderer.raster;
      case 'vector':
      default:
        return TileRenderer.vector;
    }
  }
}

class TileConfig {
  /// MapLibre style URL used by the vector renderer.
  static const String defaultStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Attribution required by OpenFreeMap (https://openfreemap.org, section
  /// "Attribution", accessed 2026-11-24). SPEC-001 BR-13: always visible,
  /// not translated.
  static const String defaultAttribution =
      'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

  static const double defaultMaxZoom = 18;

  /// Style URL for [TileRenderer.vector].
  final String styleUrl;

  /// Raster `{z}/{x}/{y}` URL template for [TileRenderer.raster]. Empty by
  /// default: a raster provider must be chosen explicitly (ADR-0009 4a).
  final String rasterUrlTemplate;

  /// Attribution text shown permanently on the map (SPEC-001 BR-13).
  final String attribution;

  /// Maximum map zoom.
  final double maxZoom;

  final TileRenderer renderer;

  const TileConfig({
    this.styleUrl = defaultStyleUrl,
    this.rasterUrlTemplate = '',
    this.attribution = defaultAttribution,
    this.maxZoom = defaultMaxZoom,
    this.renderer = TileRenderer.vector,
  });

  /// Builds the config from `--dart-define` values (compile-time constants).
  factory TileConfig.fromEnvironment() {
    const styleUrl = String.fromEnvironment(
      'TILE_STYLE_URL',
      defaultValue: defaultStyleUrl,
    );
    const rasterUrl = String.fromEnvironment('TILE_RASTER_URL');
    const attribution = String.fromEnvironment(
      'TILE_ATTRIBUTION',
      defaultValue: defaultAttribution,
    );
    const maxZoom = String.fromEnvironment('TILE_MAX_ZOOM');
    const renderer = String.fromEnvironment(
      'TILE_RENDERER',
      defaultValue: 'vector',
    );
    return TileConfig.fromValues(
      styleUrl: styleUrl,
      rasterUrlTemplate: rasterUrl,
      attribution: attribution,
      maxZoom: maxZoom,
      renderer: renderer,
    );
  }

  /// Parses raw string values (separated from [TileConfig.fromEnvironment]
  /// so parsing is unit-testable). Blank values fall back to defaults.
  factory TileConfig.fromValues({
    String styleUrl = '',
    String rasterUrlTemplate = '',
    String attribution = '',
    String maxZoom = '',
    String renderer = '',
  }) {
    final parsedZoom = double.tryParse(maxZoom.trim());
    return TileConfig(
      styleUrl: styleUrl.trim().isEmpty ? defaultStyleUrl : styleUrl.trim(),
      rasterUrlTemplate: rasterUrlTemplate.trim(),
      attribution:
          attribution.trim().isEmpty ? defaultAttribution : attribution.trim(),
      maxZoom: parsedZoom == null || parsedZoom <= 0
          ? defaultMaxZoom
          : parsedZoom,
      renderer: TileRenderer.parse(renderer),
    );
  }
}
