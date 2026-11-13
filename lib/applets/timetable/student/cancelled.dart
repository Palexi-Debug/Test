import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/look.dart';

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

bool _isCancelText(String? art) {
  final t = (art ?? '').toLowerCase();
  return t.contains('entf') || t.contains('ausfall') || t.contains('freisetz');
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
        if (!_isCancelText(sub.art)) continue;
        if (!_range(sub.stunde).any(lessonNums.contains)) continue;
        final f = (sub.fach_alt ?? sub.fach ?? '').toLowerCase().trim();
        if (f.isNotEmpty && name.isNotEmpty && !(name.contains(f) || f.contains(name))) {
          continue;
        }
        return true;
      }
    }
  } catch (_) {}
  return false;
}
