import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
      ).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const SecretLogoPage(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }

    // Wie bei Android: kein Hinweis, nur ein kurzes Fühlen
    HapticFeedback.selectionClick();
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
class SecretLabPage extends StatefulWidget {
  const SecretLabPage({super.key});

  @override
  State<SecretLabPage> createState() => _SecretLabPageState();
}

class _SecretLabPageState extends State<SecretLabPage> {
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


const String _secretBuildId = String.fromEnvironment(
  'BUILD_ID',
  defaultValue: 'dev',
);

/// Stufe 2 (wie bei Android): Vollbild-Logo mit Build-Nummer.
/// Tippen wechselt die Farbe, langes Drücken startet das Spiel.
class SecretLogoPage extends StatefulWidget {
  const SecretLogoPage({super.key});

  @override
  State<SecretLogoPage> createState() => _SecretLogoPageState();
}

class _SecretLogoPageState extends State<SecretLogoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  double _hue = 232;
  int _taps = 0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    setState(() {
      _hue = (_hue + 47) % 360;
      _taps++;
    });
  }

  void _onLongPress() {
    HapticFeedback.heavyImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SecretGamePage()));
  }

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromAHSL(1, _hue, 0.55, 0.30).toColor();
    final light = HSLColor.fromAHSL(1, (_hue + 30) % 360, 0.6, 0.45).toColor();
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        onLongPress: _onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, base],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) =>
                      CustomPaint(painter: _RingsPainter(_pulse.value)),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: _taps * 0.125,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 84,
                          color: base,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Schulportal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build $_secretBuildId',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double t;

  const _RingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: (1 - p) * 0.35);
      canvas.drawCircle(center, 90 + p * size.shortestSide * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => oldDelegate.t != t;
}

class _Obstacle {
  double x;
  final double gapTop;
  bool passed = false;

  _Obstacle(this.x, this.gapTop);
}

/// Stufe 3: "Schulportal Land" – ein kleines Spiel wie Lollipop Land.
/// Tippen lässt das Buch fliegen, zwischen den Bleistiften hindurch.
class SecretGamePage extends StatefulWidget {
  const SecretGamePage({super.key});

  @override
  State<SecretGamePage> createState() => _SecretGamePageState();
}

class _SecretGamePageState extends State<SecretGamePage>
    with SingleTickerProviderStateMixin {
  static int _best = 0;

  static const double _radius = 18;
  static const double _gravity = 1500;
  static const double _flapVelocity = -520;
  static const double _speed = 190;
  static const double _obstacleWidth = 64;
  static const double _groundHeight = 24;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  final Random _random = Random();

  double _y = 0;
  double _vy = 0;
  final List<_Obstacle> _obstacles = [];
  int _score = 0;
  bool _started = false;
  bool _dead = false;

  double get _gap => max(170.0, _size.height * 0.26);
  double get _playerX => _size.width * 0.28;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset() {
    _y = _size.height / 2;
    _vy = 0;
    _obstacles.clear();
    _score = 0;
    _started = false;
    _dead = false;
  }

  void _flap() {
    if (_size == Size.zero || _dead) return;
    _started = true;
    _vy = _flapVelocity;
    HapticFeedback.selectionClick();
  }

  void _die() {
    if (_dead) return;
    _dead = true;
    if (_score > _best) _best = _score;
    HapticFeedback.heavyImpact();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1000000.0)
        .clamp(0.0, 0.05)
        .toDouble();
    _last = elapsed;
    if (_size == Size.zero) return;
    if (_started && !_dead) _step(dt);
    setState(() {});
  }

  void _step(double dt) {
    _vy += _gravity * dt;
    _y += _vy * dt;
    for (final o in _obstacles) {
      o.x -= _speed * dt;
    }
    _obstacles.removeWhere((o) => o.x + _obstacleWidth < -10);

    if (_obstacles.isEmpty || _obstacles.last.x < _size.width - 260) {
      const margin = 70.0;
      final gap = _gap;
      final maxTop = _size.height - _groundHeight - margin - gap;
      final top = margin + _random.nextDouble() * max(1.0, maxTop - margin);
      _obstacles.add(_Obstacle(_size.width + 10, top));
    }

    for (final o in _obstacles) {
      if (!o.passed && o.x + _obstacleWidth < _playerX - _radius) {
        o.passed = true;
        _score++;
        HapticFeedback.lightImpact();
      }
      final overlapX =
          _playerX + _radius > o.x && _playerX - _radius < o.x + _obstacleWidth;
      if (overlapX &&
          (_y - _radius < o.gapTop || _y + _radius > o.gapTop + _gap)) {
        _die();
      }
    }
    if (_y + _radius > _size.height - _groundHeight || _y - _radius < 0) {
      _die();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14183A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final newSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_size != newSize) {
            _size = newSize;
            _reset();
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _flap(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GamePainter(
                      y: _y,
                      vy: _vy,
                      playerX: _playerX,
                      radius: _radius,
                      obstacleWidth: _obstacleWidth,
                      gap: _gap,
                      groundHeight: _groundHeight,
                      obstacles: [
                        for (final o in _obstacles) Offset(o.x, o.gapTop),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        '$_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_started && !_dead)
                  const IgnorePointer(
                    child: Center(
                      child: Text(
                        'Tippen zum Fliegen',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                    ),
                  ),
                if (_dead) Center(child: _gameOverCard(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _gameOverCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Aus die Maus!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Punkte: $_score · Rekord: $_best'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(_reset),
              child: const Text('Nochmal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const SecretLabPage())),
              child: const Text('Geheimlabor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final double y;
  final double vy;
  final double playerX;
  final double radius;
  final double obstacleWidth;
  final double gap;
  final double groundHeight;
  final List<Offset> obstacles;

  const _GamePainter({
    required this.y,
    required this.vy,
    required this.playerX,
    required this.radius,
    required this.obstacleWidth,
    required this.gap,
    required this.groundHeight,
    required this.obstacles,
  });

  void _pencil(
    Canvas canvas,
    double x,
    double top,
    double height, {
    required bool tipDown,
  }) {
    const tipHeight = 34.0;
    if (height <= tipHeight) return;
    final body = Paint()..color = const Color(0xFFFFC107);
    final stripe = Paint()..color = const Color(0xFFFFA000);
    final wood = Paint()..color = const Color(0xFFF2D1A0);
    final lead = Paint()..color = const Color(0xFF37474F);
    final w = obstacleWidth;
    if (tipDown) {
      canvas.drawRect(Rect.fromLTWH(x, top, w, height - tipHeight), body);
      canvas.drawRect(
        Rect.fromLTWH(x + w * 0.5, top, w * 0.2, height - tipHeight),
        stripe,
      );
      final bottom = top + height;
      canvas.drawPath(
        Path()
          ..moveTo(x, bottom - tipHeight)
          ..lineTo(x + w, bottom - tipHeight)
          ..lineTo(x + w / 2, bottom)
          ..close(),
        wood,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x + w / 2 - 7, bottom - 12)
          ..lineTo(x + w / 2 + 7, bottom - 12)
          ..lineTo(x + w / 2, bottom)
          ..close(),
        lead,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(x, top + tipHeight, w, height - tipHeight),
        body,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + w * 0.5, top + tipHeight, w * 0.2, height - tipHeight),
        stripe,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, top + tipHeight)
          ..lineTo(x + w, top + tipHeight)
          ..lineTo(x + w / 2, top)
          ..close(),
        wood,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x + w / 2 - 7, top + 12)
          ..lineTo(x + w / 2 + 7, top + 12)
          ..lineTo(x + w / 2, top)
          ..close(),
        lead,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14183A), Color(0xFF3F51B5)],
        ).createShader(rect),
    );

    final star = Paint()..color = Colors.white24;
    for (var i = 0; i < 40; i++) {
      final sx = ((i * 97) % 100) / 100 * size.width;
      final sy = ((i * 53) % 100) / 100 * size.height * 0.7;
      canvas.drawCircle(Offset(sx, sy), i % 3 == 0 ? 1.8 : 1.0, star);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - groundHeight, size.width, groundHeight),
      Paint()..color = const Color(0xFF1B5E20),
    );

    for (final o in obstacles) {
      _pencil(canvas, o.dx, 0, o.dy, tipDown: true);
      final bottomTop = o.dy + gap;
      _pencil(
        canvas,
        o.dx,
        bottomTop,
        size.height - groundHeight - bottomTop,
        tipDown: false,
      );
    }

    canvas.save();
    canvas.translate(playerX, y);
    canvas.rotate((vy / 900).clamp(-0.5, 0.7).toDouble());
    final book = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.1,
        height: radius * 1.7,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(book, Paint()..color = Colors.white);
    canvas.drawLine(
      Offset(0, -radius * 0.85),
      Offset(0, radius * 0.85),
      Paint()
        ..color = const Color(0xFF3F51B5)
        ..strokeWidth = 3,
    );
    final line = Paint()
      ..color = const Color(0xFF9FA8DA)
      ..strokeWidth = 2;
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(-radius * 0.85, i * 6.0),
        Offset(-radius * 0.2, i * 6.0),
        line,
      );
      canvas.drawLine(
        Offset(radius * 0.2, i * 6.0),
        Offset(radius * 0.85, i * 6.0),
        line,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GamePainter oldDelegate) => true;
}
