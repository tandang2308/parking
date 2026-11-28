/// SPEC-001 BR-17: map labels drawn by the vector style follow the app
/// locale. Pure JSON in, JSON out, so it is unit-testable without a map.
library;

/// The label expression for [languageCode]:
/// - `en` → the English name where OSM has one (`name:en`), otherwise the
///   local name (`name`);
/// - `vi` (and anything else, vi is the app fallback locale) → the local
///   name (`name`).
List<Object?> mapLabelExpression(String languageCode) => languageCode == 'en'
    ? const [
        'coalesce',
        ['get', 'name:en'],
        ['get', 'name'],
      ]
    : const ['get', 'name'];

/// Returns a copy of the MapLibre [style] whose symbol-layer labels show
/// names per BR-17 for [languageCode]. [style] is never modified.
///
/// In each `symbol` layer's `layout.text-field`, the largest subexpression
/// that reads only name properties (`name`, `name:*`, `name_*` via `get`)
/// is replaced by [mapLabelExpression]. For OpenFreeMap "liberty" that is
/// the whole field
/// `["case", ["has", "name:nonlatin"], ["concat", ["get", "name:latin"], …,
/// ["get", "name:nonlatin"]], ["coalesce", ["get", "name_en"], ["get",
/// "name"]]]`, which shows English names in Vũng Tàu (ADR-0009 spike §8.3).
/// Anything else a label shows next to the name (e.g. a road `ref`) is
/// kept; labels without a name (e.g. `["to-string", ["get", "ref"]]`) and
/// non-symbol layers are untouched. A legacy template is rewritten only
/// when it is a single name token (`"{name:latin}"`).
///
/// When a label changes, the style's `modified` gets a `|labels=<code>`
/// suffix: the renderer keys its tile caches by name/version/modified, so
/// styles in two languages never share cached label output.
Map<String, Object?> localizeMapLabels(
  Map<String, Object?> style,
  String languageCode,
) {
  final layers = style['layers'];
  if (layers is! List) return style;
  final target = mapLabelExpression(languageCode);
  var changed = false;
  final newLayers = [
    for (final layer in layers) _localizeLayer(layer, target),
  ];
  for (var i = 0; i < layers.length; i++) {
    if (!identical(newLayers[i], layers[i])) changed = true;
  }
  if (!changed) return style;
  final modified = style['modified'];
  return {
    ...style,
    'layers': newLayers,
    'modified': '${modified ?? ''}|labels=$languageCode',
  };
}

Object? _localizeLayer(Object? layer, List<Object?> target) {
  if (layer is! Map || layer['type'] != 'symbol') return layer;
  final layout = layer['layout'];
  if (layout is! Map || !layout.containsKey('text-field')) return layer;
  final field = layout['text-field'];
  final rewritten = _rewrite(field, target);
  if (identical(rewritten, field)) return layer;
  return <String, Object?>{
    ...layer.cast<String, Object?>(),
    'layout': <String, Object?>{
      ...layout.cast<String, Object?>(),
      'text-field': rewritten,
    },
  };
}

final RegExp _nameToken = RegExp(r'^\{(name(?:[:_][^{}]*)?)\}$');

Object? _rewrite(Object? expr, List<Object?> target) {
  if (expr is String) {
    return _nameToken.hasMatch(expr.trim()) ? target : expr;
  }
  if (expr is! List || expr.isEmpty || expr.first == 'literal') return expr;
  if (_readsOnlyNames(expr)) return target;
  List<Object?>? out;
  for (var i = 1; i < expr.length; i++) {
    final item = expr[i];
    // Bare strings inside an expression are literals (separators, keys),
    // not templates: only sub-expressions are rewritten.
    if (item is! List) continue;
    final rewritten = _rewrite(item, target);
    if (!identical(rewritten, item)) (out ??= List.of(expr))[i] = rewritten;
  }
  return out ?? expr;
}

bool _isNameKey(Object? key) =>
    key is String &&
    (key == 'name' || key.startsWith('name:') || key.startsWith('name_'));

/// True when [expr] reads at least one feature property and every property
/// it reads (`get`) is a name.
bool _readsOnlyNames(List<Object?> expr) {
  var names = 0;
  var others = 0;
  void visit(Object? e) {
    if (e is! List || e.isEmpty || e.first == 'literal') return;
    if (e.first == 'get') {
      if (e.length == 2 && _isNameKey(e[1])) {
        names++;
      } else {
        others++;
      }
      return;
    }
    for (var i = 1; i < e.length; i++) {
      visit(e[i]);
    }
  }

  visit(expr);
  return names > 0 && others == 0;
}
