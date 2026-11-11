import 'dart:async';

import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/student_timetable_item.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:lanis/widgets/entrance.dart';

int _min(SphTimeOfDay t) => t.hour * 60 + t.minute;

/// Handy-Ansicht des Stundenplans: ein Tag als Liste großer Karten, oben die
/// Wochentage zum Wechseln (auch per Wischen). Die aktuelle Stunde ist markiert.
class TimetableDayView extends StatefulWidget {
  final TimeTableData data;
  final DateTime weekStart;
  final Map<String, dynamic> settings;
  final Function updateSettings;
  final Future<void> Function()? refresh;

  const TimetableDayView({
    super.key,
    required this.data,
    required this.weekStart,
    required this.settings,
    required this.updateSettings,
    this.refresh,
  });

  @override
  State<TimetableDayView> createState() => _TimetableDayViewState();
}

class _TimetableDayViewState extends State<TimetableDayView> {
  int _day = -1;
  Timer? _timer;

  DateTime _dateOf(int i) => DateTime(
    widget.weekStart.year,
    widget.weekStart.month,
    widget.weekStart.day + i,
  );

  bool _isToday(int i) {
    final d = _dateOf(i);
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go(int delta, int count) {
    final next = _day + delta;
    if (next < 0 || next >= count) return;
    setState(() => _day = next);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.data.timetableDays;
    final scheme = Theme.of(context).colorScheme;
    if (days.isEmpty) {
      return const Center(child: Text('Keine Einträge'));
    }
    if (_day < 0 || _day >= days.length) {
      final today = List.generate(days.length, (i) => i).where(_isToday);
      _day = today.isNotEmpty ? today.first : 0;
    }
    final day = days[_day];
    final text = Theme.of(context).textTheme;

    // Schulzeit des Tages
    int? first;
    int? last;
    for (final s in day) {
      final a = _min(s.startTime);
      final b = _min(s.endTime);
      if (first == null || a < first) first = a;
      if (last == null || b > last) last = b;
    }
    String hm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final showNow = _isToday(_day);

    final items = <Widget>[];
    if (first != null && last != null) {
      for (final row in widget.data.hours) {
        final rs = _min(row.startTime);
        final re = _min(row.endTime);
        if (rs < first || re > last) continue;
        final starting = day.where((s) => _min(s.startTime) == rs).toList();
        final covering = day.any(
          (s) => _min(s.startTime) < rs && _min(s.endTime) >= re,
        );
        if (row.type == TimeTableRowType.pause) {
          if (!covering) items.add(_pause(context, rs, re, hm));
          continue;
        }
        if (starting.isEmpty) {
          if (!covering) items.add(_free(context, row));
          continue;
        }
        for (final s in starting) {
          items.add(
            Entrance(
              key: ValueKey('d$_day-${items.length}'),
              index: items.length,
              child: _card(context, row, s, showNow, nowMin),
            ),
          );
        }
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300) _go(1, days.length);
        if (v > 300) _go(-1, days.length);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _chip(context, i),
                    ),
                  ),
              ],
            ),
          ),
          if (first != null && last != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Unterricht ${hm(first)} – ${hm(last)} Uhr'
                '${widget.data.weekBadge != null && widget.data.weekBadge!.isNotEmpty ? ' · Woche ${widget.data.weekBadge}' : ''}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.refresh ?? () async {},
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.celebration_rounded,
                          size: 56,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Kein Unterricht',
                            style: text.titleMedium,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 96),
                      children: items,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final selected = i == _day;
    final date = _dateOf(i);
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _day = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: _isToday(i) && !selected
              ? Border.all(color: scheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              DateFormat.E(
                Localizations.localeOf(context).languageCode,
              ).format(date),
              style: TextStyle(fontWeight: FontWeight.bold, color: fg),
            ),
            Text(
              date.format('dd.MM.'),
              style: TextStyle(fontSize: 11, color: fg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pause(
    BuildContext context,
    int rs,
    int re,
    String Function(int) hm,
  ) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Pause ${hm(rs)}–${hm(re)}',
              style: TextStyle(fontSize: 11, color: c),
            ),
          ),
          Expanded(child: Divider(color: c.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _free(BuildContext context, TimeTableRow row) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.coffee_rounded, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(
              '${row.label} · Freistunde',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    TimeTableRow row,
    TimetableSubject s,
    bool showNow,
    int nowMin,
  ) {
    final raw = TimeTableHelper.getColorForLesson(widget.settings, s);
    final bg = ItemBlock.soften(context, raw);
    final fg = bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final a = _min(s.startTime);
    final b = _min(s.endTime);
    final current = showNow && nowMin >= a && nowMin < b;
    final progress = current ? (nowMin - a) / (b - a) : 0.0;
    final sub = fg.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: current
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ItemBlock(
            subject: s,
            height: 0,
            offset: 0,
            width: 0,
            color: raw,
            settings: widget.settings,
            updateSettings: widget.updateSettings,
          ).showSubject(context),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.startTime.toFlutter().format(context),
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            s.endTime.toFlutter().format(context),
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name ?? '',
                            style: TextStyle(
                              color: fg,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (s.lehrer != null && s.lehrer!.isNotEmpty)
                                s.lehrer!,
                              if (s.raum != null && s.raum!.isNotEmpty)
                                'Raum ${s.raum!}',
                              if (s.duration > 1) 'Doppelstunde',
                            ].join(' · '),
                            style: TextStyle(color: sub),
                          ),
                        ],
                      ),
                    ),
                    if (current)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Jetzt',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (current)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.transparent,
                  color: fg.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
