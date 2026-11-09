import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:liblanis/liblanis.dart';

/// Einstellungs-Schlüssel für den Bereich, der beim Öffnen der App zuerst
/// erscheint. Leer = automatisch (erster verfügbarer Bereich).
const startPageSettingKey = 'start-page';

/// Dialog, in dem die Startseite gewählt werden kann.
Future<void> showStartPageDialog(BuildContext context) async {
  final shared = ProviderScope.containerOf(
    context,
  ).read(sharedOverAccountSettingsProvider);
  final current = shared.getString(startPageSettingKey) ?? 'dashboard';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Widget option(String value, String label) => ListTile(
        title: Text(label),
        trailing: current == value ? const Icon(Icons.check) : null,
        onTap: () {
          shared.setString(startPageSettingKey, value);
          Navigator.pop(dialogContext);
        },
      );
      return SimpleDialog(
        title: const Text('Startseite'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Dieser Bereich öffnet sich beim nächsten Start der App.'),
          ),
          option('dashboard', 'Kachel-Übersicht (Standard)'),
          option('auto', 'Erster verfügbarer Bereich'),
          for (final def in AppDefinitions.homeApplets)
            option(def.pathSegment, def.label(dialogContext)),
        ],
      );
    },
  );
}
