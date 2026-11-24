import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consent_record.dart';

/// Device-only storage of the location consent answer (SPEC-001 US-1.4 AC7).
///
/// Implementations must never send the record over the network.
abstract interface class ConsentStore {
  /// Returns the stored answer, or `null` if there is none or it is
  /// unreadable. Must not throw.
  Future<ConsentRecord?> load();

  /// Stores [record]. May throw if the storage is unavailable; callers treat
  /// a failed save as "answer valid for this session only" (D4).
  Future<void> save(ConsentRecord record);
}

/// [ConsentStore] backed by `shared_preferences`: Android SharedPreferences,
/// Web localStorage.
class SharedPrefsConsentStore implements ConsentStore {
  SharedPrefsConsentStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const resultKey = 'location_consent.result';
  static const versionKey = 'location_consent.version';
  static const timestampKey = 'location_consent.timestamp';

  @override
  Future<ConsentRecord?> load() async {
    try {
      final prefs = await _prefs();
      final result = prefs.getString(resultKey);
      final version = prefs.getInt(versionKey);
      final timestamp = prefs.getString(timestampKey);
      if (result == null || version == null || timestamp == null) return null;

      final parsedResult = ConsentResult.values
          .where((r) => r.name == result)
          .firstOrNull;
      final parsedTime = DateTime.tryParse(timestamp);
      if (parsedResult == null || parsedTime == null) return null;

      return ConsentRecord(
        result: parsedResult,
        version: version,
        timestamp: parsedTime,
      );
    } catch (e) {
      // Storage unavailable (e.g. Safari private mode): behave as first
      // launch, S1 is shown again (D4). No personal data in this log.
      debugPrint('Consent storage unavailable on load: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> save(ConsentRecord record) async {
    final prefs = await _prefs();
    // Version and timestamp first: an interrupted save leaves no result, so
    // S1 is simply shown again.
    await prefs.setInt(versionKey, record.version);
    await prefs.setString(
      timestampKey,
      record.timestamp.toUtc().toIso8601String(),
    );
    await prefs.setString(resultKey, record.result.name);
  }
}
