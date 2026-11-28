import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkfinder/features/map/base_tile_layer.dart';
import 'package:parkfinder/features/map/map_label_language.dart';
import 'package:parkfinder/features/map/style_label_client.dart';

/// SPEC-001 BR-17 (TC-1.1.33 automated part): map labels follow the app
/// locale — vi → `name`, en → `name:en` falling back to `name`.

/// The OpenFreeMap "liberty" label expression (style JSON, 2026-11-28).
const List<Object?> _libertyName = [
  'case',
  ['has', 'name:nonlatin'],
  [
    'concat',
    ['get', 'name:latin'],
    '\n',
    ['get', 'name:nonlatin'],
  ],
  [
    'coalesce',
    ['get', 'name_en'],
    ['get', 'name'],
  ],
];

const List<Object?> _vi = ['get', 'name'];
const List<Object?> _en = [
  'coalesce',
  ['get', 'name:en'],
  ['get', 'name'],
];

Map<String, Object?> _style() => {
      'version': 8,
      'name': 'Liberty',
      'sources': {
        'openmaptiles': {
          'type': 'vector',
          'tiles': ['https://tiles.example.invalid/{z}/{x}/{y}.pbf'],
        },
      },
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': '#f8f4f0'},
        },
        {
          'id': 'road',
          'type': 'line',
          'source': 'openmaptiles',
          'source-layer': 'transportation',
          'paint': {'line-color': '#fff'},
        },
        {
          'id': 'label_town',
          'type': 'symbol',
          'source': 'openmaptiles',
          'source-layer': 'place',
          'layout': {
            'text-field': _libertyName,
            'text-font': ['Noto Sans Regular'],
            'text-size': 12,
          },
        },
        {
          'id': 'highway-shield',
          'type': 'symbol',
          'source': 'openmaptiles',
          'source-layer': 'transportation_name',
          'layout': {
            'text-field': [
              'to-string',
              ['get', 'ref'],
            ],
          },
        },
        {
          'id': 'oneway-arrow',
          'type': 'symbol',
          'source': 'openmaptiles',
          'source-layer': 'transportation',
          'layout': {'icon-image': 'arrow'},
        },
      ],
    };

List<Object?> _layers(Map<String, Object?> style) =>
    style['layers']! as List<Object?>;

Object? _field(Map<String, Object?> style, String id) {
  final layer =
      _layers(style).cast<Map>().firstWhere((l) => l['id'] == id);
  return (layer['layout'] as Map?)?['text-field'];
}

void main() {
  group('localizeMapLabels (BR-17)', () {
    test('vi: name labels show the local OSM name', () {
      final out = localizeMapLabels(_style(), 'vi');
      expect(_field(out, 'label_town'), _vi);
    });

    test('en: name:en with fallback to the local name', () {
      final out = localizeMapLabels(_style(), 'en');
      expect(_field(out, 'label_town'), _en);
      expect(mapLabelExpression('en'), _en);
      // The fallback is the plain local name, never name_en / name:latin.
      expect(jsonEncode(out), isNot(contains('name_en')));
      expect(jsonEncode(out), isNot(contains('name:latin')));
    });

    test('other locales fall back to vi (the app fallback locale)', () {
      expect(mapLabelExpression('fr'), _vi);
    });

    test('layers without a name label are untouched', () {
      final input = _style();
      final out = localizeMapLabels(input, 'en');
      for (final i in [0, 1, 3, 4]) {
        expect(identical(_layers(out)[i], _layers(input)[i]), isTrue,
            reason: 'layer $i');
      }
      expect(_field(out, 'highway-shield'), [
        'to-string',
        ['get', 'ref'],
      ]);
    });

    test('the input style is not modified', () {
      final input = _style();
      final before = jsonEncode(input);
      localizeMapLabels(input, 'en');
      expect(jsonEncode(input), before);
    });

    test('text next to the name (e.g. a ref) is kept', () {
      final style = _style();
      (_layers(style)[2] as Map)['layout'] = {
        'text-field': [
          'concat',
          ['get', 'name'],
          ' (',
          ['get', 'ref'],
          ')',
        ],
      };
      expect(_field(localizeMapLabels(style, 'en'), 'label_town'), [
        'concat',
        _en,
        ' (',
        ['get', 'ref'],
        ')',
      ]);
    });

    test('a legacy single-name template is rewritten', () {
      final style = _style();
      (_layers(style)[2] as Map)['layout'] = {'text-field': '{name:latin}'};
      expect(_field(localizeMapLabels(style, 'vi'), 'label_town'), _vi);
    });

    test('the theme id differs per language, unchanged style stays as is',
        () {
      final vi = localizeMapLabels(_style(), 'vi');
      final en = localizeMapLabels(_style(), 'en');
      expect(vi['modified'], isNot(en['modified']));

      final noLabels = {
        'version': 8,
        'layers': [_layers(_style())[0]],
      };
      expect(identical(localizeMapLabels(noLabels, 'en'), noLabels), isTrue);
    });

    test('applying it again switches the language (idempotent rewrite)', () {
      final twice = localizeMapLabels(localizeMapLabels(_style(), 'en'), 'vi');
      expect(_field(twice, 'label_town'), _vi);
    });
  });

  group('StyleLabelClient (BR-17 wiring)', () {
    const styleUrl = 'https://tiles.example.invalid/styles/liberty';

    StyleLabelClient clientFor(String language, {int status = 200}) =>
        StyleLabelClient(
          inner: MockClient((request) async {
            if (request.url.toString() == styleUrl) {
              return http.Response(jsonEncode(_style()), status);
            }
            return http.Response('{"tiles":["x"]}', 200);
          }),
          styleUrl: styleUrl,
          languageCode: language,
        );

    test('rewrites the style document only', () async {
      final client = clientFor('en');
      final style = jsonDecode((await client.get(Uri.parse(styleUrl))).body)
          as Map<String, Object?>;
      expect(_field(style, 'label_town'), _en);

      final other = await client
          .get(Uri.parse('https://tiles.example.invalid/planet'));
      expect(other.body, '{"tiles":["x"]}');
      client.close();
    });

    test('error responses pass through unchanged', () async {
      final client = clientFor('vi', status: 404);
      final response = await client.get(Uri.parse(styleUrl));
      expect(response.statusCode, 404);
      expect(response.body, jsonEncode(_style()));
      client.close();
    });

    test('the renderer compiles the rewritten style (vi and en)', () async {
      for (final language in ['vi', 'en']) {
        final style = await vt.StyleReader(
          uri: styleUrl,
          httpClient: clientFor(language),
          cache: false,
        ).read();
        expect(style.theme.layers.map((l) => l.id), contains('label_town'));
        style.dispose();
      }
    });
  });

  group('VectorBaseLayer passes the app locale to the style loader', () {
    for (final locale in const [Locale('vi'), Locale('en')]) {
      testWidgets('locale ${locale.languageCode}', (tester) async {
        final requested = <String>[];
        await tester.pumpWidget(Localizations(
          locale: locale,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: VectorBaseLayer(
            styleUrl: 'https://tiles.example.invalid/styles/liberty',
            styleLoader: (url, language) {
              requested.add(language);
              return Completer<vt.Style>().future;
            },
          ),
        ));
        await tester.pump();
        expect(requested, [locale.languageCode]);
      });
    }
  });
}
