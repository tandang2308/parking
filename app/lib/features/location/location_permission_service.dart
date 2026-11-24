import 'package:flutter/foundation.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

/// Outcome of the OS/browser location permission request.
enum LocationPermissionStatus { granted, denied, deniedForever, unavailable }

/// Requests the OS/browser location permission.
///
/// Called only after the user tapped "Allow" on S1 (SPEC-001 US-1.4 AC1,
/// AC3, BR-9). Position fixes, last-known position and permission-state
/// handling belong to US-1.1.
abstract interface class LocationPermissionService {
  /// Shows the OS/browser permission prompt (if the platform still can).
  /// Must not throw.
  Future<LocationPermissionStatus> requestPermission();
}

/// [LocationPermissionService] using the geolocator platform plugins
/// (`geolocator_android`, `geolocator_web`).
///
/// Only `requestPermission` is called — no `checkPermission`,
/// `getCurrentPosition` or `getLastKnownPosition` here.
/// Note: browsers have no "prompt only" API, so on Web `geolocator_web`
/// implements this with one `navigator.geolocation.getCurrentPosition` call
/// whose result is discarded by the plugin.
class PlatformLocationPermissionService implements LocationPermissionService {
  const PlatformLocationPermissionService();

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final permission = await GeolocatorPlatform.instance.requestPermission();
      return switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationPermissionStatus.granted,
        LocationPermission.denied => LocationPermissionStatus.denied,
        LocationPermission.deniedForever =>
          LocationPermissionStatus.deniedForever,
        LocationPermission.unableToDetermine =>
          LocationPermissionStatus.unavailable,
      };
    } catch (e) {
      // E.g. Web without HTTPS / Geolocation API (US-1.1 AC11): no error
      // shown, the map keeps working. No coordinates in this log.
      debugPrint('Location permission request failed: ${e.runtimeType}');
      return LocationPermissionStatus.unavailable;
    }
  }
}
