import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Minimal `banner_location_needed` banner with "Enable"
/// (SPEC-001 US-1.1 AC3, US-1.4 AC4/AC5).
///
/// US-1.4 scope: shown after "Not now"; "Enable" reopens S1. The other
/// location banners (denied, blocked, GPS off, …) come with US-1.1.
class LocationNeededBanner extends StatelessWidget {
  const LocationNeededBanner({super.key, required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      key: const ValueKey('banner-location-needed'),
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.location_off_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.banner_location_needed,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('banner-enable'),
              // NFR-8: touch target ≥ 48 dp.
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onEnable,
              child: Text(l10n.btn_enable),
            ),
          ],
        ),
      ),
    );
  }
}
