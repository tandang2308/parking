import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/features/lots/lot_card.dart';
import 'package:parkfinder/features/lots/parking_lot.dart';
import 'package:parkfinder/l10n/generated/app_localizations.dart';

/// SPEC-001 BR-16, US-1.2 AC8 (TC-1.2.34 automated part): customer-only
/// lots show `label_customers_only` under the name on the mini card.

const _label = ValueKey('lot-card-customers-only');

ParkingLot _lot({required bool customersOnly}) => ParkingLot(
      id: 'c1',
      name: 'Khách sạn Biển Xanh',
      position: const LatLng(10.3466, 107.0752),
      vehicleTypes: const {VehicleType.motorbike},
      customersOnly: customersOnly,
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required Locale locale,
  required bool customersOnly,
}) =>
    tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LotMiniCard(
          lot: _lot(customersOnly: customersOnly),
          distanceMetres: 145,
          onTap: () {},
        ),
      ),
    ));

void main() {
  const texts = {'en': 'Customers only', 'vi': 'Chỉ dành cho khách'};

  for (final entry in texts.entries) {
    final locale = Locale(entry.key);

    testWidgets('TC-1.2.34 ${entry.key}: customer-only lot shows the label '
        'under the name', (tester) async {
      await _pumpCard(tester, locale: locale, customersOnly: true);

      expect(find.text(entry.value), findsOneWidget);
      final name =
          tester.getRect(find.byKey(const ValueKey('lot-card-name')));
      final label = tester.getRect(find.byKey(_label));
      final types =
          tester.getRect(find.byKey(const ValueKey('lot-card-types')));
      expect(label.top, greaterThanOrEqualTo(name.bottom));
      expect(types.top, greaterThanOrEqualTo(label.bottom));
    });

    testWidgets('TC-1.2.34 ${entry.key}: other lots have no label',
        (tester) async {
      await _pumpCard(tester, locale: locale, customersOnly: false);

      expect(find.byKey(_label), findsNothing);
      expect(find.text(entry.value), findsNothing);
      expect(find.byKey(const ValueKey('lot-card-name')), findsOneWidget);
    });
  }

  test('BR-6: the pin style does not depend on customers_only', () {
    expect(_lot(customersOnly: true).pinKind,
        _lot(customersOnly: false).pinKind);
  });
}
