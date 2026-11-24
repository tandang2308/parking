import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/consent/consent_store.dart';
import 'package:parkfinder/features/location/location_permission_service.dart';

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

/// Counts permission requests (no real location API in tests).
class FakeLocationPermissionService implements LocationPermissionService {
  FakeLocationPermissionService([this.result = LocationPermissionStatus.granted]);

  final LocationPermissionStatus result;
  int requestCalls = 0;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestCalls++;
    return result;
  }
}

ConsentRecord consentRecord(ConsentResult result, {int version = 1}) =>
    ConsentRecord(
      result: result,
      version: version,
      timestamp: DateTime.utc(2026, 11, 24, 8),
    );
