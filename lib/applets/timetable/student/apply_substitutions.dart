import 'dart:math';

import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/cancelled.dart';

String _krz(String? s) =>
    (s ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim().toLowerCase();

String _clean(String? s) {
  final t = (s ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return (t == '-' || t == '---') ? '' : t;
}

/// Setzt Vertretungen (Ersatz, Raumwechsel, Verlegung) in den Stundenplan ein.
/// Ausfälle bleiben unverändert (die zeigt der Stundenplan durchsichtig).
///
/// Eine Vertretung gehört zu einer Plan-Stunde, wenn die Stundennummern
/// überlappen und der Lehrer übereinstimmt (ein Lehrer kann nicht zwei Klassen
/// gleichzeitig unterrichten). Fehlt der Lehrer, entscheidet das Fach.
/// [weekStart] ist der Montag der angezeigten Woche.
List<TimetableDay> applySubstitutions({
  required List<TimetableDay> plan,
  required List<TimeTableRow> hours,
  required SubstitutionPlan? subs,
  required DateTime weekStart,
}) {
  if (subs == null || plan.isEmpty || hours.isEmpty) return plan;
  final allNames = <String>{
    for (final d in plan)
      for (final l in d)
        if ((l.name ?? '').isNotEmpty) l.name!,
  };
  final out = <TimetableDay>[];
  for (var d = 0; d < plan.length; d++) {
    final date = DateTime(weekStart.year, weekStart.month, weekStart.day + d);
    SubstitutionDay? day;
    for (final x in subs.days) {
      final dt = x.dateTime;
      if (dt.year == date.year && dt.month == date.month && dt.day == date.day) {
        day = x;
        break;
      }
    }
    if (day == null) {
      out.add(plan[d]);
      continue;
    }
    final entries =
        day.substitutions.where((s) => !isCancelSubstitution(s)).toList();
    if (entries.isEmpty) {
      out.add(plan[d]);
      continue;
    }
    out.add([for (final l in plan[d]) _replace(l, entries, hours, allNames)]);
  }
  return out;
}

TimetableSubject _replace(
  TimetableSubject l,
  List<Substitution> entries,
  List<TimeTableRow> hours,
  Set<String> allNames,
) {
  final nums = lessonHourNumbers(l, hours);
  if (nums.isEmpty) return l;
  final lname = _krz(l.name);
  final lteacher = _krz(l.lehrer);
  for (final s in entries) {
    if (!substitutionHours(s.stunde).any(nums.contains)) continue;
    final sTeacher = _krz(s.lehrer ?? s.Lehrerkuerzel);
    final bool match;
    if (sTeacher.isNotEmpty && lteacher.isNotEmpty) {
      match = sTeacher == lteacher;
    } else {
      final f = _krz(s.fach_alt ?? s.fach);
      match = f.isNotEmpty &&
          lname.isNotEmpty &&
          (lname.contains(f) || f.contains(lname));
    }
    if (!match) continue;

    var newName = _clean(s.fach);
    final hint = _clean(s.hinweis);
    String? note = hint.isEmpty ? null : hint;
    // "Sport, statt 3./4." -> neues Fach steht im Hinweis.
    final m = RegExp(
      r'^\s*([^,]+?)\s*,?\s*statt\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(hint);
    if (m != null) {
      final fromHint = m.group(1)!.trim();
      final low = fromHint.toLowerCase();
      newName = fromHint;
      for (final n in allNames) {
        final nl = n.toLowerCase();
        if (nl.length >= 2 && low.startsWith(nl.substring(0, min(3, nl.length)))) {
          newName = n;
          break;
        }
      }
      note = 'statt ${m.group(2)!.trim()}';
    }
    final raum = _clean(s.raum);
    final vertreter = _clean(s.vertreter ?? s.Vertreterkuerzel);
    return TimetableSubject(
        id: l.id,
        name: newName.isEmpty ? l.name : newName,
        raum: raum.isEmpty ? l.raum : raum,
        lehrer: vertreter.isEmpty ? l.lehrer : vertreter,
        badge: l.badge,
        duration: l.duration,
        startTime: l.startTime,
        endTime: l.endTime,
        stunde: l.stunde,
      )
      ..substituted = true
      ..substitutionNote = note;
  }
  return l;
}
