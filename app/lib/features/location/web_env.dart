/// Platform facts that need `dart:js_interop` on Web (SPEC-001 US-1.1 AC11).
library;

export 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart';
