import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/widgets/press_tile.dart';
import 'package:lanis/widgets/settings_widgets.dart';
import 'package:liblanis/liblanis.dart';

/// Alle Einstellungen rund um den Vertretungsplan an einer Stelle.
class SubstitutionsSettings extends ConsumerSettingsColours {
  const SubstitutionsSettings({super.key});

  @override
  ConsumerState<SubstitutionsSettings> createState() =>
      _SubstitutionsSettingsState();
}

class _SubstitutionsSettingsState
    extends ConsumerSettingsColoursState<SubstitutionsSettings> {
  static const _subsInPlan = 'tt-subs-in-plan';
  static const _greyCancelled = 'tt-grey-cancelled';

  bool _on(String key) =>
      ref.read(sharedOverAccountSettingsProvider).getString(key) != '0';

  void _set(String key, bool value) {
    ref.read(sharedOverAccountSettingsProvider).setString(key, value ? '1' : '0');
    if (key == _greyCancelled) notifyThemeChanged(ref);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final inPlan = _on(_subsInPlan);
    final grey = _on(_greyCancelled);
    return SettingsPage(
      backgroundColor: backgroundColor,
      title: const Text('Vertretungsplan'),
      fallbackLocation: SettingsDeepLinks.home,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SettingsSectionHeader('Im Stundenplan'),
            SettingsSwitchTile(
              icon: Icons.swap_horiz_rounded,
              title: 'Vertretungen einsetzen',
              subtitle:
                  'Geänderte Stunden (Vertretung, Raumwechsel) erscheinen direkt im Stundenplan',
              value: inPlan,
              color: foregroundColor,
              borderRadius: settingsGroupRadius(0, 2),
              onChanged: (v) => _set(_subsInPlan, v),
            ),
            SettingsSwitchTile(
              icon: Icons.event_busy_rounded,
              title: 'Ausfälle grau anzeigen',
              subtitle: 'Entfallende Stunden werden im Stundenplan grau',
              value: grey,
              color: foregroundColor,
              borderRadius: settingsGroupRadius(1, 2),
              onChanged: (v) => _set(_greyCancelled, v),
            ),
            const SettingsSectionHeader('Filter'),
            PressTile(
              title: 'Vertretungen filtern',
              subtitle: 'Nach Klasse, Fach, Lehrer, Raum oder Art',
              icon: Icons.filter_alt_rounded,
              foregroundColor: foregroundColor,
              onPressed: () => context.push('/common/substitutions/filter'),
            ),
          ],
        ),
      ],
    );
  }
}
