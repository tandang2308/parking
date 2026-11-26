import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/consent/consent_store.dart';
import 'package:parkfinder/features/location/location_service.dart';
import 'package:parkfinder/features/lots/connectivity_monitor.dart';
import 'package:parkfinder/features/lots/lots_repository.dart';
import 'package:parkfinder/features/lots/parking_lot.dart';

/// Scriptable [LotsRepository] (no network in tests). Records every call.
///
/// By default every call returns [lots] at once. With [hold] = true calls
/// wait until [complete] / [fail] is called for them (in-flight tests).
class FakeLotsRepository implements LotsRepository {
  FakeLotsRepository({this.lots = const [], this.error, this.hold = false});

  List<ParkingLot> lots;

  /// If set, every (non-held) call throws it.
  Object? error;
  bool hold;

  final List<({LatLng point, int radiusM})> calls = [];
  final List<Completer<List<ParkingLot>>> _pending = [];

  int get pendingCount => _pending.where((c) => !c.isCompleted).length;

  @override
  Future<List<ParkingLot>> nearbyLots({
    required LatLng point,
    required int radiusM,
  }) {
    calls.add((point: point, radiusM: radiusM));
    if (hold) {
      final c = Completer<List<ParkingLot>>();
      _pending.add(c);
      return c.future;
    }
    if (error != null) return Future.error(error!);
    return Future.value(lots);
  }

  /// Completes the [index]-th held call (default: the oldest pending one).
  void complete(List<ParkingLot> result, {int? index}) {
    final c = index != null
        ? _pending[index]
        : _pending.firstWhere((c) => !c.isCompleted);
    c.complete(result);
  }

  void fail({int? index, Object error = const LotsLoadException('test')}) {
    final c = index != null
        ? _pending[index]
        : _pending.firstWhere((c) => !c.isCompleted);
    c.completeError(error);
  }
}

/// [ConnectivityMonitor] whose offline → online events are fired by tests.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  void reconnect() => _controller.add(null);

  @override
  Stream<void> get onReconnected => _controller.stream;

  @override
  void dispose() => _controller.close();
}

/// A lot for tests (SPEC-001 §5 row).
ParkingLot lotAt(
  String id,
  double lat,
  double lng, {
  Set<VehicleType> types = const {VehicleType.motorbike, VehicleType.car},
  String? name,
}) =>
    ParkingLot(
      id: id,
      name: name ?? 'Lot $id',
      address: 'Address $id',
      position: LatLng(lat, lng),
      vehicleTypes: types,
    );

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
    this.approximateOnly = false,
  });

  /// Android 12+ "approximate" permission only (BR-7).
  bool approximateOnly;
  int approximateCalls = 0;

  @override
  Future<bool> isApproximateOnly() async {
    approximateCalls++;
    return approximateOnly;
  }

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
      approximateCalls +
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
  static final mp3LowAccuracy = fixAt(10.3265, 107.0845, accuracy: 150);
  static final mp4 = fixAt(10.3500, 107.0820);
  static final mp6 = fixAt(10.7769, 106.7009); // outside the service area
}
