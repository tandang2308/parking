import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';

/// Top-of-map banner (SPEC-001 §3: max one shown at a time).
class MapBanner extends StatelessWidget {
  const MapBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.actionKey,
    required this.actionLabel,
    required this.onAction,
    this.onDismiss,
  });

  final IconData icon;
  final String text;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback onAction;

  /// Close (×) action, labelled `a11y_dismiss` (US-1.1 AC10).
  final VoidCallback? onDismiss;

  /// NFR-8: touch targets ≥ 48 dp.
  static const Size minTouchTarget = Size(48, 48);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onDismiss = this.onDismiss;

    return Material(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, onDismiss == null ? 8 : 0, 4),
        // Text and action wrap onto two lines on narrow phones (320 px).
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(text, style: theme.textTheme.bodyMedium),
                  ),
                  TextButton(
                    key: actionKey,
                    style: TextButton.styleFrom(minimumSize: minTouchTarget),
                    onPressed: onAction,
                    child: Text(actionLabel, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                key: const ValueKey('banner-dismiss'),
                tooltip: l10n.a11y_dismiss,
                constraints: BoxConstraints.tight(minTouchTarget),
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

/// Builds the banner for [kind] wired to [controller] (US-1.1 AC3–AC10).
Widget buildLocationBanner(
  BuildContext context,
  MapBannerKind kind,
  LocationController controller,
) {
  final l10n = AppLocalizations.of(context);
  switch (kind) {
    case MapBannerKind.locationNeeded:
      return MapBanner(
        key: const ValueKey('banner-location-needed'),
        icon: Icons.location_off_outlined,
        text: l10n.banner_location_needed,
        actionKey: const ValueKey('banner-enable'),
        actionLabel: l10n.btn_enable,
        onAction: controller.onEnable,
      );
    case MapBannerKind.locationOff:
      return MapBanner(
        key: const ValueKey('banner-location-off'),
        icon: Icons.location_disabled_outlined,
        text: l10n.banner_location_off,
        actionKey: const ValueKey('banner-turn-on'),
        actionLabel: l10n.btn_turn_on,
        onAction: controller.onTurnOn,
      );
    case MapBannerKind.noFix:
      return MapBanner(
        key: const ValueKey('banner-no-fix'),
        icon: Icons.gps_not_fixed,
        text: l10n.banner_no_fix,
        actionKey: const ValueKey('banner-adjust'),
        actionLabel: l10n.btn_adjust,
        onAction: controller.onAdjust,
      );
    case MapBannerKind.outOfArea:
      return MapBanner(
        key: const ValueKey('banner-out-of-area'),
        icon: Icons.info_outline,
        text: l10n.out_of_area,
        actionKey: const ValueKey('banner-go-vung-tau'),
        actionLabel: l10n.btn_go_vung_tau,
        onAction: controller.onGoToVungTau,
        onDismiss: controller.onDismissOutOfArea,
      );
  }
}

/// Web unblock guide (US-1.1 AC5, SPEC-001 §3).
Future<void> showWebUnblockGuide(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('web-unblock-guide'),
      title: Text(l10n.web_unblock_title),
      content: Text(l10n.web_unblock_guide),
      actions: [
        TextButton(
          key: const ValueKey('web-unblock-ok'),
          style: TextButton.styleFrom(minimumSize: MapBanner.minTouchTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.btn_ok),
        ),
      ],
    ),
  );
}
