import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Blendet ein Widget beim ersten Erscheinen weich ein und schiebt es leicht
/// nach oben. [index] staffelt mehrere Einträge zeitlich.
class Entrance extends StatefulWidget {
  final int index;
  final Widget child;

  const Entrance({super.key, this.index = 0, required this.child});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 45 * math.min(widget.index, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - _a.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
