import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lanis/applets/timetable/student/cancelled.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Stundenplan als Bild: der ganze Stundenplan (mit eingesetzten Vertretungen und
/// ausgegrauten Ausfällen) auf einen Blick. Über das Teilen-Symbol wird er als
/// Bild (PNG) weitergegeben.
class WeekPreviewPage extends StatefulWidget {
  final List<TimetableDay> plan;
  final List<TimeTableRow> hours;
  final DateTime weekStart;
  final String? weekBadge;
  final Map<String, dynamic> settings;

  const WeekPreviewPage({
    super.key,
    required this.plan,
    required this.hours,
    required this.weekStart,
    required this.settings,
    this.weekBadge,
  });

  @override
  State<WeekPreviewPage> createState() => _WeekPreviewPageState();
}

class _WeekPreviewPageState extends State<WeekPreviewPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  static const _dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  /// Mo–Fr immer, Sa/So nur wenn dort Stunden stehen.
  int get _dayCount {
    var n = 5;
    for (var d = 5; d < widget.plan.length && d < 7; d++) {
      if (widget.plan[d].isNotEmpty) n = d + 1;
    }
    return n;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/stundenplan.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'Mein Stundenplan');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Das Bild konnte nicht erstellt werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const title = 'Stundenplan als Bild'
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Als Bild teilen',
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: widget.hours.where((h) => h.type == TimeTableRowType.lesson).isEmpty
          ? const Center(child: Text('Noch keine Stundenplan-Daten.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: scheme.surface,
                  padding: const EdgeInsets.all(8),
                  child: _Grid(
                    plan: widget.plan,
                    hours: widget.hours,
                    weekStart: widget.weekStart,
                    dayCount: _dayCount,
                    dayNames: _dayNames,
                    settings: widget.settings,
                    weekBadge: widget.weekBadge,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<TimetableDay> plan;
  final List<TimeTableRow> hours;
  final DateTime weekStart;
  final int dayCount;
  final List<String> dayNames;
  final Map<String, dynamic> settings;
  final String? weekBadge;

  const _Grid({
    required this.plan,
    required this.hours,
    required this.weekStart,
    required this.dayCount,
    required this.dayNames,
    required this.settings,
    required this.weekBadge,
  });

  /// Gleiche Farbgebung wie im Stundenplan (gedämpfte Fachfarbe).
  Color _lessonColor(BuildContext context, TimetableSubject l) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final seed = TimeTableHelper.getColorForLesson(settings, l);
    final hsl = HSLColor.fromColor(seed);
    return hsl
        .withSaturation(math.min(hsl.saturation, 0.5))
        .withLightness(
          dark ? 0.30 + hsl.lightness * 0.14 : 0.74 + hsl.lightness * 0.12,
        )
        .toColor();
  }

  static const double _headerH = 44;
  static const double _rowH = 58;
  static const double _timeW = 40;

  String _hm(SphTimeOfDay t) =>
      '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = hours.where((h) => h.type == TimeTableRowType.lesson).toList();
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, c) {
        final colW = (c.maxWidth - _timeW) / dayCount;
        final children = <Widget>[];

        // Kopfzeile mit den Wochentagen
        for (var d = 0; d < dayCount; d++) {
          final date = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + d,
          );
          final today =
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          children.add(
            Positioned(
              left: _timeW + d * colW,
              top: 0,
              width: colW,
              height: _headerH,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[d],
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: today ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${date.day}.${date.month}.',
                    style: text.labelSmall?.copyWith(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Ecke oben links: G-/U-Woche
        if ((weekBadge ?? '').isNotEmpty) {
          children.add(
            Positioned(
              left: 0,
              top: 0,
              width: _timeW,
              height: _headerH,
              child: Center(
                child: Text(
                  '$weekBadge-Wo.',
                  style: text.labelSmall?.copyWith(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }

        // Stundenzeiten links
        for (var r = 0; r < rows.length; r++) {
          children.add(
            Positioned(
              left: 0,
              top: _headerH + r * _rowH,
              width: _timeW,
              height: _rowH,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      rows[r].label,
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _hm(rows[r].startTime),
                    style: text.labelSmall?.copyWith(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Stunden
        for (var d = 0; d < dayCount && d < plan.length; d++) {
          final date = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + d,
          );
          for (final l in plan[d]) {
            final r = rows.indexWhere((h) => h.startTime == l.startTime);
            if (r < 0) continue;
            final span = l.duration < 1 ? 1 : l.duration;
            final cancelled = isLessonCancelled(context, l, date, hours);
            final changed = l.substituted && !cancelled;
            final bg = cancelled
                ? scheme.surfaceContainerHighest
                : _lessonColor(context, l);
            final fg = cancelled
                ? scheme.onSurfaceVariant
                : (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
                      ? Colors.white
                      : Colors.black87);
            children.add(
              Positioned(
                left: _timeW + d * colW + 2,
                top: _headerH + r * _rowH + 2,
                width: colW - 4,
                height: span * _rowH - 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: changed
                        ? Border.all(color: scheme.tertiary, width: 2)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        (l.name ?? '').trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                          fontSize: 11,
                          decoration: cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if ((l.raum ?? '').trim().isNotEmpty)
                        Text(
                          l.raum!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            fontSize: 10,
                            color: fg.withValues(alpha: 0.85),
                          ),
                        ),
                      if ((l.lehrer ?? '').trim().isNotEmpty)
                        Text(
                          l.lehrer!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            fontSize: 10,
                            color: fg.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        return SizedBox(
          width: c.maxWidth,
          height: _headerH + rows.length * _rowH,
          child: Stack(children: children),
        );
      },
    );
  }
}
