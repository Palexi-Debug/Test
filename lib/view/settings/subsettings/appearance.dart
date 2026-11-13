import 'package:flutter/material.dart';
import 'package:lanis/utils/look.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/themes.dart';
import 'package:lanis/widgets/radio_pills.dart';
import 'package:lanis/widgets/switch_tile.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

class AppearanceSettings extends ConsumerSettingsColours {
  final bool showBackButton;
  const AppearanceSettings({super.key, this.showBackButton = true});

  @override
  ConsumerState<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState
    extends ConsumerSettingsColoursState<AppearanceSettings> {
  ThemeData? dynamicTheme = Themes.dynamicTheme.lightTheme;

  @override
  void didChangeDependencies() {
    setState(() {
      dynamicTheme = Theme.of(context).brightness == Brightness.dark
          ? Themes.dynamicTheme.darkTheme
          : Themes.dynamicTheme.lightTheme;
    });

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeSettingsProvider);
    final shared = ref.read(sharedOverAccountSettingsProvider);

    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).appearance),
      showBackButton: widget.showBackButton,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            AppLocalizations.of(context).theme,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: RadioPillGroup<String>(
            groupValue: theme['theme'] as String,
            onChanged: (value) {
              shared.setString('theme', value);
              notifyThemeChanged(ref);
            },
            color: foregroundColor,
            pills: [
              RadioPillGroupItem.vertical(
                title: Text(AppLocalizations.of(context).system),
                leading: Icon(Icons.phone_android_rounded),
                value: "system",
              ),
              RadioPillGroupItem.vertical(
                title: Text(AppLocalizations.of(context).light),
                leading: Icon(Icons.light_mode_rounded),
                value: "light",
              ),
              RadioPillGroupItem.vertical(
                title: Text(AppLocalizations.of(context).dark),
                leading: Icon(Icons.dark_mode_rounded),
                value: "dark",
              ),
            ],
          ),
        ),
        Visibility(
          visible: Theme.of(context).brightness == Brightness.dark,
          child: Column(
            children: [
              SizedBox(height: 16.0),
              MinimalSwitchTile(
                title: Text(AppLocalizations.of(context).amoledMode),
                leading: Icon(Icons.contrast_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                useInkWell: true,
                value: theme['is-amoled'] as bool,
                onChanged: (value) {
                  shared.setBool('is-amoled', value);
                  notifyThemeChanged(ref);
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 24.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            AppLocalizations.of(context).accentColor,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: RadioPillGroup<String>.large(
            groupValue: theme['color'] as String,
            onChanged: (value) {
              shared.setString('color', value);
              notifyThemeChanged(ref);
            },
            color: foregroundColor,
            pills: [
              RadioPillGroupItem.horizontal(
                title: Text(AppLocalizations.of(context).standard),
                value: "standard",
                trailing: TrailingCircle(
                  color: Themes
                      .standardTheme
                      .lightTheme!
                      .colorScheme
                      .primaryFixedDim,
                  selectedBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  selected: theme['color'] == "standard",
                ),
              ),
              if (dynamicTheme != null)
                RadioPillGroupItem.horizontal(
                  title: Text(AppLocalizations.of(context).dynamicColor),
                  value: "dynamic",
                  trailing: TrailingCircle.custom(
                    selectedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    selected: theme['color'] == "dynamic",
                    customCircle: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(100),
                              ),
                              color: dynamicTheme!.colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(100),
                                    ),
                                    color: dynamicTheme!
                                        .colorScheme
                                        .inversePrimary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      bottomRight: Radius.circular(100),
                                    ),
                                    color: dynamicTheme!.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            customPillBuilder:
                (String? groupValue, void Function(String)? onChanged) {
              return Column(
                children: [
                  SizedBox(height: 2.0),
                  RadioTrailingCircleGroup<String>(
                    groupValue: groupValue,
                    onChanged: onChanged,
                    border: RadioBorder.bottom,
                    color: foregroundColor,
                    colors: List<ColorPair<String>>.generate(
                      Themes.flutterColorThemes.keys.length,
                      (index) {
                        final key = Themes.flutterColorThemes.keys.elementAt(
                          index,
                        );

                        return ColorPair<String>(
                          color: Themes
                              .flutterColorThemes[key]!
                              .lightTheme!
                              .colorScheme
                              .primaryFixedDim,
                          value: key,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 28.0),
              Icon(
                Icons.info_outline_rounded,
                size: 20.0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 8.0),
              Text(
                dynamicTheme == null
                    ? AppLocalizations.of(
                        context,
                      ).settingsUnsupportedInfoAppearance
                    : AppLocalizations.of(context).settingsInfoDynamicColor,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const _LookSection(),
      ],
    );
  }
}


class _LookSection extends ConsumerStatefulWidget {
  const _LookSection();

  @override
  ConsumerState<_LookSection> createState() => _LookSectionState();
}

class _LookSectionState extends ConsumerState<_LookSection> {
  /// Noch nicht übernommene Änderungen (Vorschau).
  final Map<String, String> _p = {};

  static const _presets = <Color>[
    Color(0xFF3F51B5), Color(0xFF2196F3), Color(0xFF00BCD4), Color(0xFF009688),
    Color(0xFF4CAF50), Color(0xFFCDDC39), Color(0xFFFFC107), Color(0xFFFF9800),
    Color(0xFFF44336), Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF607D8B),
  ];

  static const _navLabels = {
    'substitutions': 'Vertretungen',
    'timetable': 'Stundenplan',
    'dashboard': 'Start',
    'conversations': 'Nachrichten',
  };
  static const _defaultOrder = [
    'substitutions',
    'timetable',
    'dashboard',
    'conversations',
  ];

  static const _allKeys = [
    'accent-hex', 'look-radius', 'look-font', 'look-density', 'look-anim',
    'nav-labels', 'tt-intensity', 'tt-grey-cancelled', 'look-card', 'look-center', 'nav-order',
  ];

  Map<String, dynamic> get _t => ref.read(themeSettingsProvider);

  String _str(String key, String saved) => _p[key] ?? saved;

  double _num(String key, double fallback) =>
      double.tryParse(_p[key] ?? '') ?? (_t[key] as double? ?? fallback);

  int _int(String key) =>
      int.tryParse(_p[key] ?? '') ?? (_t[key] as int? ?? 0);

  String get _color => _p['color'] ?? _t['color'] as String;

  Color get _seed {
    final c = _color;
    if (c == 'custom') {
      return AppLook.parseHex(_str('accent-hex', _t['accent-hex'] as String)) ??
          Colors.indigo;
    }
    if (c == 'dynamic') return Theme.of(context).colorScheme.primary;
    if (c == 'standard') return Colors.indigo;
    return Themes.seedColors[c] ?? Colors.indigo;
  }

  bool get _labels =>
      (_p['nav-labels'] ?? (_t['nav-labels'] as bool ? '1' : '0')) != '0';

  bool get _greyCancelled =>
      (_p['tt-grey-cancelled'] ??
          (_t['tt-grey-cancelled'] as bool ? '1' : '0')) !=
      '0';

  bool get _center =>
      (_p['look-center'] ?? (_t['look-center'] as bool ? '1' : '0')) == '1';

  List<String> get _order {
    final raw = _p['nav-order'] ?? _t['nav-order'] as String;
    final list = raw.split(',').where(_navLabels.containsKey).toList();
    for (final k in _defaultOrder) {
      if (!list.contains(k)) list.add(k);
    }
    return list;
  }

  void _set(String key, String value) => setState(() => _p[key] = value);

  void _apply() {
    final shared = ref.read(sharedOverAccountSettingsProvider);
    for (final e in _p.entries) {
      shared.setString(e.key, e.value);
    }
    setState(_p.clear);
    notifyThemeChanged(ref);
  }

  void _resetAll() {
    final shared = ref.read(sharedOverAccountSettingsProvider);
    for (final k in _allKeys) {
      shared.setString(k, '');
    }
    shared.setString('color', 'standard');
    setState(_p.clear);
    notifyThemeChanged(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final customColor = AppLook.parseHex(
      _str('accent-hex', _t['accent-hex'] as String),
    );
    final hue = HSVColor.fromColor(
      customColor ?? const Color(0xFF3F51B5),
    ).hue;

    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          color: scheme.primary,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title('Vorschau'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Preview(
            seed: _seed,
            radius: _num('look-radius', 20),
            density: _num('look-density', 0),
            font: _num('look-font', 1),
            card: _int('look-card'),
            center: _center,
            labels: _labels,
            order: _order,
          ),
        ),
        if (_p.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Übernehmen'),
                    onPressed: _apply,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(_p.clear),
                  child: const Text('Verwerfen'),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Änderungen unten erscheinen zuerst hier in der Vorschau und '
              'gelten erst nach "Übernehmen".',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        title('Eigene Farbe'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _presets)
                GestureDetector(
                  onTap: () {
                    _set('accent-hex', AppLook.toHex(c));
                    _set('color', 'custom');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == 'custom' &&
                                customColor?.toARGB32() == c.toARGB32()
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _LookSlider(
          label: 'Farbton frei wählen',
          value: hue,
          min: 0,
          max: 360,
          display: (v) => '${v.round()}°',
          onChanged: (v) {
            _set(
              'accent-hex',
              AppLook.toHex(HSVColor.fromAHSV(1, v, 0.65, 0.8).toColor()),
            );
            _set('color', 'custom');
          },
        ),
        title('Form & Größe'),
        _LookSlider(
          label: 'Eckenrundung',
          value: _num('look-radius', 20),
          min: 4,
          max: 32,
          display: (v) => v.round().toString(),
          onChanged: (v) => _set('look-radius', v.toStringAsFixed(0)),
        ),
        _LookSlider(
          label: 'Schriftgröße',
          value: _num('look-font', 1),
          min: 0.85,
          max: 1.3,
          display: (v) => '${(v * 100).round()} %',
          onChanged: (v) => _set('look-font', v.toStringAsFixed(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: -1.0, label: Text('Kompakt')),
              ButtonSegment(value: 0.0, label: Text('Normal')),
              ButtonSegment(value: 1.0, label: Text('Luftig')),
            ],
            selected: {_num('look-density', 0)},
            onSelectionChanged: (v) => _set('look-density', v.first.toString()),
          ),
        ),
        title('Karten-Stil'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Flach')),
              ButtonSegment(value: 1, label: Text('Umriss')),
              ButtonSegment(value: 2, label: Text('Schatten')),
            ],
            selected: {_int('look-card')},
            onSelectionChanged: (v) => _set('look-card', v.first.toString()),
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Titel in der Leiste zentrieren'),
          value: _center,
          onChanged: (v) => _set('look-center', v ? '1' : '0'),
        ),
        title('Animationen'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Aus')),
              ButtonSegment(value: 1, label: Text('Dezent')),
              ButtonSegment(value: 2, label: Text('Lebendig')),
            ],
            selected: {
              int.tryParse(_p['look-anim'] ?? '') ?? (_t['look-anim'] as int),
            },
            onSelectionChanged: (v) => _set('look-anim', v.first.toString()),
          ),
        ),
        title('Untere Leiste'),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Beschriftung anzeigen'),
          value: _labels,
          onChanged: (v) => _set('nav-labels', v ? '1' : '0'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            onReorder: (from, to) {
              final list = [..._order];
              if (to > from) to -= 1;
              list.insert(to, list.removeAt(from));
              _set('nav-order', list.join(','));
            },
            children: [
              for (final k in _order)
                ListTile(
                  key: ValueKey(k),
                  dense: true,
                  leading: const Icon(Icons.drag_indicator_rounded),
                  title: Text(_navLabels[k]!),
                ),
            ],
          ),
        ),
        title('Stundenplan'),
        _LookSlider(
          label: 'Farbintensität',
          value: _num('tt-intensity', 1),
          min: 0.3,
          max: 1.0,
          display: (v) => '${(v * 100).round()} %',
          onChanged: (v) => _set('tt-intensity', v.toStringAsFixed(2)),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Ausfall grau anzeigen'),
          subtitle: const Text('Entfallende Stunden werden im Stundenplan grau'),
          value: _greyCancelled,
          onChanged: (v) => _set('tt-grey-cancelled', v ? '1' : '0'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Alles zurücksetzen'),
            onPressed: _resetAll,
          ),
        ),
      ],
    );
  }
}

/// Kleine Nachbildung der App mit den noch nicht übernommenen Werten.
class _Preview extends StatelessWidget {
  final Color seed;
  final double radius;
  final double density;
  final double font;
  final int card;
  final bool center;
  final bool labels;
  final List<String> order;

  const _Preview({
    required this.seed,
    required this.radius,
    required this.density,
    required this.font,
    required this.card,
    required this.center,
    required this.labels,
    required this.order,
  });

  static const _icons = {
    'substitutions': Icons.sync_alt_rounded,
    'timetable': Icons.calendar_view_week_rounded,
    'dashboard': Icons.home_rounded,
    'conversations': Icons.chat_bubble_rounded,
  };
  static const _names = {
    'substitutions': 'Vertretung',
    'timetable': 'Plan',
    'dashboard': 'Start',
    'conversations': 'Chat',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final themes = Themes.getNewTheme(
      seed,
      radius: radius,
      density: density,
      cardStyle: card,
      centerTitle: center,
    );
    final data = (dark ? themes.darkTheme : themes.lightTheme)!;
    return Theme(
      data: data,
      child: Builder(
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          final text = Theme.of(ctx).textTheme;
          return MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              textScaler: TextScaler.linear(font),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 44,
                    alignment: center ? Alignment.center : Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Schulportal', style: text.titleMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        for (final label in ['Vertretungen', 'Stundenplan'])
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.all(4),
                              child: Padding(
                                padding: EdgeInsets.all(12 + density * 3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.circle, size: 14, color: cs.primary),
                                    const SizedBox(height: 6),
                                    Text(label, style: text.bodyMedium),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    color: cs.surfaceContainer,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        for (var i = 0; i < order.length; i++)
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? cs.secondaryContainer
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    _icons[order[i]],
                                    size: 18,
                                    color: i == 0
                                        ? cs.onSecondaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                                if (labels)
                                  Text(
                                    _names[order[i]]!,
                                    style: text.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LookSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) display;
  final ValueChanged<double> onChanged;

  const _LookSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(display(v)),
            ],
          ),
          Slider(value: v, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}
