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


class _LookSection extends ConsumerWidget {
  const _LookSection();

  static const _presets = <Color>[
    Color(0xFF3F51B5), Color(0xFF2196F3), Color(0xFF00BCD4), Color(0xFF009688),
    Color(0xFF4CAF50), Color(0xFFCDDC39), Color(0xFFFFC107), Color(0xFFFF9800),
    Color(0xFFF44336), Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeSettingsProvider);
    final shared = ref.read(sharedOverAccountSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    void set(String key, String value) {
      shared.setString(key, value);
      notifyThemeChanged(ref);
    }

    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          color: scheme.primary,
        ),
      ),
    );

    final customColor = AppLook.parseHex(t['accent-hex'] as String);
    final currentHue = HSVColor.fromColor(
      customColor ?? const Color(0xFF3F51B5),
    ).hue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    shared.setString('accent-hex', AppLook.toHex(c));
                    set('color', 'custom');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t['color'] == 'custom' &&
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
          value: currentHue,
          min: 0,
          max: 360,
          display: (v) => '${v.round()}°',
          onEnd: (v) {
            shared.setString(
              'accent-hex',
              AppLook.toHex(HSVColor.fromAHSV(1, v, 0.65, 0.8).toColor()),
            );
            set('color', 'custom');
          },
        ),
        title('Form & Größe'),
        _LookSlider(
          label: 'Eckenrundung',
          value: t['look-radius'] as double,
          min: 4,
          max: 32,
          display: (v) => v.round().toString(),
          onEnd: (v) => set('look-radius', v.toStringAsFixed(0)),
        ),
        _LookSlider(
          label: 'Schriftgröße',
          value: t['look-font'] as double,
          min: 0.85,
          max: 1.3,
          display: (v) => '${(v * 100).round()} %',
          onEnd: (v) => set('look-font', v.toStringAsFixed(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: -1.0, label: Text('Kompakt')),
              ButtonSegment(value: 0.0, label: Text('Normal')),
              ButtonSegment(value: 1.0, label: Text('Luftig')),
            ],
            selected: {t['look-density'] as double},
            onSelectionChanged: (v) => set('look-density', v.first.toString()),
          ),
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
            selected: {t['look-anim'] as int},
            onSelectionChanged: (v) => set('look-anim', v.first.toString()),
          ),
        ),
        title('Untere Leiste & Stundenplan'),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Beschriftung der unteren Leiste'),
          value: t['nav-labels'] as bool,
          onChanged: (v) => set('nav-labels', v ? '1' : '0'),
        ),
        _LookSlider(
          label: 'Farbintensität im Stundenplan',
          value: t['tt-intensity'] as double,
          min: 0.3,
          max: 1.0,
          display: (v) => '${(v * 100).round()} %',
          onEnd: (v) => set('tt-intensity', v.toStringAsFixed(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Aussehen zurücksetzen'),
            onPressed: () {
              for (final k in [
                'accent-hex', 'look-radius', 'look-font', 'look-density',
                'look-anim', 'nav-labels', 'tt-intensity',
              ]) {
                shared.setString(k, '');
              }
              set('color', 'standard');
            },
          ),
        ),
      ],
    );
  }
}

class _LookSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) display;
  final ValueChanged<double> onEnd;

  const _LookSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onEnd,
  });

  @override
  State<_LookSlider> createState() => _LookSliderState();
}

class _LookSliderState extends State<_LookSlider> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final v = (_drag ?? widget.value).clamp(widget.min, widget.max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.label)),
              Text(widget.display(v)),
            ],
          ),
          Slider(
            value: v,
            min: widget.min,
            max: widget.max,
            onChanged: (x) => setState(() => _drag = x),
            onChangeEnd: (x) {
              widget.onEnd(x);
              setState(() => _drag = null);
            },
          ),
        ],
      ),
    );
  }
}
