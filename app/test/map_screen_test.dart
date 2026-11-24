import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:parkfinder/config/tile_config.dart';
import 'package:parkfinder/features/map/base_tile_layer.dart';
import 'package:parkfinder/main.dart';

/// A style loader that never completes: no network in tests.
Future<vt.Style> _pendingStyle(String _) => Completer<vt.Style>().future;

/// A tiny offline style (background only, no sources): exercises the real
/// VectorTileLayer without any network access.
Future<vt.Style> _offlineStyle(String _) async => vt.Style(
      theme: const vt.ThemeReader().read(const {
        'version': 8,
        'sources': <String, Object?>{},
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': '#f8f4f0'},
          },
        ],
      }),
      providers: const vt.TileProviders({}),
    );

void main() {
  testWidgets('app shows a full-screen map centred on BR-5 with attribution',
      (tester) async {
    await tester.pumpWidget(
      const ParkFinderApp(
        tileConfig: TileConfig(),
        styleLoader: _pendingStyle,
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    // SPEC-001 BR-13: attribution always visible, from config.
    expect(
      find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
      findsOneWidget,
    );

    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.initialCenter.latitude, 10.3460);
    expect(options.initialCenter.longitude, 107.0740);
    expect(options.initialZoom, 15);
    expect(options.minZoom, 13);
    expect(options.maxZoom, 18);
  });

  testWidgets('attribution stays visible without overflow on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ParkFinderApp(
        tileConfig: TileConfig(),
        styleLoader: _pendingStyle,
      ),
    );

    final attribution =
        find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap');
    expect(attribution, findsOneWidget);
    final rect = tester.getRect(attribution);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('attribution text comes from config', (tester) async {
    await tester.pumpWidget(
      const ParkFinderApp(
        tileConfig: TileConfig(attribution: 'Custom © OpenStreetMap'),
        styleLoader: _pendingStyle,
      ),
    );
    expect(find.text('Custom © OpenStreetMap'), findsOneWidget);
  });

  testWidgets('vector renderer mounts VectorTileLayer once the style loads',
      (tester) async {
    await tester.pumpWidget(
      const ParkFinderApp(
        tileConfig: TileConfig(),
        styleLoader: _offlineStyle,
      ),
    );
    await tester.pump();

    expect(find.byType(VectorBaseLayer), findsOneWidget);
    expect(find.byType(vt.VectorTileLayer), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(
      find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
      findsOneWidget,
    );

    // Unmount cleanly (disposes the style).
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('raster renderer is a config switch (ADR-0009 decision 3)',
      (tester) async {
    await tester.pumpWidget(
      const ParkFinderApp(
        tileConfig: TileConfig(renderer: TileRenderer.raster),
        styleLoader: _pendingStyle,
      ),
    );

    expect(find.byType(RasterBaseLayer), findsOneWidget);
    expect(find.byType(VectorBaseLayer), findsNothing);
    // No raster URL configured by default: nothing is requested.
    expect(find.byType(TileLayer), findsNothing);
  });

  test('buildBaseTileLayer picks the layer from config', () {
    expect(buildBaseTileLayer(const TileConfig()), isA<VectorBaseLayer>());
    final raster = buildBaseTileLayer(
      const TileConfig(
        renderer: TileRenderer.raster,
        rasterUrlTemplate: 'https://example.test/{z}/{x}/{y}.png',
      ),
    );
    expect(raster, isA<RasterBaseLayer>());
    expect(
      (raster as RasterBaseLayer).urlTemplate,
      'https://example.test/{z}/{x}/{y}.png',
    );
  });
}
