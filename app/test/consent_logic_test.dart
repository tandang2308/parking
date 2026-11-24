import 'package:flutter_test/flutter_test.dart';
import 'package:parkfinder/features/consent/consent_record.dart';
import 'package:parkfinder/features/consent/consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

void main() {
  group('isConsentRequired (SPEC-001 US-1.4)', () {
    test('first launch / no stored answer → S1 (AC1, AC7)', () {
      expect(isConsentRequired(null, 1), isTrue);
    });

    test('granted with current version → no S1', () {
      expect(isConsentRequired(consentRecord(ConsentResult.granted), 1),
          isFalse);
    });

    test('declined with current version → no S1 (AC5, no nagging)', () {
      expect(isConsentRequired(consentRecord(ConsentResult.declined), 1),
          isFalse);
    });

    test('older version → S1 again, granted and declined (AC6)', () {
      expect(
        isConsentRequired(consentRecord(ConsentResult.granted), 2),
        isTrue,
      );
      expect(
        isConsentRequired(consentRecord(ConsentResult.declined), 2),
        isTrue,
      );
    });

    test('default consent version is 1 unless overridden (Q-QA-31)', () {
      expect(kConsentVersion, 1);
    });
  });

  group('isLocationUseAllowed (BR-9, D3)', () {
    test('only a current-version granted answer allows location use', () {
      expect(isLocationUseAllowed(null, 1), isFalse);
      expect(
        isLocationUseAllowed(consentRecord(ConsentResult.granted), 1),
        isTrue,
      );
      expect(
        isLocationUseAllowed(consentRecord(ConsentResult.declined), 1),
        isFalse,
      );
      expect(
        isLocationUseAllowed(consentRecord(ConsentResult.granted), 2),
        isFalse,
      );
    });
  });

  group('SharedPrefsConsentStore (AC7, device only)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('empty storage → null (first launch)', () async {
      expect(await SharedPrefsConsentStore().load(), isNull);
    });

    test('save then load round-trips result, version and UTC timestamp',
        () async {
      final store = SharedPrefsConsentStore();
      final record = ConsentRecord(
        result: ConsentResult.granted,
        version: 3,
        timestamp: DateTime.utc(2026, 11, 24, 9, 30),
      );
      await store.save(record);

      expect(await SharedPrefsConsentStore().load(), record);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPrefsConsentStore.resultKey), 'granted');
      expect(prefs.getInt(SharedPrefsConsentStore.versionKey), 3);
      expect(
        prefs.getString(SharedPrefsConsentStore.timestampKey),
        '2026-11-24T09:30:00.000Z',
      );
    });

    test('declined is stored and loaded', () async {
      final store = SharedPrefsConsentStore();
      await store.save(consentRecord(ConsentResult.declined));
      expect((await store.load())!.result, ConsentResult.declined);
    });

    test('cleared data → null again (AC7: S1 shown after clearing)', () async {
      final store = SharedPrefsConsentStore();
      await store.save(consentRecord(ConsentResult.granted));
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      expect(await store.load(), isNull);
    });

    test('corrupt or partial data → null (treated as first launch)',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConsentStore.resultKey: 'maybe',
        SharedPrefsConsentStore.versionKey: 1,
        SharedPrefsConsentStore.timestampKey: '2026-11-24T09:30:00.000Z',
      });
      expect(await SharedPrefsConsentStore().load(), isNull);

      SharedPreferences.setMockInitialValues({
        SharedPrefsConsentStore.resultKey: 'granted',
      });
      expect(await SharedPrefsConsentStore().load(), isNull);
    });

    test('storage failure on load → null, no throw (D4)', () async {
      final store = SharedPrefsConsentStore(
        prefs: () => Future.error(StateError('localStorage unavailable')),
      );
      expect(await store.load(), isNull);
    });

    test('storage failure on save → throws to the caller (gate handles it)',
        () async {
      final store = SharedPrefsConsentStore(
        prefs: () => Future.error(StateError('localStorage unavailable')),
      );
      expect(
        store.save(consentRecord(ConsentResult.granted)),
        throwsStateError,
      );
    });
  });
}
