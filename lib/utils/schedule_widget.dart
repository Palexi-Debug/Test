import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liblanis/liblanis.dart';

const _channel = MethodChannel('de.palexi.schulportal/widget');
String? _lastSent;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Schickt den Wochenplan an das Homescreen-Widget (nur Android, nur wenn sich
/// etwas geändert hat). Das Widget rechnet die laufende Stunde selbst aus.
Future<void> updateScheduleWidget(
  List<TimetableDay> plan,
  DateTime weekStart,
) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final days = <String, dynamic>{};
    for (var d = 0; d < plan.length && d < 7; d++) {
      final date = DateTime(weekStart.year, weekStart.month, weekStart.day + d);
      final lessons = [...plan[d]]
        ..sort(
          (a, b) => (a.startTime.hour * 60 + a.startTime.minute).compareTo(
            b.startTime.hour * 60 + b.startTime.minute,
          ),
        );
      days[_iso(date)] = [
        for (final l in lessons)
          {
            's': l.startTime.hour * 60 + l.startTime.minute,
            'e': l.endTime.hour * 60 + l.endTime.minute,
            'n': (l.name ?? '').trim(),
            'r': (l.raum ?? '').trim(),
            'x': l.substituted,
          },
      ];
    }
    final json = jsonEncode({'days': days});
    if (json == _lastSent) return;
    _lastSent = json;
    await _channel.invokeMethod('update', {'json': json});
  } catch (_) {
    // Widget ist optional; Fehler (z. B. kein Kanal im Hintergrund) ignorieren.
  }
}
