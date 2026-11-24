import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Whether the browser Geolocation API can be used: secure context (HTTPS or
/// localhost) and `navigator.geolocation` present (SPEC-001 US-1.1 AC11).
bool get geolocationApiAvailable {
  try {
    final secure = globalContext['isSecureContext']?.dartify();
    if (secure == false) return false;
    final navigator = globalContext['navigator'];
    if (navigator == null) return false;
    return (navigator as JSObject).has('geolocation');
  } catch (_) {
    return false;
  }
}
