import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/view/server_status_page.dart';

const String _orderKey = 'dashboard-order';
const String _hiddenKey = 'dashboard-hidden';
const String _columnsKey = 'dashboard-columns';
const String _sizeKey = 'dashboard-size';
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
    _style = int.tryParse(settings.getString(_styleKey) ?? '') ?? 0;
    _radius = int.tryParse(settings.getString(_radiusKey) ?? '') ?? 1;
    _greetingOn = settings.getString(_greetingKey) != '0';
  }

  void _save() {
    final settings = ref.read(sharedOverAccountSettingsProvider);
    settings.setString(_orderKey, _order.join(','));
    settings.setString(_hiddenKey, _hidden.join(','));
    settings.setString(_columnsKey, _columns.toString());
    settings.setString(_sizeKey, _size.toString());
    settings.setString(_colorsKey, jsonEncode(_colors));
    settings.setString(_namesKey, jsonEncode(_names));
    settings.setString(_styleKey, _style.toString());
    settings.setString(_radiusKey, _radius.toString());
    settings.setString(_greetingKey, _greetingOn ? '1' : '0');
  }

  Future<void> _editTile(_TileData tile) async {
    final controller = TextEditingController(text: _names[tile.id] ?? tile.label);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kachel anpassen', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                helperText: 'Original: ${tile.label}',
              ),
              onChanged: (v) {
                setState(() {
                  if (v.trim().isEmpty || v.trim() == tile.label) {
                    _names.remove(tile.id);
                  } else {
                    _names[tile.id] = v.trim();
                  }
                });
                _save();
              },
            ),
            const SizedBox(height: 16),
            Text('Farbe', style: Theme.of(ctx).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Automatisch'),
                  onPressed: () {
                    setState(() => _colors.remove(tile.id));
                    _save();
                    Navigator.pop(ctx);
                  },
                ),
                for (final c in _tilePalette)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() => _colors[tile.id] = c.toARGB32());
                      _save();
                      Navigator.pop(ctx);
                    },
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
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _reset() {
    setState(() {
      _order = [];
      _hidden = {};
      _columns = 0;
      _size = 1;
      _colors = {};
      _names = {};
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
      appBar: AppBar(
        title: const Text('Startseite'),
        actions: [
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
          const baseAspect = [1.5, 1.15, 0.95];
          final aspect = baseAspect[_size] * (columns == 1 ? 2.4 : 1.0);
          const padding = 12.0;
          const spacing = 12.0;
          final cellWidth =
              (width - 2 * padding - spacing * (columns - 1)) / columns;
          final cellHeight = cellWidth / aspect;

          Widget cell(String id) {
            final data = byId[id]!;
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
                      icon: data.icon,
                      onTap: data.onTap,
                    ),
              radius: const [12.0, 24.0, 34.0][_radius],
              onEdit: () => _editTile(data),
              background: colors.$1,
              foreground: colors.$2,
              wide: columns == 1,
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
                      width: cellWidth,
                      height: cellHeight,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Opacity(opacity: 0.9, child: tile),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.25, child: tile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(const [12.0, 24.0, 34.0][_radius]),
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
                        _greeting(),
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
                          child: _editPanel(context),
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
                        : ((shownIds.length + columns - 1) ~/ columns) *
                                  cellHeight +
                              (((shownIds.length + columns - 1) ~/ columns) -
                                      1) *
                                  spacing,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < shownIds.length; i++)
                          AnimatedPositioned(
                            key: ValueKey(shownIds[i]),
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                            left: (i % columns) * (cellWidth + spacing),
                            top: (i ~/ columns) * (cellHeight + spacing),
                            width: cellWidth,
                            height: cellHeight,
                            child: cell(shownIds[i]),
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

  Widget _editPanel(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kachel gedrückt halten und verschieben. Tippen ändert Name und Farbe, das Auge blendet eine Kachel aus.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text('Spalten', style: labelStyle),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('Auto')),
                  ButtonSegment<int>(value: 1, label: Text('1')),
                  ButtonSegment<int>(value: 2, label: Text('2')),
                  ButtonSegment<int>(value: 3, label: Text('3')),
                  ButtonSegment<int>(value: 4, label: Text('4')),
                ],
                selected: {_columns},
                onSelectionChanged: (value) {
                  setState(() => _columns = value.first);
                  _save();
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Größe', style: labelStyle),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('Klein')),
                  ButtonSegment<int>(value: 1, label: Text('Mittel')),
                  ButtonSegment<int>(value: 2, label: Text('Groß')),
                ],
                selected: {_size},
                onSelectionChanged: (value) {
                  setState(() => _size = value.first);
                  _save();
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Stil', style: labelStyle),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('Bunt')),
                  ButtonSegment<int>(value: 1, label: Text('Einfarbig')),
                ],
                selected: {_style},
                onSelectionChanged: (value) {
                  setState(() => _style = value.first);
                  _save();
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Ecken', style: labelStyle),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('Eckig')),
                  ButtonSegment<int>(value: 1, label: Text('Rund')),
                  ButtonSegment<int>(value: 2, label: Text('Sehr rund')),
                ],
                selected: {_radius},
                onSelectionChanged: (value) {
                  setState(() => _radius = value.first);
                  _save();
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Begrüßung anzeigen'),
              value: _greetingOn,
              onChanged: (v) {
                setState(() => _greetingOn = v);
                _save();
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Zurücksetzen'),
              ),
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

  const _TileData({
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
    required this.editing,
    required this.hidden,
    required this.onToggleHidden,
  });

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
              Expanded(child: _FitLabel(data.label, titleStyle)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(data.icon, size: 38, color: foreground),
              _FitLabel(data.label, titleStyle),
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
