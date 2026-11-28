import 'package:lanis/core/school_schedule.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:lanis/utils/watch_sync.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/utils/updater.dart';
import 'package:lanis/utils/version_label.dart';
import 'package:lanis/view/secret/secret_page.dart';
import 'package:lanis/view/wear/wear_substitutions_page.dart';
import 'package:lanis/widgets/book_logo.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:lanis/widgets/week_badge.dart';
import 'package:lanis/applets/timetable/student/apply_substitutions.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';

/// Wear-OS-Startseite: senkrecht wischbare Seiten für das Wichtigste.
/// Jetzt (aktuelle/nächste Stunde) · Heute (Stundenplan) · Vertretungen · Update
class WearHome extends ConsumerStatefulWidget {
  const WearHome({super.key});

  @override
  ConsumerState<WearHome> createState() => _WearHomeState();
}

class _WearHomeState extends ConsumerState<WearHome> {
  late PageController _pages;
  int _page = 0;
  double _scroll = 1.6; // Scroll-Tempo (Einstellung)
  bool _animOn = true; // Animationen (Einstellung)
  double _animSpeed = 1.0; // Animations-Tempo (Einstellung)

  Duration _ad(int ms) => _animOn
      ? Duration(milliseconds: (ms / _animSpeed).round().clamp(1, 4000).toInt())
      : Duration.zero;
  UpdateInfo? _update;
  double _overscrollSum = 0;
  bool _startedAtEdge = false;
  bool _switching = false;
  double _font = 1.0; // Textgröße der Uhr (Einstellung)

  static const _count = 4;

  final WatchConnectivity _watch = WatchConnectivity();
  final List<StreamSubscription> _subs = [];
  int _ttRev = 0;

  void _onPhoneData(Map<String, dynamic> m) {
    final ok = applyTimetableFromPhone(
      m,
      ref.read(accountSpecificSettingsProvider),
    );
    try {
      applyCacheFromPhone(
        m,
        ref.read(lanisDatabaseProvider),
        ref.read(activeAccountProvider)?.localId,
      );
    } catch (_) {}
    if (ok && mounted) setState(() => _ttRev++);
  }

  void _loadSettings() {
    final st = ref.read(sharedOverAccountSettingsProvider);
    _font = double.tryParse(st.getString('wear-font') ?? '') ?? 1.0;
    _scroll = double.tryParse(st.getString('wear-scroll') ?? '') ?? 1.6;
    _animOn = st.getString('wear-anim') != '0';
    _animSpeed = double.tryParse(st.getString('wear-anim-speed') ?? '') ?? 1.0;
    _page = (int.tryParse(st.getString('wear-start-page') ?? '') ?? 0)
        .clamp(0, _count - 1)
        .toInt();
  }

  @override
  void initState() {
    super.initState();
    _subs.add(_watch.messageStream.listen(_onPhoneData));
    _subs.add(_watch.contextStream.listen(_onPhoneData));
    _watch.receivedApplicationContexts.then((list) {
      for (final m in list) {
        _onPhoneData(m);
      }
    }).catchError((_) {});
    _loadSettings();
    _pages = PageController(initialPage: _page);
    checkForUpdate(wear: true).then((r) {
      if (r.result == UpdateCheckResult.newer) {
        // Im Hintergrund vorladen, damit "Installieren" sofort startet.
        prefetchUpdate(r.info!);
        if (mounted) setState(() => _update = r.info);
      }
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(physics: _WearScrollPhysics(factor: _scroll)),
      child: MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_font),
      ),
      child: Theme(
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
            // Listen in den Seiten scrollen selbst; am Anfang/Ende wechselt
            // ein weiteres Wischen zur vorherigen/nächsten Seite.
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.depth == 0 || n.metrics.axis != Axis.vertical) {
                  return false;
                }
                // Erst nach längerem Wischen am Listenende die Seite wechseln
                // (entspannteres Scrollen statt sofortigem Umschalten).
                if (n is ScrollStartNotification) {
                  _overscrollSum = 0;
                  _startedAtEdge =
                      n.metrics.pixels <= n.metrics.minScrollExtent + 1 ||
                      n.metrics.pixels >= n.metrics.maxScrollExtent - 1;
                }
                if (n is ScrollEndNotification) {
                  _overscrollSum = 0;
                  _startedAtEdge = false;
                }
                // Nur wenn der Finger schon am Rand angesetzt hat (kein
                // versehentliches Weiterblättern durch Schwung).
                if (n is OverscrollNotification &&
                    !_switching &&
                    n.dragDetails != null) {
                  _overscrollSum += n.overscroll;
                  if (_overscrollSum.abs() > 50) {
                    final back = _overscrollSum < 0;
                    _overscrollSum = 0;
                    _switching = true;
                    final d = _ad(450);
                    if (back) {
                      _pages.previousPage(
                        duration: d,
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _pages.nextPage(duration: d, curve: Curves.easeInOutCubic);
                    }
                    Future.delayed(
                      Duration(milliseconds: _animOn ? 800 : 300),
                      () => _switching = false,
                    );
                  }
                }
                return false;
              },
              child: PageView(
                scrollDirection: Axis.vertical,
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _KeepAlive(
                    child: _WearTimetablePage(
                      key: ValueKey('now$_ttRev'),
                      now: true,
                      updateHint: _update != null,
                    ),
                  ),
                  _KeepAlive(
                    child: _WearTimetablePage(
                      key: ValueKey('today$_ttRev'),
                      now: false,
                    ),
                  ),
                  const _KeepAlive(child: WearSubstitutionsPage()),
                  _KeepAlive(
                    child: _WearUpdatePage(
                    initial: _update,
                    onSettings: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _WearSettingsPage(),
                        ),
                      );
                      if (mounted) {
                        setState(() {
                          final keep = _page;
                          _loadSettings();
                          _page = keep;
                          _ttRev++;
                        });
                      }
                    },
                  ),
                  ),
                ],
              ),
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
                        duration: _ad(200),
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
    )));
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
  const _WearTimetablePage({
    super.key,
    required this.now,
    this.updateHint = false,
  });

  @override
  ConsumerState<_WearTimetablePage> createState() => _WearTimetablePageState();
}

class _WearTimetablePageState extends ConsumerState<_WearTimetablePage>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription? _subSub;

  // Minutengenau reicht; im Hintergrund (Display aus) läuft kein Timer.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    // Vertretungen für die Anzeige im Stundenplan laden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final p = ref.read(substitutionsParserProvider);
        _subSub = p.stream.listen((_) {
          if (mounted) setState(() {});
        });
        p.fetchData();
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _subSub?.cancel();
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
        final wb = (timetable.weekBadge ?? '').trim();
        final hidden = (settings['hidden-lessons'] as List?) ?? const [];
        final merged = TimeTableHelper.mergeByIndices(
          base,
          TimeTableHelper.getCustomLessons(settings),
        );
        // Vertretungen einsetzen (Ersatz/Verlegung), Datum der Woche vom Portal.
        List<List<TimetableSubject>> withSubs = merged;
        try {
          final sp =
              (ref.read(substitutionsParserProvider) as dynamic)
                      .latestResponse
                      ?.content
                  as SubstitutionPlan?;
          final subsOn =
              ref
                  .read(sharedOverAccountSettingsProvider)
                  .getString('wear-subs-in-plan') !=
              '0';
          if (!subsOn) throw StateError('aus');
          withSubs = applySubstitutions(
            plan: merged,
            hours: timetable.hours ?? const <TimeTableRow>[],
            subs: sp,
            weekStart: timetableWeekStart(
              DateTime.tryParse(timetable.weekDate ?? '') ?? DateTime.now(),
            ),
          );
        } catch (_) {}
        final plan = withSubs.map((day) => day.where((l) => !hidden.contains(l.id) && _inWeek(l, wb)).toList()).toList();
        return widget.now
            ? _buildNow(context, plan, wb)
            : _buildToday(context, plan, wb);
      },
    );
  }

  /// G/U-Woche und Halbjahr-Markierungen beachten (wie auf dem Handy).
  bool _inWeek(TimetableSubject l, String weekBadge) {
    final b = (l.badge ?? '').trim();
    if (TimeTableData.isHalfYearBadge(b)) {
      return TimeTableData.halfYearActive(b, DateTime.now());
    }
    if (weekBadge.isEmpty || b.isEmpty) return true;
    return weekBadge == b;
  }

  /// Lehrplan des heutigen Tages, nach Startzeit sortiert.
  List<TimetableSubject> _lessonsOf(List<List<TimetableSubject>> plan, int i) {
    if (i < 0 || i >= plan.length) return const [];
    final l = [...plan[i]]
      ..sort((a, b) => _min(a.startTime).compareTo(_min(b.startTime)));
    return l;
  }

  Widget _buildNow(
    BuildContext context,
    List<List<TimetableSubject>> plan,
    String weekBadge,
  ) {
    final now = DateTime.now();
    final nowMin = SchoolSchedule.minutesOf(now);
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

    if (weekBadge.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 6),
        WeekBadgeChip(badge: weekBadge, compact: true),
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

  Widget _buildToday(
    BuildContext context,
    List<List<TimetableSubject>> plan,
    String weekBadge,
  ) {
    final now = DateTime.now();
    final nowMin = SchoolSchedule.minutesOf(now);
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isToday ? 'Heute' : _weekdays[day],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            if (weekBadge.isNotEmpty) ...[
              const SizedBox(width: 8),
              WeekBadgeChip(badge: weekBadge, compact: true),
            ],
          ],
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

class _WearUpdatePage extends ConsumerStatefulWidget {
  final UpdateInfo? initial;
  final VoidCallback onSettings;
  const _WearUpdatePage({
    this.initial,
    required this.onSettings,
  });

  @override
  ConsumerState<_WearUpdatePage> createState() => _WearUpdatePageState();
}

class _WearUpdatePageState extends ConsumerState<_WearUpdatePage> {
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
          prefetchUpdate(r.info!);
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
    return LayoutBuilder(
      builder: (context, cons) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cons.maxHeight - 56),
          child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BookLogo(size: 52),
            const SizedBox(height: 6),
            SecretBuildTap(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(versionLabel(), style: const TextStyle(fontSize: 14)),
              ),
            ),
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
                child: const FittedBox(child: Text('Nach Update suchen')),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: widget.onSettings,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Einstellungen'),
            ),
          ],
        ),
      ),
    ),
  ),
  ),
    );
  }
}


/// Hält die Seiten der Uhr am Leben, damit sie beim Blättern nicht neu
/// aufgebaut werden (verhindert leere/verschwindende Seiten).
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Etwas flinkeres Scrollen auf der Uhr (Wischweg wird verstärkt).
class _WearScrollPhysics extends ClampingScrollPhysics {
  final double factor;
  const _WearScrollPhysics({this.factor = 1.6, super.parent});

  @override
  _WearScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _WearScrollPhysics(factor: factor, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      offset * factor;
}


/// Einstellungen der Uhr (rund, scrollbar).
class _WearSettingsPage extends ConsumerStatefulWidget {
  const _WearSettingsPage();

  @override
  ConsumerState<_WearSettingsPage> createState() => _WearSettingsPageState();
}

class _WearSettingsPageState extends ConsumerState<_WearSettingsPage> {
  String _get(String k, String d) =>
      ref.read(sharedOverAccountSettingsProvider).getString(k) ?? d;

  void _set(String k, String v) {
    ref.read(sharedOverAccountSettingsProvider).setString(k, v);
    setState(() {});
  }

  Widget _choice(String title, String key, String def, List<(String, String)> opts) {
    final cur = _get(key, def);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              for (final o in opts)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(o.$1, style: const TextStyle(fontSize: 11)),
                  selected: cur == o.$2,
                  onSelected: (_) => _set(key, o.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subsOn = _get('wear-subs-in-plan', '1') != '0';
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
        body: ListView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 48),
          children: [
            const Center(
              child: Text(
                'Einstellungen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _choice('Textgröße', 'wear-font', '1.0', const [
              ('Klein', '0.85'),
              ('Normal', '1.0'),
              ('Groß', '1.15'),
            ]),
            _choice('Scroll-Tempo', 'wear-scroll', '1.6', const [
              ('Ruhig', '1.2'),
              ('Normal', '1.6'),
              ('Flink', '2.2'),
            ]),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Animationen', style: TextStyle(fontSize: 13)),
              value: _get('wear-anim', '1') != '0',
              onChanged: (v) => _set('wear-anim', v ? '1' : '0'),
            ),
            if (_get('wear-anim', '1') != '0')
              _choice('Animations-Tempo', 'wear-anim-speed', '1.0', const [
                ('Langsam', '0.6'),
                ('Normal', '1.0'),
                ('Schnell', '1.6'),
              ]),
            _choice('Startseite', 'wear-start-page', '0', const [
              ('Jetzt', '0'),
              ('Heute', '1'),
              ('Vertretung', '2'),
            ]),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Vertretungen im Plan',
                style: TextStyle(fontSize: 13),
              ),
              value: subsOn,
              onChanged: (v) => _set('wear-subs-in-plan', v ? '1' : '0'),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fertig'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
