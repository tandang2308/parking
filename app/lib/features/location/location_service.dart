import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_env.dart';

/// Outcome of an OS/browser location permission check or request.
enum LocationPermissionStatus {
  granted,

  /// Not granted, the OS/browser can still ask (Android "denied once",
  /// Web Permissions API state `prompt`).
  denied,

  /// Android "Don't ask again" / Web site permission "Blocked".
  deniedForever,

  /// No location API (e.g. Web without HTTPS / Geolocation API, US-1.1 AC11).
  unavailable,

  /// The state cannot be read without calling the location API itself
  /// (Web without the Permissions API, e.g. older iPhone Safari — Q-QA-22).
  unknown,
}

/// One position fix. Kept in memory only (SPEC-001 BR-10, NFR-6): never
/// logged, stored or sent anywhere except as `nearby_lots` parameters.
@immutable
class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracy,
    required this.timestamp,
  });

  final LatLng position;

  /// Reported horizontal accuracy in metres (radius of the accuracy circle).
  final double accuracy;

  /// When the fix was taken (used for the 5 min last-known age, AC9).
  final DateTime timestamp;

  @override
  String toString() => 'LocationFix(<redacted>)'; // never print coordinates
}

/// Error on the position stream: permission revoked / denied.
class LocationPermissionDeniedError implements Exception {
  const LocationPermissionDeniedError();
}

/// Error on the position stream: device location services are off (Android).
class LocationServiceDisabledError implements Exception {
  const LocationServiceDisabledError();
}

/// All device location access of the app (SPEC-001 US-1.1, US-1.4).
///
/// Only used after in-app consent is `granted` (BR-9): the map receives a
/// `null` service when consent was declined, so no method here can be
/// called then. Foreground use only (NFR-5).
abstract interface class LocationService {
  /// Web build (no app settings, no GPS-off detection, no last-known).
  bool get isWeb;

  /// Android only: `getLastKnownPosition` (AC9, Q-QA-8).
  bool get supportsLastKnown;

  /// Android only: location services on/off can be detected (AC6, Q-QA-5).
  bool get canDetectServiceOff;

  /// Android only: app settings / location settings can be opened (AC5, AC6).
  bool get canOpenSettings;

  /// Reads the permission state without prompting. Must not throw.
  Future<LocationPermissionStatus> checkPermission();

  /// Shows the OS/browser permission prompt if the platform still can.
  /// On Web this calls the Geolocation API once (Q-QA-22). Must not throw.
  Future<LocationPermissionStatus> requestPermission();

  /// Whether device location services are on (always `true` on Web).
  Future<bool> isLocationServiceEnabled();

  /// Location services on/off changes (Android); empty on Web.
  Stream<bool> serviceStatusStream();

  /// Foreground position updates. Errors: [LocationPermissionDeniedError],
  /// [LocationServiceDisabledError], or anything else (ignored by callers).
  Stream<LocationFix> positionStream();

  /// Android only: last known position, or `null`. Must not throw.
  Future<LocationFix?> lastKnownPosition();

  /// Android: opens this app's settings page (AC5).
  Future<void> openAppSettings();

  /// Android: opens the device location settings (AC6).
  Future<void> openLocationSettings();
}

/// [LocationService] on the geolocator platform plugins
/// (`geolocator_android`, `geolocator_web`, MIT). The umbrella `geolocator`
/// package is intentionally not used (MPL-2.0 Linux dependency).
class PlatformLocationService implements LocationService {
  PlatformLocationService({
    GeolocatorPlatform? platform,
    bool? isWeb,
    Future<SharedPreferences> Function()? prefs,
  })  : _platformOverride = platform,
        _prefs = prefs ?? SharedPreferences.getInstance,
        isWeb = isWeb ?? kIsWeb;

  final GeolocatorPlatform? _platformOverride;
  final Future<SharedPreferences> Function() _prefs;
  GeolocatorPlatform get _platform =>
      _platformOverride ?? GeolocatorPlatform.instance;

  @override
  final bool isWeb;

  bool get _isAndroid =>
      !isWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get supportsLastKnown => _isAndroid;

  @override
  bool get canDetectServiceOff => _isAndroid;

  @override
  bool get canOpenSettings => _isAndroid;

  /// SPEC-001 AC7 / NFR-5: 10 m distance filter (also enforced in
  /// `LocationController`, because geolocator_web's filter is ineffective).
  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  static LocationPermissionStatus _map(LocationPermission p) => switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationPermissionStatus.granted,
        LocationPermission.denied => LocationPermissionStatus.denied,
        LocationPermission.deniedForever =>
          LocationPermissionStatus.deniedForever,
        LocationPermission.unableToDetermine =>
          LocationPermissionStatus.unknown,
      };

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    if (isWeb && !geolocationApiAvailable) {
      return LocationPermissionStatus.unavailable;
    }
    try {
      // Web: Permissions API, used only as an optimisation (Q-QA-22);
      // `unableToDetermine` (not supported) maps to `unknown`.
      final p = _map(await _platform.checkPermission());
      if (isWeb) return p;
      if (p == LocationPermissionStatus.granted) {
        await _setBlocked(false);
      } else if (p == LocationPermissionStatus.denied && await _isBlocked()) {
        return LocationPermissionStatus.deniedForever; // AC5, issue #32
      }
      return p;
    } catch (e) {
      debugPrint('Location permission check failed: ${e.runtimeType}');
      return isWeb
          ? LocationPermissionStatus.unknown
          : LocationPermissionStatus.unavailable;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    if (isWeb) return _requestWeb();
    final LocationPermissionStatus p;
    try {
      final mapped = _map(await _platform.requestPermission());
      p = mapped == LocationPermissionStatus.unknown
          ? LocationPermissionStatus.unavailable
          : mapped;
    } catch (e) {
      debugPrint('Location permission request failed: ${e.runtimeType}');
      return LocationPermissionStatus.unavailable;
    }
    // AC5 / issue #32: remember "Don't ask again" across relaunches.
    switch (p) {
      case LocationPermissionStatus.deniedForever:
        await _setBlocked(true);
      case LocationPermissionStatus.granted:
      case LocationPermissionStatus.denied:
        await _setBlocked(false);
      case LocationPermissionStatus.unavailable:
      case LocationPermissionStatus.unknown:
        break;
    }
    return p;
  }

  /// Android's `checkPermission` cannot tell "Don't ask again" from
  /// "denied" (it reports `denied` for both); only a request result can.
  /// The last request result `deniedForever` is therefore stored on the
  /// device (a flag only, no location data) so that a relaunch starts in
  /// the blocked state and the first "Enable" opens the app settings
  /// (US-1.1 AC5, issue #32).
  static const blockedKey = 'location_permission.blocked';

  Future<bool> _isBlocked() async {
    try {
      return (await _prefs()).getBool(blockedKey) ?? false;
    } catch (e) {
      debugPrint('Permission flag unavailable: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> _setBlocked(bool blocked) async {
    try {
      final prefs = await _prefs();
      if (blocked) {
        await prefs.setBool(blockedKey, true);
      } else if (prefs.containsKey(blockedKey)) {
        await prefs.remove(blockedKey);
      }
    } catch (e) {
      debugPrint('Permission flag not saved: ${e.runtimeType}');
    }
  }

  /// Web (Q-QA-22): call the Geolocation API once. `PERMISSION_DENIED`
  /// means denied/blocked; any other error (position unavailable, timeout)
  /// still means the permission was granted. The position is discarded.
  Future<LocationPermissionStatus> _requestWeb() async {
    if (!geolocationApiAvailable) return LocationPermissionStatus.unavailable;
    try {
      await _platform.getCurrentPosition(locationSettings: _settings);
      return LocationPermissionStatus.granted;
    } on PermissionDeniedException {
      return LocationPermissionStatus.deniedForever;
    } on PositionUpdateException {
      return LocationPermissionStatus.granted;
    } on TimeoutException {
      return LocationPermissionStatus.granted;
    } catch (e) {
      debugPrint('Geolocation request failed: ${e.runtimeType}');
      return LocationPermissionStatus.unavailable;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (!canDetectServiceOff) return true;
    try {
      return await _platform.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Location service check failed: ${e.runtimeType}');
      return true; // unknown: let the stream / timeout decide
    }
  }

  @override
  Stream<bool> serviceStatusStream() {
    if (!canDetectServiceOff) return const Stream.empty();
    try {
      return _platform
          .getServiceStatusStream()
          .map((s) => s == ServiceStatus.enabled)
          .handleError((Object e) =>
              debugPrint('Service status stream error: ${e.runtimeType}'));
    } catch (e) {
      return const Stream.empty();
    }
  }

  @override
  Stream<LocationFix> positionStream() {
    final Stream<Position> source;
    try {
      source = _platform.getPositionStream(locationSettings: _settings);
    } catch (e) {
      return Stream.error(e);
    }
    return source.transform(
      StreamTransformer<Position, LocationFix>.fromHandlers(
        handleData: (p, sink) => sink.add(_toFix(p)),
        handleError: (Object e, st, sink) {
          if (e is PermissionDeniedException) {
            sink.addError(const LocationPermissionDeniedError());
          } else if (e is LocationServiceDisabledException) {
            sink.addError(const LocationServiceDisabledError());
          } else {
            sink.addError(e);
          }
        },
      ),
    );
  }

  @override
  Future<LocationFix?> lastKnownPosition() async {
    if (!supportsLastKnown) return null;
    try {
      final p = await _platform.getLastKnownPosition();
      return p == null ? null : _toFix(p);
    } catch (e) {
      debugPrint('Last known position failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> openAppSettings() async {
    if (!canOpenSettings) return;
    try {
      await _platform.openAppSettings();
    } catch (e) {
      debugPrint('Open app settings failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> openLocationSettings() async {
    if (!canOpenSettings) return;
    try {
      await _platform.openLocationSettings();
    } catch (e) {
      debugPrint('Open location settings failed: ${e.runtimeType}');
    }
  }

  static LocationFix _toFix(Position p) => LocationFix(
        position: LatLng(p.latitude, p.longitude),
        accuracy: p.accuracy,
        timestamp: p.timestamp,
      );
}
