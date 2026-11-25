import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/look.dart';
import 'package:lanis/utils/logger.dart';

/// Zahlenbereich aus "3" oder "3 - 4" (Vertretungsplan) bzw. Stundenbezeichnung.
List<int> _range(String? s) {
  final n = RegExp(r'\d+')
      .allMatches(s ?? '')
      .map((m) => int.parse(m.group(0)!))
      .toList();
  if (n.isEmpty) return const [];
  final a = n.first, b = n.length > 1 ? n.last : n.first;
  return [for (var i = a; i <= b; i++) i];
}

bool _isCancelText(String? text) {
  final t = (text ?? '')
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue');
  return t.contains('entf') ||
      t.contains('ausfall') ||
      t.contains('freisetz') ||
      t.contains('faellt aus') ||
      t.contains('faellt ersatzlos') ||
      t.contains('faellt weg') ||
      t.contains('entfaellt') ||
      t.contains('unterrichtsfrei');
}

final Set<String> _loggedCancel = {};

/// Ist dieser Vertretungseintrag ein Ausfall (kein Ersatz)?
bool isCancelSubstitution(Substitution s) =>
    _isCancelText(s.art) || _isCancelText(s.hinweis) || _isCancelText(s.hinweis2);

/// Stundennummern aus "3" oder "3 - 4".
List<int> substitutionHours(String? s) => _range(s);

/// Stundennummern, die eine Stunde im Plan belegt.
Set<int> lessonHourNumbers(TimetableSubject s, List<TimeTableRow> hours) {
  final startRow = hours.where(
    (h) => h.type == TimeTableRowType.lesson && h.startTime == s.startTime,
  );
  if (startRow.isEmpty) return {};
  final from = _range(startRow.first.label);
  if (from.isEmpty) return {};
  return {for (var k = 0; k < s.duration; k++) from.first + k};
}

/// Fällt [s] am Tag [date] laut Vertretungsplan aus?
bool isLessonCancelled(
  BuildContext context,
  TimetableSubject s,
  DateTime date,
  List<TimeTableRow> hours,
) {
  if (!AppLook.greyCancelled) return false;
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final plan =
        (container.read(substitutionsParserProvider) as dynamic)
                .latestResponse
                ?.content
            as SubstitutionPlan?;
    if (plan == null) return false;

    final startRow = hours.where(
      (h) => h.type == TimeTableRowType.lesson && h.startTime == s.startTime,
    );
    final first = startRow.isEmpty ? null : startRow.first;
    final lessonNums = <int>{};
    if (first != null) {
      final from = _range(first.label);
      if (from.isNotEmpty) {
        for (var k = 0; k < s.duration; k++) {
          lessonNums.add(from.first + k);
        }
      }
    }
    if (lessonNums.isEmpty) return false;

    final name = (s.name ?? '').toLowerCase().trim();
    for (final d in plan.days) {
      final dt = d.dateTime;
      if (dt.year != date.year || dt.month != date.month || dt.day != date.day) {
        continue;
      }
      for (final sub in d.substitutions) {
        if (!_isCancelText(sub.art) &&
            !_isCancelText(sub.hinweis) &&
            !_isCancelText(sub.hinweis2)) {
          continue;
        }
        if (!_range(sub.stunde).any(lessonNums.contains)) continue;
        final f = (sub.fach_alt ?? sub.fach ?? '').toLowerCase().trim();
        if (f.isNotEmpty && name.isNotEmpty && !(name.contains(f) || f.contains(name))) {
          continue;
        }
        final key = '${date.year}-${date.month}-${date.day}|${s.name}|${sub.stunde}';
        if (_loggedCancel.add(key)) {
          logger.i(
            'Ausfall erkannt: ${s.name} am ${date.day}.${date.month}. '
            '(Stunde ${sub.stunde}, art="${sub.art}", hinweis="${sub.hinweis}")',
          );
        }
        return true;
      }
    }
  } catch (e) {
    logger.e('Ausfall-Erkennung fehlgeschlagen: $e');
  }
  return false;
}
