import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart'
    show formatDate;
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:liblanis/liblanis.dart';

/// Experimentelle Wear-OS-Ansicht: nur der Vertretungsplan, sehr einfach.
class WearSubstitutionsPage extends ConsumerWidget {
  const WearSubstitutionsPage({super.key});

  static String _t(Object? value) {
    final s = value?.toString().trim() ?? '';
    return (s == '-' || s == '---') ? '' : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final parser = ref.watch(substitutionsParserProvider);
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: CombinedAppletBuilder<SubstitutionPlan>(
          accountType:
              session.accountTypeOrNull ??
              ref.read(activeAccountProvider)?.accountType ??
              AccountType.student,
          parser: parser,
          phpUrl: substitutionDefinition.appletPhpUrl,
          settingsDefaults: substitutionDefinition.settingsDefaults,
          builder:
              (context, data, accountType, settings, updateSetting, refresh) =>
                  _buildList(context, data, refresh),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    SubstitutionPlan data,
    RefreshFunction? refresh,
  ) {
    final days = data.days.where((d) => d.substitutions.isNotEmpty).toList();
    final children = <Widget>[];

    if (days.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(
            child: Text(
              'Keine Vertretungen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    for (final day in days) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            formatDate(day.parsedDate),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
      for (final s in day.substitutions) {
        children.add(_entry(context, s));
      }
    }

    // Kein Pull-to-Refresh: Wischen am Rand wechselt die Seite (WearHome).
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 34, 40),
      children: children,
    );
  }

  Widget _entry(BuildContext context, Substitution s) {
    final stunde = _t(s.stunde);
    final fach = _t(s.fach);
    final art = _t(s.art);
    final raum = _t(s.raum);
    final vertreter = _t(s.vertreter);
    final hinweis = _t(s.hinweis);
    final details = [
      if (raum.isNotEmpty) 'Raum $raum',
      if (vertreter.isNotEmpty) 'Vertr. $vertreter',
    ].join(' · ');
    final titleText = [
      if (stunde.isNotEmpty) 'Std $stunde',
      if (fach.isNotEmpty) fach,
    ].join(' · ');

    return Card(
      color: const Color(0xFF1B1D2E),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleText.isNotEmpty)
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (art.isNotEmpty)
              Text(
                art,
                style: const TextStyle(fontSize: 13, color: Colors.amber),
              ),
            if (details.isNotEmpty)
              Text(details, style: const TextStyle(fontSize: 13)),
            if (hinweis.isNotEmpty)
              Text(
                hinweis,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}
