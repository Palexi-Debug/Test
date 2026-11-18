import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/garmin_sync.dart';
import 'package:lanis/utils/watch_sync.dart';

/// Alle Uhren-Sync-Funktionen an einem Ort, mit Erklärungen und
/// Ausweich-Möglichkeiten, falls etwas nicht klappt.
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  String? _busy;
  final Map<String, String> _result = {};

  Future<void> _run(String key, Future<String?> Function() job) async {
    if (_busy != null) return;
    setState(() {
      _busy = key;
      _result.remove(key);
    });
    String? msg;
    try {
      msg = await job();
    } catch (e) {
      msg = 'Fehler: $e';
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _result[key] = msg ?? 'Erfolgreich.';
    });
  }

  String _lastGarmin() {
    try {
      final raw = ref
          .read(sharedOverAccountSettingsProvider)
          .getString('garmin-last');
      if (raw == null || raw.isEmpty) return 'Noch nie gesendet.';
      final parts = raw.split('|');
      final t = DateTime.tryParse(parts.first)?.toLocal();
      if (t == null) return 'Noch nie gesendet.';
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      final ok = parts.length > 1 && parts[1] == 'ok';
      return 'Zuletzt: ${t.day}.${t.month}. um $hh:$mm Uhr – '
          '${ok ? 'erfolgreich' : 'fehlgeschlagen'}';
    } catch (_) {
      return 'Noch nie gesendet.';
    }
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _action({
    required String key,
    required String label,
    required IconData icon,
    required Future<String?> Function() job,
    bool tonal = false,
  }) {
    final busy = _busy == key;
    final onPressed = _busy == null ? () => _run(key, job) : null;
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Icon(icon);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: tonal
                ? FilledButton.tonalIcon(
                    onPressed: onPressed,
                    icon: child,
                    label: Text(label),
                  )
                : FilledButton.icon(
                    onPressed: onPressed,
                    icon: child,
                    label: Text(label),
                  ),
          ),
          if (_result[key] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                _result[key]!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _backup(List<String> steps) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('Klappt nicht? Ausweich-Möglichkeiten'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}. ${steps[i]}'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final garminAuto = shared.getString('garmin-enabled') == '1';
    return Scaffold(
      appBar: AppBar(title: const Text('Sync mit Uhren')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Hier steuerst du alles, was zwischen Handy und Uhr abgeglichen '
              'wird. Die Uhr holt die Daten nie selbst vom Schulportal, sie '
              'bekommt sie vom Handy.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _section('Wear OS (Samsung, Pixel, …)', Icons.watch_rounded, [
            _note(
              'Überträgt dein Konto an die Uhr, damit sie sich selbst '
              'anmelden und Stundenplan und Vertretungen laden kann. Öffne '
              'vorher auf der Uhr die Schulportal-App (Seite „Mit Handy '
              'verbinden“). Die Zugangsdaten werden danach aus der Kopplung '
              'wieder entfernt.',
            ),
            _action(
              key: 'wear-login',
              label: 'Login auf die Uhr übertragen',
              icon: Icons.login_rounded,
              job: () async => await sendLoginToWatch(ref) ?? 'Uhr ist angemeldet.',
            ),
            _note(
              'Eigene Stunden, ausgeblendete Stunden und Farben werden '
              'automatisch übertragen. Falls etwas fehlt:',
            ),
            _action(
              key: 'wear-tt',
              label: 'Stundenplan-Einstellungen erneut senden',
              icon: Icons.sync_rounded,
              tonal: true,
              job: () async {
                final st = ref.read(accountSpecificSettingsProvider);
                if (st == null) return 'Kein Konto angemeldet.';
                await syncTimetableToWatch(st);
                return 'Gesendet (die Uhr übernimmt es beim nächsten Öffnen).';
              },
            ),
            _backup([
              'Bluetooth am Handy und an der Uhr einschalten, die Uhr muss in '
                  'der Wear-OS-App verbunden sein.',
              'Auf der Uhr die Schulportal-App öffnen und auf der Seite „Mit '
                  'Handy verbinden“ bleiben, dann erneut senden.',
              'Geht es weiter nicht: auf der Uhr „Manuell anmelden“ antippen '
                  'und Benutzername und Passwort direkt eingeben.',
              'Wenn die Uhr alte Daten zeigt: Schulportal auf der Uhr '
                  'schließen und neu öffnen.',
            ]),
          ]),
          _section('Garmin (Venu Sq 2)', Icons.watch_outlined, [
            _note(
              'Schickt Stundenplan und Vertretungen (heute, sonst der nächste '
              'Schultag) über Garmin Connect an die Uhr. Die Schulportal-App '
              'muss dafür auf der Uhr geöffnet sein.',
            ),
            Text(
              _lastGarmin(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            _action(
              key: 'garmin-send',
              label: 'Jetzt an Garmin senden',
              icon: Icons.send_rounded,
              job: () async {
                final err = await sendToGarmin(ref);
                return err ?? 'An die Garmin-Uhr gesendet.';
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatisch im Hintergrund senden'),
              subtitle: const Text(
                'Ungefähr alle 15 Minuten und beim Öffnen der App. '
                'Wird nach dem ersten erfolgreichen Senden eingeschaltet.',
              ),
              value: garminAuto,
              onChanged: (v) {
                shared.setString('garmin-enabled', v ? '1' : '0');
                setState(() {});
              },
            ),
            _action(
              key: 'garmin-check',
              label: 'Verbindung prüfen',
              icon: Icons.network_check_rounded,
              tonal: true,
              job: garminCheck,
            ),
            _backup([
              'Garmin Connect muss auf dem Handy installiert und die Uhr '
                  'per Bluetooth verbunden sein.',
              'Auf der Uhr die Schulportal-App öffnen und offen lassen, '
                  'dann „Jetzt an Garmin senden“.',
              'Auf der Uhr die Seite „Info“ öffnen: dort stehen Version und '
                  'Sync-Stand. Die Uhr merkt sich die letzten Daten auch '
                  'ohne Handy.',
              'Zeigt die Uhr nur Beispieldaten, ist noch nie etwas '
                  'angekommen: erst „Verbindung prüfen“, dann erneut senden.',
              'Erscheint immer ein Fehler, hilft meist eine neuere Version '
                  'der Garmin-App (.prg per USB nach GARMIN/Apps kopieren).',
              'Fehlermeldungen stehen im Log (Entwickler-Menü in den Einstellungen).',
            ]),
          ]),
        ],
      ),
    );
  }
}
