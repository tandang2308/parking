import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:parkfinder/features/location/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scriptable geolocator platform: Android's `checkPermission` reports
/// `denied` for both "denied once" and "Don't ask again".
class _FakePlatform extends GeolocatorPlatform {
  LocationPermission check = LocationPermission.denied;
  LocationPermission request = LocationPermission.denied;

  @override
  Future<LocationPermission> checkPermission() async => check;

  @override
  Future<LocationPermission> requestPermission() async => request;
}

/// SPEC-001 US-1.1 AC4/AC5, issue #32: the "blocked" state survives a
/// relaunch via a device-only flag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;

  PlatformLocationService newService() =>
      PlatformLocationService(platform: platform, isWeb: false);

  Future<bool?> storedFlag() async => (await SharedPreferences.getInstance())
      .getBool(PlatformLocationService.blockedKey);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = _FakePlatform();
  });

  test('request → deniedForever is remembered; after a relaunch the check '
      'reports deniedForever (AC5)', () async {
    platform.request = LocationPermission.deniedForever;
    expect(await newService().requestPermission(),
        LocationPermissionStatus.deniedForever);
    expect(await storedFlag(), isTrue);

    // Relaunch: new service instance, OS check still says "denied".
    expect(await newService().checkPermission(),
        LocationPermissionStatus.deniedForever);
  });

  test('denied once is not blocked: check stays denied (AC4)', () async {
    platform.request = LocationPermission.denied;
    expect(await newService().requestPermission(),
        LocationPermissionStatus.denied);
    expect(await storedFlag(), isNull);
    expect(await newService().checkPermission(),
        LocationPermissionStatus.denied);
  });

  test('granted (e.g. in app settings) clears the flag', () async {
    SharedPreferences.setMockInitialValues(
        {PlatformLocationService.blockedKey: true});
    platform.check = LocationPermission.whileInUse;
    expect(await newService().checkPermission(),
        LocationPermissionStatus.granted);
    expect(await storedFlag(), isNull);

    // Later revoked to "Ask every time": back to denied (AC4), not blocked.
    platform.check = LocationPermission.denied;
    expect(await newService().checkPermission(),
        LocationPermissionStatus.denied);
  });

  test('a request returning denied or granted clears the flag', () async {
    SharedPreferences.setMockInitialValues(
        {PlatformLocationService.blockedKey: true});
    platform.request = LocationPermission.denied;
    await newService().requestPermission();
    expect(await storedFlag(), isNull);
  });

  test('Web never uses the flag', () async {
    SharedPreferences.setMockInitialValues(
        {PlatformLocationService.blockedKey: true});
    final web = PlatformLocationService(platform: platform, isWeb: true);
    // Web reads the browser state (Permissions API); the flag is ignored.
    expect(await web.checkPermission(), LocationPermissionStatus.denied);
  });
}
