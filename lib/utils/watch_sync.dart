import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

const watchLoginKind = 'schulportal-login-v1';

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
  }
}
