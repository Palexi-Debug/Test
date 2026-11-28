import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:liblanis/liblanis.dart';

/// Klausuren, Arbeiten, Tests und Prüfungen erkennt die Erinnerung am Titel.
final RegExp _examLike = RegExp(
  r'klausur|klassenarbeit|arbeit|test|prüfung|pruefung|abitur|lernkontrolle|'
  r'schulaufgabe|vokabel|präsentation|praesentation',
  caseSensitive: false,
);

String _two(int v) => v.toString().padLeft(2, '0');

/// Erinnert an anstehende Termine: am Vortag ab 16 Uhr ("Morgen") und am Tag
/// selbst ab 6 Uhr ("Heute"). Standard: nur Klausuren/Arbeiten/Tests; mit dem
/// Schalter "calendar-remind-all" (Einstellungen > Benachrichtigungen) alle.
Future<void> calendarBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit toolkit,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final remindAll = toolkit.settings.getBool('calendar-remind-all') ?? false;

  final events = await container
      .read(calendarParserProvider)
      .getCalendar(
        startDate: today,
        endDate: today.add(const Duration(days: 3)),
      );

  for (final e in events) {
    final label = '${e.title} ${e.category?.name ?? ''}';
    if (!remindAll && !_examLike.hasMatch(label)) continue;

    final day = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final isTomorrow = day == tomorrow && now.hour >= 16;
    final isToday = day == today && now.hour >= 6 && e.endTime.isAfter(now);
    if (!isTomorrow && !isToday) continue;

    final parts = <String>[
      if (!e.allDay) '${_two(e.startTime.hour)}:${_two(e.startTime.minute)} Uhr',
      if ((e.place ?? '').trim().isNotEmpty) e.place!.trim(),
    ];
    final base = (e.id.hashCode & 0x7fffffff) % 5000;
    await toolkit.sendMessage(
      id: isToday ? 5000 + base : base,
      title: isToday ? 'Heute: ${e.title}' : 'Morgen: ${e.title}',
      message: parts.isEmpty ? 'Termin im Schulkalender' : parts.join(' · '),
      avoidDuplicateSending: true,
      importance: Importance.defaultImportance,
    );
  }
}
