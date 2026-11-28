import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:watch_connectivity_garmin/watch_connectivity_garmin.dart';
import 'package:lanis/applets/timetable/student/apply_substitutions.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import 'package:lanis/core/school_schedule.dart';
import 'package:lanis/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// ID der Garmin-App (steht in garmin/manifest.xml auf dem Branch "garmin").
const garminAppId = 'a310ed80-12b3-4086-9623-15db0f0699c2';

String _clean(Object? v) {
  final t = (v ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return (t == '-' || t == '---') ? '' : t;
}

String _cut(String s, int n) => s.length <= n ? s : s.substring(0, n);

int _min(SphTimeOfDay t) => t.hour * 60 + t.minute;

/// Prüft (und fragt bei Bedarf) die Bluetooth-Berechtigung, die Android 12+
/// für die Verbindung zu Garmin Connect verlangt. Gibt eine deutsche
/// Fehlermeldung zurück oder null, wenn alles passt. Im Hintergrund
/// ([ask] = false) wird nur geprüft, nicht gefragt.
Future<String?> _ensureBluetooth({bool ask = true}) async {
  if (!Platform.isAndroid) return null;
  try {
    var status = await Permission.bluetoothConnect.status;
    if (!status.isGranted && ask) {
      status = await Permission.bluetoothConnect.request();
    }
    if (status.isGranted || status.isLimited) return null;
    return status.isPermanentlyDenied
        ? 'Die Bluetooth-Berechtigung ("Geräte in der Nähe") fehlt. Bitte '
            'in den Android-Einstellungen der App erlauben, damit die Garmin-'
            'Uhr erreichbar ist.'
        : 'Ohne die Bluetooth-Berechtigung ("Geräte in der Nähe") kann die '
            'App nicht mit der Garmin-Uhr sprechen.';
  } catch (_) {
    // Plugin/ältere Android-Version: nicht blockieren, Senden selbst prüft.
    return null;
  }
}

/// Macht aus technischen Fehlern eine verständliche deutsche Meldung.
String _garminErrorText(Object e) {
  final t = e.toString();
  final low = t.toLowerCase();
  if (low.contains('securityexception') || low.contains('bluetooth_connect')) {
    return 'Die Bluetooth-Berechtigung fehlt. Bitte "Geräte in der Nähe" für '
        'die App erlauben.';
  }
  if (low.contains('bluetooth')) {
    return 'Bluetooth scheint ausgeschaltet zu sein. Bitte einschalten und '
        'erneut versuchen.';
  }
  if (low.contains('not installed') || low.contains('connect iq')) {
    return 'Die Garmin-Connect-App ist nicht installiert oder nicht bereit.';
  }
  return 'Senden an die Garmin-Uhr ist fehlgeschlagen: $t';
}

/// Schickt Stundenplan und Vertretungen (heute, sonst nächster Schultag)
/// an die Garmin-Uhr. Gibt eine Fehlermeldung zurück oder null bei Erfolg.
Future<String?> sendToGarmin(WidgetRef ref, {bool ask = true}) async {
  TimeTable? tt;
  SubstitutionPlan? sp;
  try {
    tt =
        (ref.read(timetableParserProvider) as dynamic).latestResponse?.content
            as TimeTable?;
  } catch (_) {}
  try {
    sp =
        (ref.read(substitutionsParserProvider) as dynamic).latestResponse
                ?.content
            as SubstitutionPlan?;
  } catch (_) {}
  final err = await _sendData(tt, sp, ask: ask);
  final shared = ref.read(sharedOverAccountSettingsProvider);
  if (err == null) {
    shared.setString('garmin-enabled', '1');
  }
  recordGarminResult(shared, err);
  return err;
}

/// Merkt sich Zeit und Ergebnis des letzten Sendens (für die Sync-Seite).
void recordGarminResult(dynamic shared, String? err) {
  try {
    shared.setString(
      'garmin-last',
      '${DateTime.now().toIso8601String()}|${err == null ? 'ok' : 'fehler'}',
    );
  } catch (_) {}
}

/// Prüft die Verbindung zur Garmin-App/Uhr, ohne Daten zu senden.
Future<String> garminCheck() async {
  try {
    final permError = await _ensureBluetooth();
    if (permError != null) return permError;
    final garmin = WatchConnectivityGarmin();
    await garmin.initialize(
      const GarminInitializationOptions(
        applicationId: garminAppId,
        urlScheme: 'schulportal-garmin',
      ),
    );
    if (!await garmin.isSupported) {
      return 'Garmin Connect ist auf dem Handy nicht installiert.';
    }
    if (!await garmin.isReachable) {
      return 'Garmin Connect ist da, aber die Schulportal-App auf der Uhr '
          'antwortet nicht. Öffne sie auf der Uhr und prüfe die '
          'Bluetooth-Verbindung in Garmin Connect.';
    }
    return 'Verbindung in Ordnung. Die Uhr ist erreichbar.';
  } catch (e) {
    return _garminErrorText(e);
  }
}

/// Hintergrund-Variante (ohne Oberfläche): holt Stundenplan und Vertretungen
/// frisch vom Server und schickt sie an die Uhr. Nur wenn schon einmal
/// erfolgreich gesendet wurde. Erwartet eine angemeldete Sitzung.
Future<void> sendToGarminHeadless(ProviderContainer container) async {
  try {
    final shared = container.read(sharedOverAccountSettingsProvider);
    if (shared.getString('garmin-enabled') != '1') return;
    final tt =
        await (container.read(timetableParserProvider) as dynamic).getHome()
            as TimeTable?;
    SubstitutionPlan? sp;
    try {
      sp =
          await (container.read(substitutionsParserProvider) as dynamic)
                  .getHome()
              as SubstitutionPlan?;
    } catch (_) {}
    final err = await _sendData(tt, sp, ask: false);
    recordGarminResult(shared, err);
  } catch (_) {}
}

bool _inWeekG(TimetableSubject l, String weekBadge) {
  final b = (l.badge ?? '').trim();
  if (TimeTableData.isHalfYearBadge(b)) {
    return TimeTableData.halfYearActive(b, DateTime.now());
  }
  if (weekBadge.isEmpty || b.isEmpty) return true;
  return weekBadge == b;
}

/// Plan der aktuellen G/U-Woche mit eingesetzten Vertretungen.
List<TimetableDay>? _garminPlan(TimeTable? tt, SubstitutionPlan? sp) {
  final raw = tt == null ? null : (tt.planForOwn ?? tt.planForAll);
  if (raw == null || tt == null) return raw;
  try {
    final wb = (tt.weekBadge ?? '').trim();
    final withSubs = applySubstitutions(
      plan: raw,
      hours: tt.hours ?? const <TimeTableRow>[],
      subs: sp,
      weekStart: timetableWeekStart(
        DateTime.tryParse(tt.weekDate ?? '') ?? DateTime.now(),
      ),
    );
    return withSubs
        .map((d) => d.where((l) => _inWeekG(l, wb)).toList())
        .toList();
  } catch (_) {
    return raw;
  }
}

Future<String?> _sendData(
  TimeTable? tt,
  SubstitutionPlan? sp, {
  bool ask = true,
}) async {
  try {
    final plan = _garminPlan(tt, sp);
    if (plan == null || plan.isEmpty) {
      return 'Öffne zuerst einmal den Stundenplan in der App, damit Daten da sind.';
    }

    final now = DateTime.now();
    final nowMin = SchoolSchedule.minutesOf(now);
    List<TimetableSubject> lessonsOf(int d) {
      if (d < 0 || d >= plan.length) return [];
      return [...plan[d]]
        ..sort((a, b) => _min(a.startTime).compareTo(_min(b.startTime)));
    }

    var dayIndex = now.weekday - 1;
    var lessons = lessonsOf(dayIndex);
    if (lessons.isEmpty || nowMin >= _min(lessons.last.endTime)) {
      for (var k = 1; k <= 7; k++) {
        final d = (now.weekday - 1 + k) % 7;
        final l = lessonsOf(d);
        if (l.isNotEmpty) {
          dayIndex = d;
          lessons = l;
          break;
        }
      }
    }
    final target = now.add(
      Duration(days: (dayIndex - (now.weekday - 1) + 7) % 7),
    );

    final lessonList = [
      for (final l in lessons.take(10))
        {
          's': _min(l.startTime),
          'e': _min(l.endTime),
          'n': _cut(_clean(l.name), 16),
          'r': _cut(_clean(l.raum), 8),
        },
    ];

    final subList = <Map<String, dynamic>>[];
    try {
      if (sp != null) {
        final dd = DateFormat('dd.MM.yyyy').format(target);
        final iso = DateFormat('yyyy-MM-dd').format(target);
        for (final d in sp.days) {
          final p = d.parsedDate.toString();
          if (!(p.contains(dd) || p.contains(iso))) continue;
          for (final s in d.substitutions.take(8)) {
            final x = s as dynamic;
            subList.add({
              'std': _cut(_clean(x.stunde), 6),
              'fach': _cut(_clean(x.fach), 14),
              'art': _cut(_clean(x.art), 14),
              'vertr': _cut(_clean(x.vertreter), 6),
              'raum': _cut(_clean(x.raum), 6),
            });
          }
        }
      }
    } catch (_) {}

    final permError = await _ensureBluetooth(ask: ask);
    if (permError != null) return permError;

    // Index der laufenden oder nächsten Stunde (nur für den heutigen Tag),
    // damit die Uhr direkt dorthin scrollt.
    var idx = 0;
    if (dayIndex == now.weekday - 1) {
      idx =
          SchoolSchedule.currentOrNextInList([
            for (final l in lessons.take(10))
              (start: _min(l.startTime), end: _min(l.endTime)),
          ], now) ??
          0;
    }

    final garmin = WatchConnectivityGarmin();
    await garmin.initialize(
      const GarminInitializationOptions(
        applicationId: garminAppId,
        urlScheme: 'schulportal-garmin',
      ),
    );
    if (!await garmin.isSupported) {
      return 'Die Garmin-Connect-App ist nicht installiert.';
    }
    if (!await garmin.isReachable) {
      return 'Die Schulportal-App ist auf der Garmin-Uhr nicht erreichbar. '
          'Uhr per Bluetooth in Garmin Connect verbunden? Schulportal-App auf '
          'der Uhr öffnen und offen lassen, dann erneut senden. Auf der Uhr '
          'muss die neueste Version (Seite "Info") installiert sein.';
    }
    final wk = (tt?.weekBadge ?? '').trim();
    await garmin.sendMessage({
      'lessons': lessonList,
      'subs': subList,
      'wk': wk.length <= 1 ? wk : '',
      'idx': idx,
    });
    logger.i('Garmin: ${lessonList.length} Stunden, ${subList.length} Vertretungen gesendet');
    return null;
  } catch (e) {
    logger.e('Garmin: Senden fehlgeschlagen: $e');
    return _garminErrorText(e);
  }
}


DateTime _lastAutoGarmin = DateTime.fromMillisecondsSinceEpoch(0);

/// Automatischer Abgleich: nur wenn schon einmal erfolgreich an die Garmin-Uhr
/// gesendet wurde, höchstens alle 8 Minuten, ohne Fehlermeldung.
Future<void> autoSyncGarmin(WidgetRef ref) async {
  try {
    final shared = ref.read(sharedOverAccountSettingsProvider);
    if (shared.getString('garmin-enabled') != '1') return;
    final now = DateTime.now();
    if (now.difference(_lastAutoGarmin) < const Duration(minutes: 8)) return;
    _lastAutoGarmin = now;
    await sendToGarmin(ref, ask: false);
  } catch (_) {}
}
