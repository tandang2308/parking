import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/generated/app_localizations.dart';
import 'map_banner.dart';

/// Widgets of the manual position (SPEC-001 US-1.3): adjust-mode crosshair,
/// hint and Confirm / Cancel bar, and the "manual" marker.
abstract final class ManualPositionStyle {
  /// Manual marker / crosshair colour. Distinct from the GPS blue dot and the
  /// lot pin colours (BR-6); red/amber stay reserved for availability.
  static const Color colour = Color(0xFF37474F);

  /// Size of the pin glyph (its tip marks the position).
  static const double pinSize = 44;
}

/// The "manual" marker (US-1.3 AC3): a pin whose tip sits on [point],
/// labelled `a11y_manual_marker` (NFR-8).
Marker manualPositionMarker(BuildContext context, LatLng point) {
  final l10n = AppLocalizations.of(context);
  return Marker(
    key: const ValueKey('manual-position-marker'),
    point: point,
    width: ManualPositionStyle.pinSize,
    height: ManualPositionStyle.pinSize,
    // The whole pin is above the point: the tip marks it.
    alignment: Alignment.topCenter,
    child: Semantics(
      container: true, // own node, not merged into the map's label
      label: l10n.a11y_manual_marker,
      excludeSemantics: true,
      child: const _PinGlyph(),
    ),
  );
}

/// US-1.3 AC2: crosshair pin fixed at the screen centre (the map moves
/// under it). Ignores pointers so the map stays pannable.
class AdjustCrosshair extends StatelessWidget {
  const AdjustCrosshair({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        // Twice the pin height, so the pin tip is exactly at the centre.
        child: SizedBox(
          key: const ValueKey('adjust-crosshair'),
          width: ManualPositionStyle.pinSize,
          height: ManualPositionStyle.pinSize * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: ManualPositionStyle.pinSize,
                child: _PinGlyph(),
              ),
              // Exact centre dot under the pin tip.
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: ManualPositionStyle.colour,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinGlyph extends StatelessWidget {
  const _PinGlyph();

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      alignment: Alignment.bottomCenter,
      child: Icon(
        Icons.person_pin_circle,
        color: ManualPositionStyle.colour,
        shadows: [Shadow(blurRadius: 4, color: Color(0x66000000))],
      ),
    );
  }
}

/// US-1.3 AC2: `hint_adjust` at the top of the map in adjust mode.
class AdjustHint extends StatelessWidget {
  const AdjustHint({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MapBanner(
      key: const ValueKey('hint-adjust'),
      icon: Icons.open_with,
      text: l10n.hint_adjust,
    );
  }
}

/// US-1.3 AC2/AC3/AC5: "Cancel" / "Confirm" at the bottom in adjust mode.
class AdjustActions extends StatelessWidget {
  const AdjustActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('btn-adjust-cancel'),
                style: OutlinedButton.styleFrom(
                  minimumSize: MapBanner.minTouchTarget,
                ),
                onPressed: onCancel,
                child: Text(l10n.btn_cancel, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const ValueKey('btn-adjust-confirm'),
                style: FilledButton.styleFrom(
                  minimumSize: MapBanner.minTouchTarget,
                ),
                onPressed: onConfirm,
                child: Text(l10n.btn_confirm, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
