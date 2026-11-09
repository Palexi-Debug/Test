import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/view/server_status_page.dart';

/// Startseite mit Kacheln für alle verfügbaren Bereiche.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Guten Morgen';
    if (hour < 17) return 'Guten Tag';
    return 'Guten Abend';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final tiles = <_TileData>[
      for (final def in defs)
        _TileData(
          label: def.label(context),
          icon: def.icon.icon ?? Icons.apps,
          onTap: () => context.go(appletHomePath(def, accountType)),
        ),
      _TileData(
        label: 'Einstellungen',
        icon: Icons.settings_rounded,
        onTap: () => context.go(SettingsDeepLinks.home),
      ),
      _TileData(
        label: 'Serverstatus',
        icon: Icons.dns_rounded,
        onTap: () => openServerStatus(context),
      ),
    ];

    final palette = <(Color, Color)>[
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.surfaceContainerHighest, scheme.onSurface),
    ];

    final today = DateFormat('EEEE, d. MMMM yyyy', 'de').format(DateTime.now());
    final schoolName = account?.schoolName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Startseite')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 600
              ? 3
              : 2;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverGrid.count(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    for (var i = 0; i < tiles.length; i++)
                      _TileCard(
                        data: tiles[i],
                        background: palette[i % palette.length].$1,
                        foreground: palette[i % palette.length].$2,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TileData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TileData({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _TileCard extends StatelessWidget {
  final _TileData data;
  final Color background;
  final Color foreground;

  const _TileCard({
    required this.data,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(data.icon, size: 38, color: foreground),
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
