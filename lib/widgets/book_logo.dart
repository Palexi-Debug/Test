import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lanis/utils/look.dart';

/// Das Schulportal-Logo (Buch mit Lesezeichen und Sonne).
/// [progress] 0 = geschlossenes Buch, 1 = aufgeschlagen mit Sonne.
class BookLogo extends StatelessWidget {
  final double size;
  final double progress;
  final bool withBackground;

  const BookLogo({
    super.key,
    this.size = 96,
    this.progress = 1,
    this.withBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BookPainter(progress, withBackground)),
    );
  }
}

/// Das Buch öffnet sich beim Erscheinen.
class AnimatedBookLogo extends StatefulWidget {
  final double size;
  final Duration delay;

  const AnimatedBookLogo({
    super.key,
    this.size = 120,
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedBookLogo> createState() => _AnimatedBookLogoState();
}

class _AnimatedBookLogoState extends State<AnimatedBookLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void initState() {
    super.initState();
    if (AppLook.anim == 0) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => BookLogo(size: widget.size, progress: _c.value),
    );
  }
}

class _BookPainter extends CustomPainter {
  final double t;
  final bool background;

  _BookPainter(this.t, this.background);

  static const _spine = 512.0;

  Path _leftPage() => Path()
    ..moveTo(222, 385)
    ..quadraticBezierTo(365, 356, 500, 412)
    ..lineTo(500, 750)
    ..quadraticBezierTo(365, 700, 222, 730)
    ..close();

  Path _rightPage() => Path()
    ..moveTo(802, 385)
    ..quadraticBezierTo(659, 356, 524, 412)
    ..lineTo(524, 750)
    ..quadraticBezierTo(659, 700, 802, 730)
    ..close();

  Path _cover(double dx, double dy) => Path()
    ..moveTo(196 + dx, 408 + dy)
    ..quadraticBezierTo(355, 378 + dy, 512, 432 + dy)
    ..quadraticBezierTo(669, 378 + dy, 828 - dx, 408 + dy)
    ..lineTo(828 - dx, 758 + dy)
    ..quadraticBezierTo(669, 726 + dy, 512, 782 + dy)
    ..quadraticBezierTo(355, 726 + dy, 196 + dx, 758 + dy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final p = t.clamp(0.0, 1.0);
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);

    if (background) {
      canvas.drawCircle(
        const Offset(512, 512),
        512,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(512, 0),
            const Offset(512, 1024),
            const [Color(0xFF4A5CD0), Color(0xFF1F2A7A)],
          ),
      );
    }

    final open = Curves.easeInOutCubic.transform(
      ((p - 0.12) / 0.6).clamp(0.0, 1.0),
    );
    final sunT = Curves.easeOut.transform(((p - 0.62) / 0.38).clamp(0.0, 1.0));

    // Schatten
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(512, 802),
        width: 660 * (0.45 + 0.55 * open),
        height: 70,
      ),
      Paint()
        ..color = const Color(0x47000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // Buch (horizontal um den Buchrücken gestaucht, solange es geschlossen ist)
    canvas.save();
    canvas.translate(_spine, 0);
    canvas.scale(0.46 + 0.54 * open, 1);
    canvas.translate(-_spine, 0);

    final coverShader = ui.Gradient.linear(
      const Offset(0, 380),
      const Offset(0, 780),
      const [Color(0xFF1B2470), Color(0xFF0E1445)],
    );
    canvas.drawPath(_cover(0, 0), Paint()..shader = coverShader);
    canvas.drawPath(
      _cover(14, -12),
      Paint()..color = const Color(0x8CFFFFFF),
    );
    canvas.drawPath(
      _cover(18, -16),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    canvas.drawPath(
      _leftPage(),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(222, 0),
          const Offset(500, 0),
          const [Color(0xFFFFFFFF), Color(0xFFEEF0FB), Color(0xFFB9BFE6)],
          const [0, 0.72, 1],
        ),
    );
    canvas.drawPath(
      _rightPage(),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(802, 0),
          const Offset(524, 0),
          const [Color(0xFFFFFFFF), Color(0xFFEEF0FB), Color(0xFFB9BFE6)],
          const [0, 0.72, 1],
        ),
    );
    canvas.drawRect(
      const Rect.fromLTRB(500, 412, 524, 750),
      Paint()..color = const Color(0xD9283593),
    );

    // Textzeilen und Lesezeichen erscheinen mit dem Aufschlagen
    final detail = ((open - 0.5) * 2).clamp(0.0, 1.0);
    if (detail > 0) {
      final line = Paint()
        ..color = Color.fromRGBO(63, 81, 181, 0.30 * detail)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final o in [0.0, 54.0, 108.0, 162.0]) {
        final w = o < 162 ? 0.0 : 40.0;
        canvas.drawPath(
          Path()
            ..moveTo(262, 452 + o)
            ..quadraticBezierTo(365, 420 + o, 468 - w, 472 + o),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(762, 452 + o)
            ..quadraticBezierTo(659, 420 + o, 556 + w, 472 + o),
          line,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(640, 372)
          ..lineTo(640, 590)
          ..lineTo(665, 566)
          ..lineTo(690, 590)
          ..lineTo(690, 366)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 366),
            const Offset(0, 590),
            [
              Color.fromRGBO(255, 213, 79, detail),
              Color.fromRGBO(255, 160, 0, detail),
            ],
          ),
      );
    }
    canvas.restore();

    // Geschlossenes Buch: Einband blendet beim Öffnen aus
    final coverAlpha = (1 - open * 1.8).clamp(0.0, 1.0);
    if (coverAlpha > 0) {
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTRB(340, 392, 684, 772),
        const Radius.circular(26),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(340, 392),
            const Offset(684, 772),
            [
              Color.fromRGBO(63, 81, 181, coverAlpha),
              Color.fromRGBO(27, 36, 112, coverAlpha),
            ],
          ),
      );
      canvas.drawRRect(
        rect.deflate(22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Color.fromRGBO(255, 213, 79, 0.8 * coverAlpha),
      );
      canvas.drawCircle(
        const Offset(512, 582),
        46,
        Paint()..color = Color.fromRGBO(255, 193, 7, coverAlpha),
      );
    }

    // Sonne steigt auf und leuchtet
    if (sunT > 0) {
      final c = Offset(512, 262 + 90 * (1 - sunT));
      canvas.drawCircle(
        c,
        150 * sunT,
        Paint()
          ..shader = ui.Gradient.radial(c, 150 * sunT, [
            Color.fromRGBO(255, 224, 130, 0.95 * sunT),
            Color.fromRGBO(255, 193, 7, 0.35 * sunT),
            const Color(0x00FFC107),
          ], const [
            0,
            0.45,
            1,
          ]),
      );
      canvas.drawCircle(
        c,
        62 * sunT,
        Paint()
          ..shader = ui.Gradient.radial(
            c.translate(-14, -14),
            62 * sunT * 1.4,
            const [Color(0xFFFFF3C4), Color(0xFFFFC107), Color(0xFFFF9800)],
            const [0, 0.5, 1],
          ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BookPainter old) =>
      old.t != t || old.background != background;
}
