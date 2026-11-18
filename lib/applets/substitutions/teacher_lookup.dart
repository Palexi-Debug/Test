import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/view/wear/wear_mode.dart';

/// Filtert Suchtreffer auf das exakte Kürzel (steht am Ende in Klammern,
/// z. B. "Rebuschat, Rainer Gustav (RT)"). Die Suche trifft sonst jeden Namen,
/// der "rt" irgendwo enthält. Gibt es keinen exakten Treffer, bleibt die
/// ganze Liste.
List<ReceiverEntry> exactKuerzelMatches(
  List<ReceiverEntry> all,
  String kuerzel,
) {
  final k = kuerzel.trim().toLowerCase();
  final exact = all.where((e) {
    final m = RegExp(r'\(([^()]*)\)\s*$').firstMatch(e.name);
    return m != null && m.group(1)!.trim().toLowerCase() == k;
  }).toList();
  return exact.isNotEmpty ? exact : all;
}

typedef _KuerzelResult = (String, List<ReceiverEntry>, bool);

/// Zerlegt "HY, REI" / "HY/REI" / "HY und REI" in einzelne Kürzel.
List<String> splitKuerzel(String raw) {
  final seen = <String>{};
  return raw
      .split(RegExp(r'\s*(?:,|;|/|\+|&|\bund\b)\s*', caseSensitive: false))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && seen.add(e.toLowerCase()))
      .toList();
}

/// Voller Name zu einem Kürzel ("Nachname, Vorname") oder null.
Future<String?> teacherFullName(BuildContext context, String kuerzel) async {
  try {
    final parser = ProviderScope.containerOf(
      context,
    ).read(conversationsParserProvider);
    final list = exactKuerzelMatches(
      (await parser.searchTeacher(kuerzel)).where((e) => e.isTeacher).toList(),
      kuerzel,
    );
    if (list.isEmpty) return null;
    return list.first.name.replaceAll(RegExp(r'\s*\([^()]*\)\s*$'), '').trim();
  } catch (_) {
    return null;
  }
}

/// Zeigt zu einem Lehrerkürzel den vollen Namen. Die Namen kommen aus der
/// Empfängersuche des Nachrichten-Moduls (gleiche Suche wie beim Tippen eines
/// Kürzels in "Neue Nachricht"). Auf der Uhr gibt es eine eigene, kompakte
/// Ansicht für runde, kleine Displays.
Future<void> showTeacherNameDialog(BuildContext context, String raw) {
  final kuerzel = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  final parser = ProviderScope.containerOf(
    context,
  ).read(conversationsParserProvider);
  final parts = splitKuerzel(kuerzel);
  final future = Future.wait<_KuerzelResult>(
    parts.map<Future<_KuerzelResult>>((k) async {
      try {
        final r = await parser.searchTeacher(k);
        return (
          k,
          exactKuerzelMatches(r.where((e) => e.isTeacher).toList(), k),
          false,
        );
      } catch (_) {
        return (k, const <ReceiverEntry>[], true);
      }
    }),
  );
  final wear = WearMode.enabled;

  Widget body(BuildContext ctx) =>
      FutureBuilder<List<_KuerzelResult>>(
        future: future,
        builder: (context, snap) {
          final style = wear
              ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
              : Theme.of(context).textTheme.titleMedium;
          final align = wear ? TextAlign.center : TextAlign.start;
          if (snap.connectionState != ConnectionState.done) {
            return SizedBox(
              height: wear ? 36 : 56,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            );
          }
          final List<_KuerzelResult> results = snap.data ?? <_KuerzelResult>[];
          final multi = results.length > 1;
          if (results.isEmpty || results.every((r) => r.$3)) {
            return Text('Name konnte nicht geladen werden.', textAlign: align);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: wear
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              for (final r in results)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: wear ? 3 : 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: wear
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      if (multi)
                        Text(
                          r.$1,
                          textAlign: align,
                          style: TextStyle(
                            fontSize: wear ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      if (r.$2.isEmpty)
                        Text(
                          r.$3
                              ? 'Name konnte nicht geladen werden.'
                              : 'Kein Lehrer zu diesem Kürzel gefunden.',
                          textAlign: align,
                        )
                      else
                        for (final e in r.$2)
                          Text(e.name, style: style, textAlign: align),
                    ],
                  ),
                ),
            ],
          );
        },
      );

  if (wear) {
    // Uhr: schwarzer, randloser Dialog mit großer Tipp-Fläche zum Schließen.
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: InkWell(
          onTap: () => Navigator.pop(ctx),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 28, 34, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_search_rounded, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      kuerzel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    body(ctx),
                    const SizedBox(height: 10),
                    const Text(
                      'Tippen zum Schließen',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.person_search_rounded),
      title: Text(kuerzel),
      content: body(ctx),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
