import 'package:flutter/material.dart';

/// Always-visible tile attribution (SPEC-001 BR-13), text from tile config.
///
/// Used instead of flutter_map's `SimpleAttributionWidget`, whose single
/// non-wrapping row overflows on narrow phones; this one wraps instead.
/// Tappable links (BR-13 "link behaviour") are not part of the spike.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        child: ColoredBox(
          color: const Color(0xCCFFFFFF),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              text,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
            ),
          ),
        ),
      ),
    );
  }
}
