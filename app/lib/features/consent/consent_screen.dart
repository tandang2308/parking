import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// S1 — in-app location consent screen (SPEC-001 US-1.4 AC2).
///
/// Minimal notice only: the "Privacy policy" link is added once US-5.2
/// delivers the policy page (§9 Q-B).
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({
    super.key,
    required this.onAllow,
    required this.onNotNow,
  });

  final VoidCallback onAllow;
  final VoidCallback onNotNow;

  /// NFR-8: touch targets ≥ 48 dp.
  static const double minButtonHeight = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const buttonSize = Size(double.infinity, minButtonHeight);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Body scrolls on small screens / large text (TC-1.4.7).
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.consent_title,
                        key: const ValueKey('consent-title'),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.consent_body,
                      key: const ValueKey('consent-body'),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: const ValueKey('consent-allow'),
                    style: FilledButton.styleFrom(minimumSize: buttonSize),
                    onPressed: onAllow,
                    child: Text(l10n.btn_allow, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('consent-not-now'),
                    style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                    onPressed: onNotNow,
                    child: Text(l10n.btn_not_now, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
