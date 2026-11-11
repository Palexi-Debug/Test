import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/deep_link.dart';
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

    return NavigationBar(
      selectedIndex: selected < 0 ? items.length - 1 : selected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      animationDuration: const Duration(milliseconds: 400),
      destinations: [
        for (final i in items)
          NavigationDestination(
            label: i.label,
            icon: i.icon,
            selectedIcon: i.selectedIcon,
          ),
      ],
      onDestinationSelected: (index) {
        // Zu schnelles Wechseln ignorieren (verhindert graue Bildschirme).
        final now = DateTime.now();
        if (now.difference(_lastTap) < const Duration(milliseconds: 450)) return;
        _lastTap = now;
        if (items[index].key == selectedKey && selectedKey != 'more') return;
        items[index].onTap();
      },
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
