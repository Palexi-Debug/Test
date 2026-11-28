/// Unterrichtszeiten der Philipp-Reis-Schule (Minuten seit Mitternacht).
///
/// Eine gemeinsame Quelle für Dashboard (Handy), Wear OS und den
/// Garmin-Abgleich, damit überall dieselbe Zeitbasis gilt.
class SchoolSchedule {
  const SchoolSchedule._();

  /// Beginn je Stunde (1. bis 9. Stunde): 08:00 … 15:25
  static const List<int> starts = [480, 525, 595, 640, 705, 750, 840, 880, 925];

  /// Ende je Stunde (1. bis 9. Stunde): 08:45 … 16:05
  static const List<int> ends = [525, 570, 640, 685, 750, 795, 880, 920, 965];

  static int get lessonCount => starts.length;

  /// Minuten seit Mitternacht für [t].
  static int minutesOf(DateTime t) => t.hour * 60 + t.minute;

  /// Index (0-basiert) der Stunde, die gerade läuft, sonst der nächsten
  /// anstehenden. `null`, wenn der Schultag vorbei ist.
  static int? currentOrNextIndex(DateTime now) {
    final m = minutesOf(now);
    for (var i = 0; i < ends.length; i++) {
      if (m < ends[i]) return i;
    }
    return null;
  }

  /// Wie [currentOrNextIndex], aber für eine beliebige Stundenliste mit
  /// Beginn/Ende in Minuten. Gibt den Listenindex der laufenden oder
  /// nächsten Stunde zurück, `null` wenn alle vorbei sind.
  static int? currentOrNextInList(
    List<({int start, int end})> lessons,
    DateTime now,
  ) {
    final m = minutesOf(now);
    for (var i = 0; i < lessons.length; i++) {
      if (m < lessons[i].end) return i;
    }
    return null;
  }
}
