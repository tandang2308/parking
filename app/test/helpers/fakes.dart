import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/consent/consent_store.dart';
import 'package:parkfinder/features/location/location_service.dart';

/// In-memory [ConsentStore]; survives "relaunches" when the same instance is
/// passed to a new app widget.
class FakeConsentStore implements ConsentStore {
  FakeConsentStore([this.record]);

  ConsentRecord? record;
  bool failLoad = false;
  bool failSave = false;
  int saveCalls = 0;

  @override
  Future<ConsentRecord?> load() async {
    if (failLoad) throw StateError('storage unavailable');
    return record;
  }

  @override
  Future<void> save(ConsentRecord record) async {
    saveCalls++;
    if (failSave) throw StateError('storage unavailable');
    this.record = record;
  }
}

/// Scriptable [LocationService]; records every call (no real location API
/// in tests).
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.requestResult = LocationPermissionStatus.granted,
    this.checkResult = LocationPermissionStatus.granted,
    this.isWeb = false,
    this.serviceEnabled = true,
    this.lastKnown,
  });

  /// Result of every [requestPermission] call (mutable between calls).
  LocationPermissionStatus requestResult;
  LocationPermissionStatus checkResult;
  bool serviceEnabled;
  LocationFix? lastKnown;

  @override
  bool isWeb;

  @override
  bool get supportsLastKnown => !isWeb;
  @override
  bool get canDetectServiceOff => !isWeb;
  @override
  bool get canOpenSettings => !isWeb;

  int requestCalls = 0;
  int checkCalls = 0;
  int serviceEnabledCalls = 0;
  int streamListens = 0;
  int lastKnownCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  /// Total number of location API calls of any kind (BR-9 checks).
  int get totalCalls =>
      requestCalls +
      checkCalls +
      serviceEnabledCalls +
      streamListens +
      lastKnownCalls +
      openAppSettingsCalls +
      openLocationSettingsCalls;

  StreamController<LocationFix>? _positions;
  final StreamController<bool> _serviceStatus =
      StreamController<bool>.broadcast();

  /// Whether the position stream is currently listened to.
  bool get isStreaming => _positions != null && _positions!.hasListener;

  /// Emits a fix on the position stream (if listened to).
  void emit(LocationFix fix) => _positions?.add(fix);
  void emitError(Object error) => _positions?.addError(error);
  void emitServiceStatus(bool enabled) => _serviceStatus.add(enabled);

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkCalls++;
    return checkResult;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestCalls++;
    return requestResult;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    serviceEnabledCalls++;
    return serviceEnabled;
  }

  @override
  Stream<bool> serviceStatusStream() => _serviceStatus.stream;

  @override
  Stream<LocationFix> positionStream() {
    final controller = StreamController<LocationFix>();
    controller.onListen = () => streamListens++;
    _positions = controller;
    return controller.stream;
  }

  @override
  Future<LocationFix?> lastKnownPosition() async {
    lastKnownCalls++;
    return lastKnown;
  }

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCalls++;
}

ConsentRecord consentRecord(ConsentResult result, {int version = 1}) =>
    ConsentRecord(
      result: result,
      version: version,
      timestamp: DateTime.utc(2026, 11, 24, 8),
    );

/// Test clock "now".
final DateTime testNow = DateTime.utc(2026, 11, 24, 9);

LocationFix fixAt(
  double lat,
  double lng, {
  double accuracy = 20,
  DateTime? at,
}) =>
    LocationFix(
      position: LatLng(lat, lng),
      accuracy: accuracy,
      timestamp: at ?? testNow,
    );

/// SPEC-001 §8 mock points.
abstract final class MockPoints {
  static final mp1 = fixAt(10.3460, 107.0740);
  static final mp4 = fixAt(10.3500, 107.0820);
  static final mp6 = fixAt(10.7769, 106.7009); // outside the service area
}
