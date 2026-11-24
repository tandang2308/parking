/// Location consent result and policy (SPEC-001 US-1.4, BR-9).
library;

/// Current version of the location consent notice (S1).
///
/// Bump it when the S1 text/purpose changes materially: every stored consent
/// with an older version shows S1 again (US-1.4 AC6).
///
/// Overridable at build time for QA (TC-1.4.4, Q-QA-31), e.g.
/// `flutter run --dart-define=CONSENT_VERSION=2`.
const int kConsentVersion = int.fromEnvironment(
  'CONSENT_VERSION',
  defaultValue: 1,
);

/// The user's answer on S1.
enum ConsentResult { granted, declined }

/// A stored consent answer: result + consent version + timestamp (US-1.4 AC3,
/// AC4). Kept on the device only (AC7) — never sent over the network.
class ConsentRecord {
  const ConsentRecord({
    required this.result,
    required this.version,
    required this.timestamp,
  });

  final ConsentResult result;
  final int version;

  /// When the user answered, in UTC.
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      other is ConsentRecord &&
      other.result == result &&
      other.version == version &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(result, version, timestamp);

  @override
  String toString() =>
      'ConsentRecord(${result.name}, v$version, ${timestamp.toIso8601String()})';
}

/// Whether S1 must be shown when the app opens.
///
/// - no stored answer (first launch, cleared data, storage unavailable):
///   show (US-1.4 AC1, AC7; D4 of MTG-2026-11-24-po-decisions-2);
/// - stored answer with an older consent version: show (AC6);
/// - otherwise (granted or declined with the current version): do not show
///   (AC5 — no nagging after a decline).
bool isConsentRequired(ConsentRecord? record, int currentVersion) {
  if (record == null) return true;
  return record.version < currentVersion;
}

/// Whether the app may call any location API (incl. permission requests).
///
/// Only a current-version `granted` answer allows it (BR-9). A `declined`
/// answer wins even if the OS permission was granted earlier (D3 of
/// MTG-2026-11-24-po-decisions-2, Q-QA-30).
bool isLocationUseAllowed(ConsentRecord? record, int currentVersion) =>
    !isConsentRequired(record, currentVersion) &&
    record!.result == ConsentResult.granted;
