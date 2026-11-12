import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/look.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/utils/whats_new.dart';
import 'package:lanis/view/server_status_page.dart';
import 'package:lanis/view/tutorial/tutorial_page.dart';

class _BarItem {
  final String key;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final VoidCallback onTap;
  const _BarItem(this.key, this.label, this.icon, this.selectedIcon, this.onTap);
}

DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

const _mainSegments = {'substitutions', 'timetable', 'conversations'};

/// Untere Leiste der App: Vertretungen, Stundenplan, Start (Mitte),
/// Nachrichten und "Mehr". Ersetzt die frühere Seitenleiste.
class AppBottomBar extends ConsumerWidget {
  const AppBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final accountType =
        ref.watch(activeAccountProvider.select((a) => a?.accountType)) ??
        AccountType.student;
    final path = GoRouterState.of(context).uri.path;

    final all = <AppletDefinition>[
      ...AppDefinitions.homeApplets,
      ...AppDefinitions.navigationApplets,
    ].where(
      (d) =>
          d.supportedAccountTypes.contains(accountType) &&
          supported.contains(d.appletPhpUrl),
    ).toList();

    AppletDefinition? find(String seg) {
      for (final d in all) {
        if (d.pathSegment == seg) return d;
      }
      return null;
    }

    final items = <_BarItem>[];
    void addApplet(String seg) {
      final d = find(seg);
      if (d == null) return;
      items.add(
        _BarItem(
          seg,
          d.label(context),
          d.icon,
          d.selectedIcon,
          () => context.go(appletHomePath(d, accountType)),
        ),
      );
    }

    addApplet('substitutions');
    addApplet('timetable');
    items.add(
      _BarItem(
        'dashboard',
        'Start',
        const Icon(Icons.home_outlined),
        const Icon(Icons.home_rounded),
        () => context.go('/dashboard'),
      ),
    );
    addApplet('conversations');
    items.add(
      _BarItem(
        'more',
        'Mehr',
        const Icon(Icons.apps_outlined),
        const Icon(Icons.apps_rounded),
        () => _showMore(context, ref, all, accountType),
      ),
    );

    var selectedKey = 'more';
    if (path.startsWith('/dashboard')) {
      selectedKey = 'dashboard';
    } else {
      for (final seg in _mainSegments) {
        if (path.contains('/$seg')) selectedKey = seg;
      }
    }
    final selected = items.indexWhere((i) => i.key == selectedKey);

    final theme = ref.watch(themeSettingsProvider);
    final showLabels = theme['nav-labels'] as bool;
    final activeIndex = selected < 0 ? items.length - 1 : selected;

    void onSelect(int index) {
      // Zu schnelles Wechseln ignorieren (verhindert graue Bildschirme).
      final now = DateTime.now();
      if (now.difference(_lastTap) < const Duration(milliseconds: 450)) return;
      _lastTap = now;
      if (items[index].key == selectedKey && selectedKey != 'more') return;
      items[index].onTap();
    }

    return _AnimatedBar(
      items: items,
      activeIndex: activeIndex,
      showLabels: showLabels,
      onSelect: onSelect,
    );
  }

  void _showMore(
    BuildContext context,
    WidgetRef ref,
    List<AppletDefinition> all,
    AccountType accountType,
  ) {
    final userData = ref.read(sessionProvider).asData?.value?.userData;
    final account = ref.read(activeAccountProvider);
    final name =
        '${userData?['vorname'] ?? ''} ${userData?['nachname'] ?? ''}'.trim();
    final others = all.where((d) => !_mainSegments.contains(d.pathSegment));

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        void act(VoidCallback f) {
          Navigator.pop(sheet);
          f();
        }

        Widget tile(IconData icon, String label, VoidCallback onTap) =>
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => act(onTap),
            );

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          sheet,
                        ).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          color: Theme.of(sheet).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Konto' : name,
                              style: Theme.of(sheet).textTheme.titleMedium,
                            ),
                            Text(
                              account?.schoolName ?? '',
                              style: Theme.of(sheet).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Account wechseln',
                        icon: const Icon(Icons.switch_account_rounded),
                        onPressed: () => act(() => context.push('/accounts')),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                for (final d in others)
                  ListTile(
                    leading: Icon(d.icon.icon),
                    title: Text(d.label(sheet)),
                    onTap: () => act(
                      () => context.go(appletHomePath(d, accountType)),
                    ),
                  ),
                tile(
                  Icons.settings_rounded,
                  'Einstellungen',
                  () => context.go(SettingsDeepLinks.home),
                ),
                tile(
                  Icons.dns_rounded,
                  'Serverstatus',
                  () => openServerStatus(context),
                ),
                tile(
                  Icons.school_outlined,
                  'Tutorial',
                  () => showTutorial(context),
                ),
                tile(
                  Icons.info_outline_rounded,
                  'Version',
                  () => showLocalUpdateInfo(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Eigene, animierte untere Leiste: gleitende Markierung, hüpfende Symbole,
/// weicher Wechsel zwischen Umriss- und gefülltem Symbol.
class _AnimatedBar extends StatelessWidget {
  final List<_BarItem> items;
  final int activeIndex;
  final bool showLabels;
  final ValueChanged<int> onSelect;

  const _AnimatedBar({
    required this.items,
    required this.activeIndex,
    required this.showLabels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lively = AppLook.anim == 2;
    final curve = lively ? Curves.easeOutBack : Curves.easeOutCubic;
    final slide = AppLook.dur(320);
    final fast = AppLook.dur(220);
    const double top = 10;
    const double pillH = 32;
    final double barH = showLabels ? 72 : 58;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barH,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / items.length;
              final pillW = math.min(w - 8, 64.0);
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: slide,
                    curve: curve,
                    left: w * activeIndex + (w - pillW) / 2,
                    top: top,
                    width: pillW,
                    height: pillH,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(pillH / 2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _BarButton(
                            item: items[i],
                            selected: i == activeIndex,
                            showLabel: showLabels,
                            top: top,
                            pillH: pillH,
                            fast: fast,
                            lively: lively,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final _BarItem item;
  final bool selected;
  final bool showLabel;
  final double top;
  final double pillH;
  final Duration fast;
  final bool lively;
  final VoidCallback onTap;

  const _BarButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.top,
    required this.pillH,
    required this.fast,
    required this.lively,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    final scale = selected ? (lively ? 1.22 : 1.08) : 1.0;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: Column(
            children: [
              SizedBox(
                height: pillH,
                child: Center(
                  child: AnimatedScale(
                    scale: scale,
                    duration: fast,
                    curve: lively ? Curves.elasticOut : Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: fast,
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: IconTheme(
                        key: ValueKey(selected),
                        data: IconThemeData(color: color, size: 24),
                        child: selected ? item.selectedIcon : item.icon,
                      ),
                    ),
                  ),
                ),
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: fast,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
