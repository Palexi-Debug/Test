import 'package:flutter/material.dart';

/// Gemeinsame Bausteine für Einstellungen und Anpassungs-Menüs, damit alle
/// Seiten gleich aussehen (Abschnitts-Titel, Schalter, Auswahlleisten).

/// Abschnitts-Überschrift in Akzentfarbe.
class SettingsSectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SettingsSectionHeader(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Abgerundete Kachel-Reihenfolge wie in der Einstellungsliste
/// (oben/unten rund, Mitte eckig).
BorderRadius settingsGroupRadius(int index, int length) {
  const r = Radius.circular(12);
  if (length <= 1) return const BorderRadius.all(r);
  if (index == 0) return const BorderRadius.vertical(top: r);
  if (index == length - 1) return const BorderRadius.vertical(bottom: r);
  return BorderRadius.zero;
}

/// Schalter im Stil der Einstellungs-Kacheln.
class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final BorderRadius? borderRadius;
  final Color? color;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: radius),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          secondary: icon == null ? null : Icon(icon, color: scheme.onSurface),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Auswahlleiste mit Beschriftung (z. B. Spalten, Ecken).
class SettingsSegmentField<T extends Object> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String? hint;

  const SettingsSegmentField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final e in options.entries)
                  ButtonSegment<T>(value: e.key, label: Text(e.value)),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
