import 'dart:convert';

import 'package:http/http.dart' as http;

import 'map_label_language.dart';

/// HTTP client for `vt.StyleReader` that applies [localizeMapLabels]
/// (SPEC-001 BR-17) to the style document as it is downloaded, before the
/// reader compiles it. It is the only hook the package offers on the style
/// JSON; every other request (TileJSON, sprites, glyphs) and any style
/// response that is not a JSON object passes through unchanged. No extra
/// requests are made.
class StyleLabelClient extends http.BaseClient {
  StyleLabelClient({
    required http.Client inner,
    required String styleUrl,
    required this.languageCode,
  })  : _inner = inner,
        _styleUri = Uri.parse(styleUrl);

  final http.Client _inner;
  final Uri _styleUri;
  final String languageCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.url != _styleUri || response.statusCode != 200) {
      return response;
    }
    final bytes = await response.stream.toBytes();
    var body = bytes;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) {
        body = utf8.encode(jsonEncode(
          localizeMapLabels(decoded.cast<String, Object?>(), languageCode),
        ));
      }
    } on FormatException {
      // Not JSON: let the reader report it as it would without us.
    }
    final headers = {...response.headers}
      ..remove('content-length')
      ..remove('content-encoding');
    return http.StreamedResponse(
      http.ByteStream.fromBytes(body),
      response.statusCode,
      contentLength: body.length,
      request: response.request,
      headers: headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
