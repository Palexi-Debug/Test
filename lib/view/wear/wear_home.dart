import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/utils/updater.dart';
import 'package:lanis/utils/version_label.dart';
import 'package:lanis/view/wear/wear_substitutions_page.dart';
import 'package:lanis/widgets/book_logo.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

/// Wear-OS-Startseite: senkrecht wischbare Seiten für das Wichtigste.
/// Jetzt (aktuelle/nächste Stunde) · Heute (Stundenplan) · Vertretungen · Update
class WearHome extends ConsumerStatefulWidget {
  const WearHome({super.key});

  @override
  ConsumerState<WearHome> createState() => _WearHomeState();
}

class _WearHomeState extends ConsumerState<WearHome> {
  final PageController _pages = PageController();
  int _page = 0;
  UpdateInfo? _update;

  static const _count = 4;

  @override
  void initState() {
    super.initState();
    checkForUpdate(wear: true).then((r) {
      if (mounted && r.result == UpdateCheckResult.newer) {
        setState(() => _update = r.info);
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: scheme,
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView(
              scrollDirection: Axis.vertical,
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _WearTimetablePage(now: true, updateHint: _update != null),
                const _WearTimetablePage(now: false),
                const WearSubstitutionsPage(),
                _WearUpdatePage(initial: _update),
              ],
            ),
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _count; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        width: 6,
                        height: i == _page ? 16 : 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _min(SphTimeOfDay t) => t.hour * 60 + t.minute;

String _hm(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

class _WearTimetablePage extends ConsumerStatefulWidget {
  final bool now;
  final bool updateHint;
  const _WearTimetablePage({required this.now, this.updateHint = false});

  @override
  ConsumerState<_WearTimetablePage> createState() => _WearTimetablePageState();
}

class _WearTimetablePageState extends ConsumerState<_WearTimetablePage> {
  Timer? _timer;

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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final parser = ref.watch(timetableParserProvider);
    return CombinedAppletBuilder<TimeTable>(
      parser: parser,
      phpUrl: timeTableDefinition.appletPhpUrl,
      settingsDefaults: timeTableDefinition.settingsDefaults,
      accountType:
          session.accountTypeOrNull ??
          ref.read(activeAccountProvider)?.accountType ??
          AccountType.student,
      builder: (context, timetable, accountType, settings, update, refresh) {
        final base = timetable.planForOwn ?? timetable.planForAll ?? const [];
        final plan = TimeTableHelper.mergeByIndices(
          base,
          TimeTableHelper.getCustomLessons(settings),
        );
        return widget.now
            ? _buildNow(context, plan)
            : _buildToday(context, plan);
      },
    );
  }

  /// Lehrplan des heutigen Tages, nach Startzeit sortiert.
  List<TimetableSubject> _lessonsOf(List<List<TimetableSubject>> plan, int i) {
    if (i < 0 || i >= plan.length) return const [];
    final l = [...plan[i]]
      ..sort((a, b) => _min(a.startTime).compareTo(_min(b.startTime)));
    return l;
  }

  Widget _buildNow(BuildContext context, List<List<TimetableSubject>> plan) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final today = _lessonsOf(plan, now.weekday - 1);

    TimetableSubject? current;
    TimetableSubject? next;
    for (final l in today) {
      if (_min(l.startTime) <= nowMin && nowMin < _min(l.endTime)) current = l;
      if (_min(l.startTime) > nowMin && next == null) next = l;
    }

    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (current != null) {
      final left = _min(current.endTime) - nowMin;
      children.addAll([
        const Text('JETZT', style: TextStyle(fontSize: 12, color: Colors.white54)),
        Text(
          current.name ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text(
          [
            if ((current.raum ?? '').isNotEmpty) 'Raum ${current.raum}',
            if ((current.lehrer ?? '').isNotEmpty) current.lehrer!,
          ].join(' · '),
          style: TextStyle(fontSize: 15, color: scheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          'noch $left min',
          style: const TextStyle(fontSize: 14, color: Colors.amber),
        ),
      ]);
    } else if (next != null) {
      final inMin = _min(next.startTime) - nowMin;
      children.addAll([
        const Text('NÄCHSTE', style: TextStyle(fontSize: 12, color: Colors.white54)),
        Text(
          next.name ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text(
          [
            _hm(_min(next.startTime)),
            if ((next.raum ?? '').isNotEmpty) 'Raum ${next.raum}',
          ].join(' · '),
          style: TextStyle(fontSize: 15, color: scheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          'in $inMin min',
          style: const TextStyle(fontSize: 14, color: Colors.amber),
        ),
      ]);
    } else {
      children.addAll([
        const AnimatedBookLogo(size: 64),
        const SizedBox(height: 8),
        Text(
          today.isEmpty ? 'Heute frei' : 'Schule aus',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ]);
    }

    if (widget.updateHint) {
      children.addAll([
        const SizedBox(height: 10),
        const Text(
          '↓ Update verfügbar',
          style: TextStyle(fontSize: 12, color: Colors.amber),
        ),
      ]);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildToday(BuildContext context, List<List<TimetableSubject>> plan) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    var day = now.weekday - 1;
    var lessons = _lessonsOf(plan, day);
    // Nach Schulschluss oder am Wochenende den nächsten Schultag zeigen.
    if (lessons.isEmpty || nowMin >= _min(lessons.last.endTime)) {
      for (var k = 1; k <= 7; k++) {
        final d = (now.weekday - 1 + k) % 7;
        final l = _lessonsOf(plan, d);
        if (l.isNotEmpty) {
          day = d;
          lessons = l;
          break;
        }
      }
    }
    final isToday = day == now.weekday - 1;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 34, 40),
      children: [
        Center(
          child: Text(
            isToday ? 'Heute' : _weekdays[day],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (lessons.isEmpty)
          const Center(child: Text('Keine Stunden', style: TextStyle(fontSize: 16))),
        for (final l in lessons)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isToday &&
                      _min(l.startTime) <= nowMin &&
                      nowMin < _min(l.endTime)
                  ? scheme.primaryContainer
                  : const Color(0xFF1B1D2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_hm(_min(l.startTime))}'
                        '${(l.raum ?? '').isNotEmpty ? ' · ${l.raum}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WearUpdatePage extends StatefulWidget {
  final UpdateInfo? initial;
  const _WearUpdatePage({this.initial});

  @override
  State<_WearUpdatePage> createState() => _WearUpdatePageState();
}

class _WearUpdatePageState extends State<_WearUpdatePage> {
  UpdateInfo? _info;
  String _status = '';
  bool _busy = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _info = widget.initial;
  }

  @override
  void didUpdateWidget(covariant _WearUpdatePage old) {
    super.didUpdateWidget(old);
    _info ??= widget.initial;
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = 'Suche …';
    });
    final r = await checkForUpdate(wear: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r.result) {
        case UpdateCheckResult.newer:
          _info = r.info;
          _status = 'Build ${r.info!.build} verfügbar';
        case UpdateCheckResult.upToDate:
          _status = 'Aktuell';
        case UpdateCheckResult.failed:
          _status = 'Keine Verbindung';
      }
    });
  }

  Future<void> _install() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Lade …';
    });
    final err = await downloadAndInstall(info, (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
      _status = err ?? 'Installer geöffnet';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BookLogo(size: 52),
            const SizedBox(height: 6),
            Text(versionLabel(), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            if (_status.isNotEmpty)
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.amber),
              ),
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: _progress),
              ),
            const SizedBox(height: 8),
            if (_info != null)
              FilledButton(
                onPressed: _busy ? null : _install,
                child: Text('Build ${_info!.build} installieren'),
              )
            else
              FilledButton.tonal(
                onPressed: _busy ? null : _check,
                child: const Text('Nach Update suchen'),
              ),
          ],
        ),
      ),
    );
  }
}
