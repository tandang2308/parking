import 'package:flutter/material.dart';

import 'parking_lot.dart';

/// Route `/lot/:id` (SPEC-001 US-1.2 AC8 hand-off).
///
/// TODO(US-3.1): replace with the lot detail screen (SPEC-003). Until then
/// it only shows the data already known from the map (no new strings).
class LotPlaceholderScreen extends StatelessWidget {
  const LotPlaceholderScreen({super.key, required this.lotId, this.lot});

  /// Route name prefix: `/lot/<id>`.
  static const String routePrefix = '/lot/';

  static String routeFor(String id) => '$routePrefix$id';

  /// The id of a `/lot/<id>` route name, or `null`.
  static String? idFromRoute(String? name) {
    if (name == null || !name.startsWith(routePrefix)) return null;
    final id = name.substring(routePrefix.length);
    return id.isEmpty || id.contains('/') ? null : Uri.decodeComponent(id);
  }

  final String lotId;
  final ParkingLot? lot;

  @override
  Widget build(BuildContext context) {
    final lot = this.lot;
    return Scaffold(
      key: ValueKey('lot-screen-$lotId'),
      appBar: AppBar(title: lot == null ? null : Text(lot.name)),
      body: lot?.address == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(lot!.address!),
            ),
    );
  }
}
