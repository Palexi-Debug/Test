import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

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
/// Kürzels in "Neue Nachricht").
Future<void> showTeacherNameDialog(BuildContext context, String raw) {
  final kuerzel = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  final parser = ProviderScope.containerOf(
    context,
  ).read(conversationsParserProvider);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.person_search_rounded),
      title: Text(kuerzel),
      content: FutureBuilder<List<ReceiverEntry>>(
        future: parser.searchTeacher(kuerzel),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return const Text('Name konnte nicht geladen werden.');
          }
          final list = exactKuerzelMatches(
            (snap.data ?? const <ReceiverEntry>[])
                .where((e) => e.isTeacher)
                .toList(),
            kuerzel,
          );
          if (list.isEmpty) {
            return const Text('Kein Lehrer zu diesem Kürzel gefunden.');
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    e.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
