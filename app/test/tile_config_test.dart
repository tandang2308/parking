import 'package:flutter_test/flutter_test.dart';
import 'package:parkfinder/config/tile_config.dart';
import 'package:parkfinder/features/map/base_tile_layer.dart';

void main() {
  group('TileConfig (ADR-0009 decision 3)', () {
    test('defaults: OpenFreeMap liberty, vector, max zoom 18, no raster URL',
        () {
      final config = TileConfig.fromValues();
      expect(config.styleUrl, 'https://tiles.openfreemap.org/styles/liberty');
      expect(config.renderer, TileRenderer.vector);
      expect(config.maxZoom, 18);
      expect(config.rasterUrlTemplate, isEmpty);
      expect(
        config.attribution,
        'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
      );
    });

    test('fromEnvironment without dart-defines equals the defaults', () {
      final config = TileConfig.fromEnvironment();
      expect(config.styleUrl, TileConfig.defaultStyleUrl);
      expect(config.attribution, TileConfig.defaultAttribution);
      expect(config.maxZoom, TileConfig.defaultMaxZoom);
      expect(config.renderer, TileRenderer.vector);
      expect(config.rasterUrlTemplate, isEmpty);
    });

    test('parses overrides', () {
      final config = TileConfig.fromValues(
        styleUrl: 'https://example.test/style.json',
        rasterUrlTemplate: 'https://example.test/{z}/{x}/{y}.png',
        attribution: '© Example © OpenStreetMap contributors',
        maxZoom: '17',
        renderer: 'RASTER',
      );
      expect(config.styleUrl, 'https://example.test/style.json');
      expect(config.rasterUrlTemplate, 'https://example.test/{z}/{x}/{y}.png');
      expect(config.attribution, '© Example © OpenStreetMap contributors');
      expect(config.maxZoom, 17);
      expect(config.renderer, TileRenderer.raster);
    });

    test('invalid values fall back to defaults', () {
      final config = TileConfig.fromValues(maxZoom: 'abc', renderer: 'webgl');
      expect(config.maxZoom, 18);
      expect(config.renderer, TileRenderer.vector);
    });
  });

  test('SPEC-001 NFR-3a: vector tile disk cache TTL is at least 7 days', () {
    expect(
      vectorTileDiskCacheTtl,
      greaterThanOrEqualTo(const Duration(days: 7)),
    );
  });
}
