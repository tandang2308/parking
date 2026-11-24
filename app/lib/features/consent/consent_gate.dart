import 'dart:async';

import 'package:flutter/material.dart';

import '../location/location_permission_service.dart';
import 'consent_record.dart';
import 'consent_screen.dart';
import 'consent_store.dart';

/// Builds the map screen; [onEnableLocation] is non-null when the
/// `banner_location_needed` banner must be shown (consent declined).
typedef ConsentMapBuilder = Widget Function(
  BuildContext context,
  VoidCallback? onEnableLocation,
);

/// Shows S1 before the map when consent is needed (SPEC-001 US-1.4).
///
/// Guarantees BR-9: [LocationPermissionService] is called only from the
/// "Allow" action — never on launch, never when consent is declined (D3 of
/// MTG-2026-11-24-po-decisions-2), even if the OS permission was granted
/// earlier.
class ConsentGate extends StatefulWidget {
  const ConsentGate({
    super.key,
    required this.store,
    required this.permissionService,
    required this.mapBuilder,
    this.consentVersion = kConsentVersion,
    this.clock = DateTime.now,
  });

  final ConsentStore store;
  final LocationPermissionService permissionService;
  final ConsentMapBuilder mapBuilder;
  final int consentVersion;
  final DateTime Function() clock;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

enum _Phase { loading, consent, map }

class _ConsentGateState extends State<ConsentGate> {
  _Phase _phase = _Phase.loading;
  bool _declined = false;
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
      if (isConsentRequired(record, widget.consentVersion)) {
        _phase = _Phase.consent; // AC1, AC6, AC7
      } else {
        _phase = _Phase.map; // AC5: no nagging
        _declined = record!.result == ConsentResult.declined;
      }
    });
  }

  Future<void> _save(ConsentResult result) async {
    try {
      await widget.store.save(
        ConsentRecord(
          result: result,
          version: widget.consentVersion,
          timestamp: widget.clock().toUtc(),
        ),
      );
    } catch (_) {
      // Storage unavailable: the answer applies to this session only and S1
      // is shown again next launch (D4). Never block the app.
      debugPrint('Consent storage unavailable on save');
    }
  }

  /// AC3: store `granted`, then request the OS/browser permission.
  Future<void> _onAllow() async {
    if (_answering) return;
    _answering = true;
    await _save(ConsentResult.granted);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.map;
      _declined = false;
      _answering = false;
    });
    // The map is shown right away so the app is never blocked by a pending
    // browser prompt; the OS/browser prompt appears on top of it. The result
    // (denied / blocked / granted) is handled by US-1.1 AC2/AC4/AC5.
    unawaited(widget.permissionService.requestPermission());
  }

  /// AC4: store `declined`, no OS/browser prompt, open the map with banner.
  Future<void> _onNotNow() async {
    if (_answering) return;
    _answering = true;
    await _save(ConsentResult.declined);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.map;
      _declined = true;
      _answering = false;
    });
  }

  /// US-1.1 AC3 / TC-1.4.3 step 4: "Enable" after a decline reopens S1.
  void _onEnable() => setState(() => _phase = _Phase.consent);

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _Phase.consent:
        return ConsentScreen(onAllow: _onAllow, onNotNow: _onNotNow);
      case _Phase.map:
        return widget.mapBuilder(context, _declined ? _onEnable : null);
    }
  }
}
