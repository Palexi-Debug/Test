import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lanis/utils/watch_sync.dart';
import 'package:lanis/utils/garmin_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/view/server_status_page.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/widgets/app_bottom_bar.dart';
import 'package:lanis/view/dashboard/dashboard_layout.dart';
import 'package:lanis/widgets/entrance.dart';
import 'package:lanis/widgets/settings_widgets.dart';
import 'package:lanis/view/tutorial/tutorial_page.dart';

const String _orderKey = 'dashboard-order';
const String _hiddenKey = 'dashboard-hidden';
const String _columnsKey = 'dashboard-columns';
const String _sizeKey = 'dashboard-size';
const String _tileSizesKey = 'dashboard-tile-sizes'; // alt (Stufen)
const String _spansKey = 'dashboard-tile-spans'; // Breite x Höhe je Kachel
const String _colorsKey = 'dashboard-colors';
const String _namesKey = 'dashboard-names';
const String _styleKey = 'dashboard-style'; // 0 bunt, 1 einfarbig
const String _radiusKey = 'dashboard-radius'; // 0 eckig, 1 rund, 2 sehr rund
const String _greetingKey = 'dashboard-greeting'; // 1 an, 0 aus

const List<Color> _tilePalette = [
  Color(0xFF3F51B5),
  Color(0xFF009688),
  Color(0xFF43A047),
  Color(0xFFF9A825),
  Color(0xFFEF6C00),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF546E7A),
];

/// Startseite mit Kacheln. Im Bearbeiten-Modus lassen sich die Kacheln
/// verschieben, ein-/ausblenden und das Raster (Spalten, Größe) ändern.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  List<String> _order = [];
  Set<String> _hidden = {};
  int _columns = 0; // 0 = automatisch
  int _size = 1; // 0 klein, 1 mittel, 2 groß
  bool _editing = false;
  Map<String, int> _colors = {};
  String? _previewId;
  TileSpan? _previewSpan;
  Map<String, TileSpan> _spans = {}; // Größe je Kachel (Breite x Höhe)
  int _lastColumns = 2;
  Map<String, String> _names = {};
  int _style = 0;
  int _radius = 1;
  bool _greetingOn = true;

  static List<String> _split(String? value) =>
      (value ?? '').split(',').where((e) => e.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(sharedOverAccountSettingsProvider);
    _order = _split(settings.getString(_orderKey));
    _hidden = _split(settings.getString(_hiddenKey)).toSet();
    _columns = int.tryParse(settings.getString(_columnsKey) ?? '') ?? 0;
    _size = int.tryParse(settings.getString(_sizeKey) ?? '') ?? 1;
    try {
      _colors = (jsonDecode(settings.getString(_colorsKey) ?? '{}') as Map)
          .map((k, v) => MapEntry(k as String, v as int));
      _names = (jsonDecode(settings.getString(_namesKey) ?? '{}') as Map)
          .map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {}
    _spans = decodeSpans(
      settings.getString(_spansKey),
      settings.getString(_tileSizesKey),
    );
    _style = int.tryParse(settings.getString(_styleKey) ?? '') ?? 0;
    _radius = int.tryParse(settings.getString(_radiusKey) ?? '') ?? 1;
    _greetingOn = settings.getString(_greetingKey) != '0';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTutorialIfFirstTime(context);
    });
    // Garmin-Uhr automatisch aktuell halten (nur wenn schon einmal gesendet)
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        autoSyncGarmin(ref);
        syncCacheToWatch(ref);
      }
    });
    _garminTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        autoSyncGarmin(ref);
        syncCacheToWatch(ref);
      }
    });
  }

  Timer? _garminTimer;

  @override
  void dispose() {
    _garminTimer?.cancel();
    super.dispose();
  }

  void _save() {
    final settings = ref.read(sharedOverAccountSettingsProvider);
    settings.setString(_orderKey, _order.join(','));
    settings.setString(_hiddenKey, _hidden.join(','));
    settings.setString(_columnsKey, _columns.toString());
    settings.setString(_sizeKey, _size.toString());
    settings.setString(_colorsKey, jsonEncode(_colors));
    settings.setString(_namesKey, jsonEncode(_names));
    settings.setString(_spansKey, encodeSpans(_spans));
    settings.setString(_tileSizesKey, '');
    settings.setString(_styleKey, _style.toString());
    settings.setString(_radiusKey, _radius.toString());
    settings.setString(_greetingKey, _greetingOn ? '1' : '0');
  }

  Future<void> _editTile(_TileData tile) async {
    final controller = TextEditingController(text: _names[tile.id] ?? tile.label);
    final maxW = _lastColumns;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
            _save();
          }

          final span = (_spans[tile.id] ?? TileSpan.unit).clamped(maxW);
          void setSpan(TileSpan v) => update(() {
            if (v.isUnit) {
              _spans.remove(tile.id);
            } else {
              _spans[tile.id] = v;
            }
          });

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kachel anpassen',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      helperText: 'Original: ${tile.label}',
                    ),
                    onChanged: (v) => update(() {
                      if (v.trim().isEmpty || v.trim() == tile.label) {
                        _names.remove(tile.id);
                      } else {
                        _names[tile.id] = v.trim();
                      }
                    }),
                  ),
                  const SettingsSectionHeader(
                    'Größe',
                    padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                  ),
                  SettingsSegmentField<int>(
                    label: 'Breite (Spalten)',
                    value: span.w,
                    options: {
                      for (var i = 1; i <= maxW; i++) i: '$i',
                    },
                    onChanged: (v) => setSpan(TileSpan(v, span.h)),
                  ),
                  SettingsSegmentField<int>(
                    label: 'Höhe (Zeilen)',
                    value: span.h,
                    options: {
                      for (var i = 1; i <= TileSpan.maxHeight; i++) i: '$i',
                    },
                    onChanged: (v) => setSpan(TileSpan(span.w, v)),
                  ),
                  const SettingsSectionHeader(
                    'Farbe',
                    padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Automatisch'),
                        onPressed: () => update(() => _colors.remove(tile.id)),
                      ),
                      for (final c in _tilePalette)
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              update(() => _colors[tile.id] = c.toARGB32()),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: c,
                            child: _colors[tile.id] == c.toARGB32()
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kachel anzeigen'),
                    value: !_hidden.contains(tile.id),
                    onChanged: (v) => update(() {
                      if (v) {
                        _hidden.remove(tile.id);
                      } else {
                        _hidden.add(tile.id);
                      }
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  /// Layout-Einstellungen für die ganze Startseite.
  Future<void> _openLayoutSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
            _save();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Startseite anpassen',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SettingsSectionHeader(
                  'Raster',
                  padding: EdgeInsets.fromLTRB(0, 16, 0, 4),
                ),
                SettingsSegmentField<int>(
                  label: 'Spalten',
                  value: _columns,
                  options: const {0: 'Auto', 1: '1', 2: '2', 3: '3', 4: '4'},
                  onChanged: (v) => update(() => _columns = v),
                ),
                SettingsSegmentField<int>(
                  label: 'Zeilenhöhe',
                  hint: 'Gilt für alle Kacheln; einzelne ziehst du an der Ecke.',
                  value: _size,
                  options: const {0: 'Flach', 1: 'Mittel', 2: 'Hoch'},
                  onChanged: (v) => update(() => _size = v),
                ),
                const SettingsSectionHeader(
                  'Aussehen',
                  padding: EdgeInsets.fromLTRB(0, 16, 0, 4),
                ),
                SettingsSegmentField<int>(
                  label: 'Stil',
                  value: _style,
                  options: const {0: 'Bunt', 1: 'Einfarbig'},
                  onChanged: (v) => update(() => _style = v),
                ),
                SettingsSegmentField<int>(
                  label: 'Ecken',
                  value: _radius,
                  options: const {0: 'Eckig', 1: 'Rund', 2: 'Sehr rund'},
                  onChanged: (v) => update(() => _radius = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Begrüßung anzeigen'),
                  value: _greetingOn,
                  onChanged: (v) => update(() => _greetingOn = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _reset();
                      setSheet(() {});
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Alles zurücksetzen'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _reset() {
    setState(() {
      _order = [];
      _hidden = {};
      _columns = 0;
      _size = 1;
      _colors = {};
      _names = {};
      _spans = {};
      _style = 0;
      _radius = 1;
      _greetingOn = true;
    });
    _save();
  }

  /// Tauscht zwei Kacheln: die abgelegte Kachel wandert an die Stelle der
  /// Ziel-Kachel, die Ziel-Kachel (animiert) dorthin, wo die gezogene herkam.
  void _move(List<String> ordered, String from, String to) {
    final list = List<String>.of(ordered);
    final i = list.indexOf(from);
    final j = list.indexOf(to);
    if (i < 0 || j < 0 || i == j) return;
    list[i] = to;
    list[j] = from;
    setState(() => _order = list);
    _save();
  }

  void _toggleHidden(String id) {
    setState(() {
      if (!_hidden.remove(id)) _hidden.add(id);
    });
    _save();
  }

  /// Live-Info zu den Vertretungen (nur wenn schon Daten geladen/gecacht sind).
  String? _substitutionLive() {
    try {
      final parser = ref.watch(substitutionsParserProvider);
      final plan =
          (parser as dynamic).latestResponse?.content as SubstitutionPlan?;
      if (plan == null) return null;
      final now = DateTime.now();
      for (final d in plan.days) {
        final p = d.parsedDate.toString();
        final parsed = DateTime.tryParse(p);
        final isToday =
            (parsed != null &&
                parsed.year == now.year &&
                parsed.month == now.month &&
                parsed.day == now.day) ||
            p.contains(DateFormat('dd.MM.yyyy').format(now)) ||
            p.contains(DateFormat('yyyy-MM-dd').format(now));
        if (isToday) {
          final subs = d.substitutions.toList();
          final n = subs.length;
          if (n == 0) return 'Heute keine Vertretung';
          final head = n == 1 ? '1 Vertretung heute' : '$n Vertretungen heute';
          // Unterrichtszeiten der Schule (Beginn/Ende je Stunde, in Minuten)
          const starts = [480, 525, 595, 640, 705, 750, 840, 880, 925];
          const ends = [525, 570, 640, 685, 750, 795, 880, 920, 965];
          final nowMin = now.hour * 60 + now.minute;
          String clean(Object? v) {
            final t = (v ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
            return (t == '-' || t == '---') ? '' : t;
          }
          ({int first, int last, Object s})? best;
          for (final sub in subs) {
            final nums = RegExp(r'\d+')
                .allMatches(clean((sub as dynamic).stunde))
                .map((m) => int.parse(m.group(0)!))
                .toList();
            if (nums.isEmpty) continue;
            final first = nums.first, last = nums.last;
            if (last < 1 || last > ends.length) continue;
            if (ends[last - 1] <= nowMin) continue; // schon vorbei
            if (best == null || first < best.first) {
              best = (first: first, last: last, s: sub as Object);
            }
          }
          if (best == null) return '$head\nHeute keine weiteren';
          final x = best.s as dynamic;
          final fach = clean(x.fach);
          final vertreter = clean(x.vertreter);
          final now_ = starts[best.first.clamp(1, starts.length) - 1] <= nowMin;
          final line = [
            '${now_ ? 'Jetzt' : 'Nächste'}: Std ${best.first == best.last ? best.first : '${best.first}-${best.last}'}',
            if (fach.isNotEmpty) fach,
            if (vertreter.isNotEmpty) 'Vertr. $vertreter',
          ].join(' · ');
          return '$head\n$line';
        }
      }
      return 'Heute keine Vertretung';
    } catch (_) {
      return null;
    }
  }

  String _firstName() {
    try {
      final v = ref
          .watch(sessionProvider)
          .asData
          ?.value
          ?.userData['vorname']
          ?.toString();
      return (v == null || v.isEmpty) ? '' : ', $v';
    } catch (_) {
      return '';
    }
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Guten Morgen';
    if (hour < 17) return 'Guten Tag';
    return 'Guten Abend';
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final accountType = account?.accountType ?? AccountType.student;
    final scheme = Theme.of(context).colorScheme;

    final defs = <AppletDefinition>[
      ...AppDefinitions.homeApplets,
      ...AppDefinitions.navigationApplets,
    ]
        .where(
          (d) =>
              d.supportedAccountTypes.contains(accountType) &&
              supported.contains(d.appletPhpUrl),
        )
        .toList();

    final allTiles = <_TileData>[
      for (final def in defs)
        _TileData(
          id: def.pathSegment,
          label: def.label(context),
          live: def.pathSegment == 'substitutions' ? _substitutionLive() : null,
          icon: def.icon.icon ?? Icons.apps,
          onTap: () => context.go(appletHomePath(def, accountType)),
        ),
      _TileData(
        id: 'settings',
        label: 'Einstellungen',
        icon: Icons.settings_rounded,
        onTap: () => context.go(SettingsDeepLinks.home),
      ),
      _TileData(
        id: 'status',
        label: 'Serverstatus',
        icon: Icons.dns_rounded,
        onTap: () => openServerStatus(context),
      ),
    ];

    final ids = allTiles.map((t) => t.id).toList();
    final ordered = <String>[
      ..._order.where(ids.contains),
      ...ids.where((id) => !_order.contains(id)),
    ];
    final byId = {for (final t in allTiles) t.id: t};
    final shownIds = _editing
        ? ordered
        : ordered.where((id) => !_hidden.contains(id)).toList();

    final palette = <(Color, Color)>[
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.surfaceContainerHighest, scheme.onSurface),
    ];

    final today = DateFormat('EEEE, d. MMMM yyyy', 'de').format(DateTime.now());
    final schoolName = account?.schoolName ?? '';

    return Scaffold(
      bottomNavigationBar: const AppBottomBar(),
      appBar: AppBar(
        title: const Text('Startseite'),
        actions: [
          IconButton(
            tooltip: 'Account wechseln',
            icon: const Icon(Icons.switch_account_rounded),
            onPressed: () => context.push('/accounts'),
          ),
          IconButton(
            tooltip: _editing ? 'Fertig' : 'Kacheln bearbeiten',
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final autoColumns = width >= 900
              ? 4
              : width >= 600
              ? 3
              : 2;
          final columns = _columns == 0 ? autoColumns : _columns;
          _lastColumns = columns;
          const baseAspect = [1.5, 1.15, 0.95];
          final aspect = baseAspect[_size] * (columns == 1 ? 2.4 : 1.0);
          const padding = 12.0;
          const spacing = 12.0;
          final cellWidth =
              (width - 2 * padding - spacing * (columns - 1)) / columns;
          final cellHeight = cellWidth / aspect;
          final radiusValue = const [12.0, 24.0, 34.0][_radius];

          final layout = placeTiles(shownIds, _spans, columns);
          final placed = layout.placed;

          // Vorschau beim Ziehen: so sähe das Raster nach dem Loslassen aus.
          TileLayout? previewLayout;
          if (_editing && _previewId != null && _previewSpan != null) {
            previewLayout = placeTiles(shownIds, {
              ..._spans,
              _previewId!: _previewSpan!,
            }, columns);
          }
          final previewRows = previewLayout?.rows ?? 0;
          final totalRows = previewRows > layout.rows ? previewRows : layout.rows;

          double xOf(int c) => c * (cellWidth + spacing);
          double yOf(int r) => r * (cellHeight + spacing);
          double wOf(int w) => w * cellWidth + (w - 1) * spacing;
          double hOf(int h) => h * cellHeight + (h - 1) * spacing;

          Widget cell(String id) {
            final data = byId[id]!;
            final span = placed[id]!;
            var colors = _style == 1
                ? palette[3]
                : palette[ordered.indexOf(id) % palette.length];
            final custom = _colors[id];
            if (custom != null) {
              final bg = Color(custom);
              final dark = Theme.of(context).brightness == Brightness.dark;
              final tinted = Color.lerp(bg, dark ? Colors.black : Colors.white, dark ? 0.35 : 0.0)!;
              colors = (
                tinted,
                tinted.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              );
            }
            final tile = _TileCard(
              data: _names[id] == null
                  ? data
                  : _TileData(
                      id: data.id,
                      label: _names[id]!,
                      live: data.live,
                      icon: data.icon,
                      onTap: data.onTap,
                    ),
              radius: radiusValue,
              onEdit: () => _editTile(data),
              background: colors.$1,
              foreground: colors.$2,
              wide: span.h == 1 && (columns == 1 || span.w > 1),
              tall: span.h > 1,
              editing: _editing,
              hidden: _hidden.contains(id),
              onToggleHidden: () => _toggleHidden(id),
            );
            if (!_editing) return tile;
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data != id,
              onAcceptWithDetails: (details) =>
                  _move(ordered, details.data, id),
              builder: (context, candidate, rejected) =>
                  LongPressDraggable<String>(
                    data: id,
                    delay: const Duration(milliseconds: 150),
                    feedback: SizedBox(
                      width: wOf(span.w),
                      height: hOf(span.h),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Opacity(opacity: 0.9, child: tile),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.25, child: tile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radiusValue),
                        border: candidate.isNotEmpty
                            ? Border.all(color: scheme.primary, width: 3)
                            : null,
                      ),
                      child: tile,
                    ),
                  ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: !_greetingOn
                    ? const SizedBox(height: 4)
                    : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting() + _firstName(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schoolName.isEmpty ? today : '$schoolName · $today',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: _editing
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _editHint(context),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(padding, 0, padding, 24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: shownIds.isEmpty
                        ? 0
                        : totalRows * cellHeight + (totalRows - 1) * spacing,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < shownIds.length; i++)
                          AnimatedPositioned(
                            key: ValueKey(shownIds[i]),
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                            left: xOf(placed[shownIds[i]]!.col),
                            top: yOf(placed[shownIds[i]]!.row),
                            width: wOf(placed[shownIds[i]]!.w),
                            height: hOf(placed[shownIds[i]]!.h),
                            child: Entrance(index: i, child: cell(shownIds[i])),
                          ),
                        // Vorschau-Umrandung: so groß wird die Kachel.
                        if (previewLayout != null &&
                            previewLayout.placed[_previewId] != null)
                          Positioned(
                            left: xOf(previewLayout.placed[_previewId]!.col),
                            top: yOf(previewLayout.placed[_previewId]!.row),
                            width: wOf(previewLayout.placed[_previewId]!.w),
                            height: hOf(previewLayout.placed[_previewId]!.h),
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: scheme.primary,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    radiusValue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Zieh-Stücke liegen über den Kacheln (nicht darin), damit
                        // Ziehen in alle Richtungen funktioniert und die Seite
                        // dabei nicht mitscrollt.
                        if (_editing)
                          for (final id in shownIds)
                            if (placed[id] != null)
                              Positioned(
                                key: ValueKey('handle-$id'),
                                left: xOf(placed[id]!.col) +
                                    wOf(placed[id]!.w) -
                                    _ResizeHandle.size,
                                top: yOf(placed[id]!.row) +
                                    hOf(placed[id]!.h) -
                                    _ResizeHandle.size,
                                width: _ResizeHandle.size,
                                height: _ResizeHandle.size,
                                child: _ResizeHandle(
                                  start: TileSpan(
                                    placed[id]!.w,
                                    placed[id]!.h,
                                  ),
                                  stepX: cellWidth + spacing,
                                  stepY: cellHeight + spacing,
                                  maxW: columns,
                                  onPreview: (span) {
                                    if (span == null) {
                                      if (_previewId != null) {
                                        setState(() {
                                          _previewId = null;
                                          _previewSpan = null;
                                        });
                                      }
                                    } else if (_previewId != id ||
                                        _previewSpan != span) {
                                      setState(() {
                                        _previewId = id;
                                        _previewSpan = span;
                                      });
                                    }
                                  },
                                  onCommit: (span) {
                                    setState(() {
                                      if (span.isUnit) {
                                        _spans.remove(id);
                                      } else {
                                        _spans[id] = span;
                                      }
                                    });
                                    _save();
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _editHint(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Halten und ziehen zum Verschieben · Ecke ziehen ändert Breite und Höhe · Tippen für Name, Größe, Farbe',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _openLayoutSheet,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Layout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileData {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? live;

  const _TileData({
    this.live,
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _TileCard extends StatelessWidget {
  final _TileData data;
  final Color background;
  final Color foreground;
  final bool wide;
  final bool tall;
  final bool editing;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onEdit;
  final double radius;

  const _TileCard({
    required this.onEdit,
    required this.radius,
    required this.data,
    required this.background,
    required this.foreground,
    required this.wide,
    this.tall = false,
    required this.editing,
    required this.hidden,
    required this.onToggleHidden,
  });

  Widget _labelBlock(TextStyle? titleStyle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _FitLabel(data.label, titleStyle),
      if (data.live != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            data.live!,
            maxLines: tall ? 8 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.bold,
    );
    final Widget content = wide
        ? Row(
            children: [
              Icon(data.icon, size: 34, color: foreground),
              const SizedBox(width: 16),
              Expanded(child: _labelBlock(titleStyle)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(data.icon, size: tall ? 48 : 38, color: foreground),
              _labelBlock(titleStyle),
            ],
          );

    return Opacity(
      opacity: editing && hidden ? 0.45 : 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: editing ? onEdit : data.onTap,
                child: Padding(padding: const EdgeInsets.all(16), child: content),
              ),
            ),
          ),
          if (editing)
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: hidden ? 'Einblenden' : 'Ausblenden',
                icon: Icon(
                  hidden ? Icons.visibility_off : Icons.visibility,
                  color: foreground,
                ),
                onPressed: onToggleHidden,
              ),
            ),
        ],
      ),
    );
  }
}

/// Beschriftung, die sich automatisch verkleinert statt abgeschnitten zu werden.
class _FitLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _FitLabel(this.text, this.style);

  @override
  Widget build(BuildContext context) {
    final multiWord = text.contains(' ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: multiWord ? w : 100000),
            child: Text(
              text,
              style: style,
              maxLines: multiWord ? 2 : 1,
              softWrap: multiWord,
            ),
          ),
        );
      },
    );
  }
}


/// Zieh-Stück zum Ändern von Breite und Höhe einer Kachel (Bearbeiten-Modus).
///
/// Gewinnt die Gesten-Arena sofort ([EagerGestureRecognizer]), damit weder die
/// Seite mitscrollt noch das Verschieben der Kachel dazwischenfunkt; die
/// Bewegung wird über rohe Zeiger-Ereignisse gelesen.
class _ResizeHandle extends StatefulWidget {
  static const double size = 52;

  final TileSpan start;
  final double stepX;
  final double stepY;
  final int maxW;
  final ValueChanged<TileSpan?> onPreview;
  final ValueChanged<TileSpan> onCommit;

  const _ResizeHandle({
    required this.start,
    required this.stepX,
    required this.stepY,
    required this.maxW,
    required this.onPreview,
    required this.onCommit,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  Offset _delta = Offset.zero;
  bool _active = false;
  TileSpan? _last;

  TileSpan _target() {
    final dw = (_delta.dx / widget.stepX).round();
    final dh = (_delta.dy / widget.stepY).round();
    return TileSpan(
      widget.start.w + dw,
      widget.start.h + dh,
    ).clamped(widget.maxW);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _delta = Offset.zero;
          _active = true;
          _last = widget.start;
        },
        onPointerMove: (e) {
          if (!_active) return;
          _delta += e.delta;
          final t = _target();
          if (t != _last) {
            _last = t;
            widget.onPreview(t);
          }
        },
        onPointerUp: (_) {
          if (!_active) return;
          _active = false;
          final t = _target();
          widget.onPreview(null);
          if (t != widget.start) widget.onCommit(t);
        },
        onPointerCancel: (_) {
          _active = false;
          widget.onPreview(null);
        },
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.open_in_full_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
