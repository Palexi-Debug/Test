import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

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
          final list = (snap.data ?? const <ReceiverEntry>[])
              .where((e) => e.isTeacher)
              .toList();
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
