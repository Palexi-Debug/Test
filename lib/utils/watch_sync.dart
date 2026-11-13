import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:lanis/utils/applet_settings.dart';

const watchLoginKind = 'schulportal-login-v1';
const watchTimetableKind = 'schulportal-tt-v1';
const _ttPrefix = 'stundenplan.php/';
const ttSyncKeys = ['custom-lessons', 'hidden-lessons', 'lesson-colors'];

/// Handy: schickt eigene Stunden, ausgeblendete Stunden und Farben an die Uhr.
/// Still im Hintergrund, Fehler werden ignoriert (Uhr evtl. nicht verbunden).
Future<void> syncTimetableToWatch(TypedSettings settings) async {
  try {
    final watch = WatchConnectivity();
    if (!await watch.isPaired) return;
    final payload = <String, dynamic>{
      'kind': watchTimetableKind,
      'custom': settings.getJsonList('${_ttPrefix}custom-lessons') ?? [],
      'hidden': settings.getJsonList('${_ttPrefix}hidden-lessons') ?? [],
      'colors': settings.getJsonMap('${_ttPrefix}lesson-colors') ?? {},
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    await watch.updateApplicationContext(payload);
    if (await watch.isReachable) {
      await watch.sendMessage(payload);
    }
  } catch (_) {}
}

/// Uhr: übernimmt die vom Handy gesendeten Stundenplan-Einstellungen.
/// Gibt true zurück, wenn etwas übernommen wurde.
bool applyTimetableFromPhone(Map<String, dynamic> m, TypedSettings? settings) {
  if (m['kind'] != watchTimetableKind || settings == null) return false;
  try {
    persistAppletSetting(
      settings,
      '${_ttPrefix}custom-lessons',
      List<dynamic>.from(m['custom'] as List? ?? const []),
    );
    persistAppletSetting(
      settings,
      '${_ttPrefix}hidden-lessons',
      List<dynamic>.from(m['hidden'] as List? ?? const []),
    );
    persistAppletSetting(
      settings,
      '${_ttPrefix}lesson-colors',
      Map<String, dynamic>.from(m['colors'] as Map? ?? const {}),
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// Handy: schickt das aktive Konto an die gekoppelte Uhr.
/// Gibt eine Fehlermeldung zurück oder null bei Erfolg.
/// Die Zugangsdaten werden danach immer wieder aus der Kopplung entfernt.
Future<String?> sendLoginToWatch(WidgetRef ref) async {
  final acc = ref.read(activeAccountProvider);
  if (acc == null) return 'Kein Konto angemeldet.';
  final watch = WatchConnectivity();
  try {
    if (!await watch.isPaired) {
      return 'Keine gekoppelte Uhr gefunden.';
    }
    final payload = <String, dynamic>{
      'kind': watchLoginKind,
      'school': acc.schoolID,
      'schoolName': acc.schoolName,
      'user': acc.username,
      'pass': acc.password,
      'type': acc.accountType?.name,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final ack = watch.messageStream
        .firstWhere((m) => m['kind'] == 'ack')
        .timeout(const Duration(seconds: 40));
    await watch.updateApplicationContext(payload);
    if (await watch.isReachable) {
      await watch.sendMessage(payload);
    }
    final reply = await ack;
    if (reply['ok'] == false) {
      return 'Die Uhr konnte sich nicht anmelden: ${reply['error'] ?? ''}';
    }
    return null;
  } on TimeoutException {
    return 'Keine Antwort von der Uhr. Öffne dort zuerst die Schulportal-App '
        '(Seite "Mit Handy verbinden") und versuche es noch einmal.';
  } catch (_) {
    return 'Senden an die Uhr ist fehlgeschlagen.';
  } finally {
    try {
      await watch.updateApplicationContext({'kind': 'cleared'});
    } catch (_) {}
    final st = ref.read(accountSpecificSettingsProvider);
    if (st != null) await syncTimetableToWatch(st);
  }
}
