import 'package:flutter/material.dart';

/// Deutlich sichtbare Anzeige der Schulwoche ("G-Woche" / "U-Woche").
class WeekBadgeChip extends StatelessWidget {
  final String badge;
  final bool compact;

  const WeekBadgeChip({super.key, required this.badge, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = badge.trim();
    final upper = b.toUpperCase();
    final (bg, fg) = switch (upper) {
      'G' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'U' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    final label = b.length == 1 ? '$upper-Woche' : b;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}
