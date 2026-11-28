import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'lot_pins_layer.dart';
import 'lots_geo.dart';
import 'parking_lot.dart';

/// Mini card of the selected lot (SPEC-001 US-1.2 AC8): name, vehicle
/// types and, when the user's position is known, the BR-11 distance
/// formatted per BR-15. Tap → `/lot/:id`.
class LotMiniCard extends StatelessWidget {
  const LotMiniCard({
    super.key,
    required this.lot,
    required this.onTap,
    this.distanceMetres,
  });

  /// Max card width on wide screens (Web/tablet), so the distance stays
  /// next to the name.
  static const double maxWidth = 480;

  final ParkingLot lot;

  /// From the user's current position (BR-11), not the search centre.
  /// `null` when there is no user position: the distance is hidden.
  final double? distanceMetres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final types = vehicleTypesLabel(lot, l10n);
    final metres = distanceMetres;
    final distance = metres == null ? null : formatDistance(metres, l10n);

    return Material(
      elevation: 4,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('lot-card-tap'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: PinColors.of(lot.pinKind),
                    child: const Icon(
                      Icons.local_parking,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lot.name,
                        key: const ValueKey('lot-card-name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        types,
                        key: const ValueKey('lot-card-types'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    distance,
                    key: const ValueKey('lot-card-distance'),
                    style: theme.textTheme.labelLarge,
                  ),
                ],
                const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
