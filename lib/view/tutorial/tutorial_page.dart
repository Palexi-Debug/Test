import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

const String tutorialDoneKey = 'tutorial-done';

/// Zeigt das Tutorial als Vollbild (blendet nur ein, keine Bewegung).
Future<void> showTutorial(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const TutorialPage(),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Beim ersten Start einmal automatisch zeigen.
void showTutorialIfFirstTime(BuildContext context) {
  try {
    final shared = ProviderScope.containerOf(
      context,
    ).read(sharedOverAccountSettingsProvider);
    if (shared.getString(tutorialDoneKey) == '1') return;
    showTutorial(context);
  } catch (_) {}
}

class _Slide {
  final IconData icon;
  final String title;
  final String text;
  const _Slide(this.icon, this.title, this.text);
}

const _slides = [
  _Slide(
    Icons.menu_book_rounded,
    'Willkommen im Schulportal',
    'Die App der Philipp-Reis-Schule. Hier siehst du Vertretungen, Stundenplan und Nachrichten schnell auf einen Blick.',
  ),
  _Slide(
    Icons.home_rounded,
    'Deine Startseite',
    'Die Kacheln bringen dich überall hin. Mit dem Stift oben rechts verschiebst du Kacheln, änderst Namen, Farben und Stil. Unter „Vertretungen" siehst du live, was als Nächstes ansteht.',
  ),
  _Slide(
    Icons.schedule_rounded,
    'Stundenplan',
    'Tippe oben auf den Wochentag oder wische zur Seite. Die laufende Stunde ist markiert. Ein Tipp auf eine Stunde zeigt Details und Farbe.',
  ),
  _Slide(
    Icons.person_search_rounded,
    'Lehrerkürzel',
    'Im Vertretungsplan zeigt ein Tipp auf ein unterstrichenes Kürzel den vollen Namen des Lehrers.',
  ),
  _Slide(
    Icons.apps_rounded,
    'Mehr',
    'Unten rechts findest du Kalender, Unterricht, Dateien, Einstellungen, den Account-Wechsel und dieses Tutorial.',
  ),
];

class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({super.key});

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final _controller = PageController();
  int _page = 0;

  void _finish() {
    try {
      ref
          .read(sharedOverAccountSettingsProvider)
          .setString(tutorialDoneKey, '1');
    } catch (_) {}
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Überspringen'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            s.icon,
                            size: 64,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                  child: Text(last ? 'Los geht\'s' : 'Weiter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
