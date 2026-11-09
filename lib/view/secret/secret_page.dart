import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Umschließt ein Widget (z. B. die Build-Nummer). Wer 7-mal schnell darauf
/// tippt, öffnet das Geheimlabor.
class SecretBuildTap extends StatefulWidget {
  final Widget child;

  const SecretBuildTap({super.key, required this.child});

  @override
  State<SecretBuildTap> createState() => _SecretBuildTapState();
}

class _SecretBuildTapState extends State<SecretBuildTap> {
  static const int _needed = 7;
  int _taps = 0;
  DateTime? _last;

  void _onTap() {
    final now = DateTime.now();
    if (_last == null ||
        now.difference(_last!) > const Duration(milliseconds: 1500)) {
      _taps = 0;
    }
    _last = now;
    _taps++;

    if (_taps >= _needed) {
      _taps = 0;
      HapticFeedback.heavyImpact();
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const SecretPage()));
      return;
    }

    HapticFeedback.selectionClick();
    if (_taps >= 4) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text('Noch ${_needed - _taps} Mal …'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}

/// Das Geheimlabor: Ausreden-Generator und Schul-Orakel.
class SecretPage extends StatefulWidget {
  const SecretPage({super.key});

  @override
  State<SecretPage> createState() => _SecretPageState();
}

class _SecretPageState extends State<SecretPage> {
  static const List<String> _excuses = [
    'Mein Wecker hat gestreikt – er wollte auch mal Ferien.',
    'Der Bus ist mir vor der Nase davongefahren, ich habe ihn noch gegrüßt.',
    'Meine Hausaufgaben liegen noch im Auto von jemandem, der gerade im Urlaub ist.',
    'Das WLAN war so langsam, dass die Aufgabe erst gestern angekommen ist.',
    'Ich habe nur die Hälfte gemacht, die andere Hälfte war noch nicht erfunden.',
    'Mein Stift ist mitten im Satz in den Ruhestand gegangen.',
    'Ich war pünktlich – nur meine Uhr nicht.',
    'Die Aufgabe war so gut, dass ich sie aufgehoben habe.',
    'Ich dachte, heute wäre schon Wochenende. Mein Kalender sieht das genauso.',
    'Mein Rucksack hat sich geweigert, das Heft herauszugeben.',
  ];

  static const List<String> _oracle = [
    'Die Sterne sagen: Vertretung. 🔮',
    'Heute fällt nichts aus – leider. 😅',
    'Die erste Stunde? Sehr wahrscheinlich Raumwechsel.',
    'Ein Lehrer ist krank, aber nicht deiner. Noch nicht.',
    'Frag nach der großen Pause nochmal.',
    'Es sieht gut aus: Freistunde in Sicht! ✨',
    'Der Vertretungsplan schweigt – ein schlechtes Zeichen.',
    'Alle Zeichen stehen auf Klassenarbeit. 📚',
  ];

  final Random _random = Random();
  int _excuseIndex = -1;
  int _oracleIndex = -1;
  int _turns = 0;

  int _pick(int length, int avoid) {
    if (length <= 1) return 0;
    int next;
    do {
      next = _random.nextInt(length);
    } while (next == avoid);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Geheimlabor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_turns),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: 0.6 + 0.4 * value, child: child),
              child: Icon(Icons.science_rounded, size: 96, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Du hast das Geheimnis gefunden!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ausreden-Generator',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _excuseIndex < 0
                        ? 'Du brauchst eine Ausrede? Tippe auf den Knopf.'
                        : _excuses[_excuseIndex],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _excuseIndex = _pick(_excuses.length, _excuseIndex);
                      _turns++;
                    }),
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Neue Ausrede'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schul-Orakel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _oracleIndex < 0
                        ? 'Frage: Fällt morgen etwas aus?'
                        : _oracle[_oracleIndex],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() {
                      _oracleIndex = _pick(_oracle.length, _oracleIndex);
                      _turns++;
                    }),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Orakel befragen'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Alle Angaben ohne Gewähr. 😉',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
