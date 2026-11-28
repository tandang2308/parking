import 'package:flutter/material.dart';

import 'consent_record.dart';
import 'consent_screen.dart';
import 'consent_store.dart';

/// What the map may do with location, decided by the consent gate.
@immutable
class LocationAccess {
  const LocationAccess._({
    required this.allowed,
    required this.requestPermission,
    this.onReopenConsent,
  });

  /// Consent declined: no location API at all; "Enable" reopens S1.
  const LocationAccess.declined({required VoidCallback onReopenConsent})
      : this._(
          allowed: false,
          requestPermission: false,
          onReopenConsent: onReopenConsent,
        );

  /// Consent granted (BR-9). [requestPermission] is true right after
  /// "Allow" (US-1.4 AC3: show the OS/browser prompt now); on relaunch the
  /// permission is only checked (no prompt).
  const LocationAccess.granted({required bool requestPermission})
      : this._(allowed: true, requestPermission: requestPermission);

  /// Whether any location API may be called ([isLocationUseAllowed]).
  final bool allowed;
  final bool requestPermission;
  final VoidCallback? onReopenConsent;
}

/// Builds the map screen for the given [access].
typedef ConsentMapBuilder = Widget Function(
  BuildContext context,
  LocationAccess access,
);

/// Shows S1 before the map when consent is needed (SPEC-001 US-1.4).
///
/// Guarantees BR-9: location is allowed only for a current-version
/// `granted` answer ([isLocationUseAllowed]) — never on first launch before
/// "Allow", never when consent is declined (D3 of
/// MTG-2026-11-24-po-decisions-2), even if the OS permission was granted
/// earlier.
class ConsentGate extends StatefulWidget {
  const ConsentGate({
    super.key,
    required this.store,
    required this.mapBuilder,
    this.consentVersion = kConsentVersion,
    this.clock = DateTime.now,
  });

  final ConsentStore store;
  final ConsentMapBuilder mapBuilder;
  final int consentVersion;
  final DateTime Function() clock;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

enum _Phase { loading, consent, map }

class _ConsentGateState extends State<ConsentGate> {
  _Phase _phase = _Phase.loading;

  /// The answer in effect for this session (also when saving failed, D4).
  ConsentRecord? _record;

  /// True when the map was opened by "Allow" in this session.
  bool _justAllowed = false;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ConsentRecord? record;
    try {
      record = await widget.store.load();
    } catch (_) {
      record = null; // Storage unavailable → first launch (D4).
    }
    if (!mounted) return;
    setState(() {
      _record = record;
      // AC1, AC6, AC7: S1 first; AC5: no nagging.
      _phase = isConsentRequired(record, widget.consentVersion)
          ? _Phase.consent
          : _Phase.map;
    });
  }

  Future<ConsentRecord> _save(ConsentResult result) async {
    final record = ConsentRecord(
      result: result,
      version: widget.consentVersion,
      timestamp: widget.clock().toUtc(),
    );
    try {
      await widget.store.save(record);
    } catch (_) {
      // Storage unavailable: the answer applies to this session only and S1
      // is shown again next launch (D4). Never block the app.
      debugPrint('Consent storage unavailable on save');
    }
    return record;
  }

  /// AC3: store `granted`; the map then requests the OS/browser permission
  /// and handles the result (US-1.1 AC2/AC4/AC5).
  Future<void> _onAllow() async {
    if (_answering) return;
    _answering = true;
    final record = await _save(ConsentResult.granted);
    if (!mounted) return;
    setState(() {
      _record = record;
      _justAllowed = true;
      _phase = _Phase.map;
      _answering = false;
    });
  }

  /// AC4: store `declined`, no OS/browser prompt, open the map with banner.
  Future<void> _onNotNow() async {
    if (_answering) return;
    _answering = true;
    final record = await _save(ConsentResult.declined);
    if (!mounted) return;
    setState(() {
      _record = record;
      _justAllowed = false;
      _phase = _Phase.map;
      _answering = false;
    });
  }

  /// US-1.1 AC3 / TC-1.4.3 step 4: "Enable" after a decline reopens S1.
  void _onReopenConsent() => setState(() => _phase = _Phase.consent);

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _Phase.consent:
        final consent = ConsentScreen(onAllow: _onAllow, onNotNow: _onNotNow);
        if (!_mapShown) return consent;
        // S1 reopened from the map ("Enable" / "My location" after a
        // decline): keep the map alive behind S1 so "Not now" returns to it
        // unchanged — e.g. a manual position stays (US-1.3 AC4, TC-1.3.15a).
        return _mapLayer(context, offstage: true, consent: consent);
      case _Phase.map:
        return _mapLayer(context, offstage: false);
    }
  }

  /// The same tree shape in both phases, so the map's state survives S1.
  Widget _mapLayer(
    BuildContext context, {
    required bool offstage,
    Widget? consent,
  }) {
    return Stack(
      children: [
        Offstage(offstage: offstage, child: _map(context)),
        ?consent,
      ],
    );
  }

  /// True once the map has been shown in this session.
  bool _mapShown = false;

  Widget _map(BuildContext context) {
    _mapShown = true;
    final allowed = isLocationUseAllowed(_record, widget.consentVersion);
    final access = allowed
        ? LocationAccess.granted(requestPermission: _justAllowed)
        : LocationAccess.declined(onReopenConsent: _onReopenConsent);
    // Keyed by the access kind: "Allow" after a decline builds a new map
    // (it requests the permission on start); "Not now" keeps the old one.
    return KeyedSubtree(
      key: ValueKey('map-allowed-$allowed'),
      child: widget.mapBuilder(context, access),
    );
  }
}
