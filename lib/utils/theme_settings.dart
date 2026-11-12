import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

class ThemeRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final themeRevisionProvider = NotifierProvider<ThemeRevision, int>(
  ThemeRevision.new,
);

final themeSettingsProvider = Provider<Map<String, dynamic>>((ref) {
  ref.watch(themeRevisionProvider);
  final settings = ref.watch(sharedOverAccountSettingsProvider);
  return {
    'color': settings.getString('color') ?? 'standard',
    'theme': settings.getString('theme') ?? 'system',
    'is-amoled': settings.getBool('is-amoled') ?? false,
    'accent-hex': settings.getString('accent-hex') ?? '',
    'look-radius':
        double.tryParse(settings.getString('look-radius') ?? '') ?? 20.0,
    'look-font': double.tryParse(settings.getString('look-font') ?? '') ?? 1.0,
    'look-density':
        double.tryParse(settings.getString('look-density') ?? '') ?? 0.0,
    'look-anim': int.tryParse(settings.getString('look-anim') ?? '') ?? 1,
    'look-card': int.tryParse(settings.getString('look-card') ?? '') ?? 0,
    'look-center': settings.getString('look-center') == '1',
    'nav-order': settings.getString('nav-order') ?? '',
    'nav-labels': settings.getString('nav-labels') != '0',
    'tt-intensity':
        double.tryParse(settings.getString('tt-intensity') ?? '') ?? 1.0,
  };
});

void notifyThemeChanged(WidgetRef ref) {
  ref.read(themeRevisionProvider.notifier).bump();
}
