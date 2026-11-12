import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:watch_connectivity_garmin/watch_connectivity_garmin.dart';

/// ID der Garmin-App (steht in garmin/manifest.xml auf dem Branch "garmin").
const garminAppId = 'a310ed80-12b3-4086-9623-15db0f0699c2';

String _clean(Object? v) {
  final t = (v ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return (t == '-' || t == '---') ? '' : t;
}

String _cut(String s, int n) => s.length <= n ? s : s.substring(0, n);

int _min(SphTimeOfDay t) => t.hour * 60 + t.minute;

/// Schickt Stundenplan und Vertretungen (heute, sonst nächster Schultag)
/// an die Garmin-Uhr. Gibt eine Fehlermeldung zurück oder null bei Erfolg.
Future<String?> sendToGarmin(WidgetRef ref) async {
  try {
    final tt =
        (ref.read(timetableParserProvider) as dynamic).latestResponse?.content
            as TimeTable?;
    final plan = tt == null ? null : (tt.planForOwn ?? tt.planForAll);
    if (plan == null || plan.isEmpty) {
      return 'Öffne zuerst einmal den Stundenplan in der App, damit Daten da sind.';
    }

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
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
      final sp =
          (ref.read(substitutionsParserProvider) as dynamic)
                  .latestResponse
                  ?.content
              as SubstitutionPlan?;
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
          'Ist sie installiert und die Uhr verbunden?';
    }
    await garmin.sendMessage({'lessons': lessonList, 'subs': subList});
    return null;
  } catch (e) {
    return 'Senden an die Garmin-Uhr ist fehlgeschlagen.';
  }
}
