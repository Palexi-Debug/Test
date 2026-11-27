import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/app_lock.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/utils/whats_new.dart';
import 'package:lanis/view/wear/wear_mode.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/view/settings/start_page.dart';
import 'package:lanis/view/settings/subsettings/cache.dart';
import 'package:lanis/view/settings/subsettings/sync_settings.dart';
import 'package:lanis/widgets/press_tile.dart';
import 'package:lanis/widgets/settings_widgets.dart';

class SettingsGroup {
  final String? title;
  final List<SettingsTile> tiles;

  const SettingsGroup({this.title, required this.tiles});
}

class SettingsTile {
  final String Function(BuildContext context) title;
  final Future<String> Function(BuildContext context) subtitle;
  final IconData icon;
  final Future<void> Function(BuildContext context) screen;
  final Future<bool> Function() show;
  final String? routePath;

  static Future<bool> alwaysShow() async {
    return true;
  }

  const SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
    this.show = alwaysShow,
    this.routePath,
  });
}

class SettingsScreen extends ConsumerSettingsColours {
  /// When true, used as the master list inside [SettingsTabletShell].
  final bool embeddedInTabletShell;

  const SettingsScreen({super.key, this.embeddedInTabletShell = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerSettingsColoursState<SettingsScreen> {
  bool _supports(AppletMeta applet) =>
      ref.read(supportedAppletPhpUrlsProvider).contains(applet.appletPhpUrl);

  /// Ein/Aus-Zustand einer lokalen Einstellung als Untertitel.
  String _onOff(String key, String on, String off, {bool defaultOn = true}) {
    final v = ref.read(sharedOverAccountSettingsProvider).getString(key);
    final enabled = defaultOn ? v != '0' : v == '1';
    return enabled ? on : off;
  }

  List<SettingsGroup> _buildSettingsTiles() {
    return [
      SettingsGroup(
        title: 'Darstellung',
        tiles: [
          SettingsTile(
            title: (context) => AppLocalizations.of(context).appearance,
            subtitle: (context) async =>
                'Farben, Design, Navigationsleiste, Stundenplan-Optik',
            icon: Icons.palette_rounded,
            routePath: SettingsDeepLinks.appearance,
            screen: (context) async =>
                context.push(SettingsDeepLinks.appearance),
          ),
          SettingsTile(
            title: (context) => 'Startseite',
            subtitle: (context) async => 'Welcher Bereich zuerst geöffnet wird',
            icon: Icons.home_rounded,
            screen: (context) async => showStartPageDialog(context),
          ),
          SettingsTile(
            title: (context) => AppLocalizations.of(context).language,
            subtitle: (context) async {
              String code = Localizations.localeOf(context).languageCode;

              if (code.contains("de")) {
                return "Deutsch";
              } else if (code.contains("en")) {
                return "English";
              } else {
                return "Unknown";
              }
            },
            icon: Icons.language_rounded,
            screen: (context) async {
              if (Platform.isAndroid) {
                AppSettings.openAppSettings(type: AppSettingsType.appLocale);
              }
              if (Platform.isIOS) {
                await showCupertinoDialog(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: Text(
                        AppLocalizations.of(context).openSystemSettings,
                      ),
                      content: Text(
                        AppLocalizations.of(
                          context,
                        ).openIOSSettingsToChangeLanguage,
                      ),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context).cancel),
                        ),
                        CupertinoDialogAction(
                          onPressed: () {
                            Navigator.pop(context);
                            AppSettings.openAppSettings(
                              type: AppSettingsType.appLocale,
                            );
                          },
                          child: Text(AppLocalizations.of(context).ok),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            show: () async {
              DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
              if (Platform.isAndroid) {
                final androidInfo = await deviceInfo.androidInfo;
                return androidInfo.version.sdkInt >= 33;
              } else if (Platform.isIOS) {
                final iosInfo = await deviceInfo.iosInfo;
                final versionParts = iosInfo.systemVersion.split('.');
                final majorVersion = int.tryParse(versionParts[0]) ?? 0;
                return majorVersion >= 13;
              }
              return false;
            },
          ),
        ],
      ),
      SettingsGroup(
        title: 'Bereiche',
        tiles: [
          if (_supports(Applets.substitutions))
            SettingsTile(
              title: (context) => 'Vertretungsplan',
              subtitle: (context) async =>
                  'Im Stundenplan anzeigen, Ausfälle grau, Filter',
              icon: Icons.swap_horiz_rounded,
              routePath: SettingsDeepLinks.substitutions,
              screen: (context) async =>
                  context.push(SettingsDeepLinks.substitutions),
            ),
          if (_supports(Applets.timetable))
            SettingsTile(
              title: (context) =>
                  AppLocalizations.of(context).customizeTimetable,
              subtitle: (context) async =>
                  AppLocalizations.of(context).customizeTimetableDescription,
              icon: Icons.timelapse,
              routePath: SettingsDeepLinks.timetable,
              screen: (context) async =>
                  context.push(SettingsDeepLinks.timetable),
            ),
          if (_supports(Applets.calendar))
            SettingsTile(
              title: (context) => AppLocalizations.of(context).calendarExport,
              subtitle: (context) async => 'PDF, iCal, ICS, CSV',
              icon: Icons.download_rounded,
              routePath: SettingsDeepLinks.calendarExport,
              screen: (context) async =>
                  context.push(SettingsDeepLinks.calendarExport),
            ),
          SettingsTile(
            title: (context) => AppLocalizations.of(context).notifications,
            subtitle: (context) async =>
                AppLocalizations.of(context).intervalAppletsList,
            icon: Icons.notifications_rounded,
            routePath: SettingsDeepLinks.notifications,
            screen: (context) async {
              if (context.mounted) {
                context.push(SettingsDeepLinks.notifications);
              }
            },
          ),
        ],
      ),
      SettingsGroup(
        title: 'Geräte & Sicherheit',
        tiles: [
          SettingsTile(
            icon: Icons.watch_rounded,
            show: () async => !WearMode.enabled,
            title: (context) => 'Sync mit Uhren',
            subtitle: (context) async =>
                'Wear OS und Garmin: Login, Stundenplan, Vertretungen',
            screen: (context) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SyncSettingsPage(),
                ),
              );
            },
          ),
          SettingsTile(
            icon: Icons.fingerprint_rounded,
            show: () async => !WearMode.enabled,
            title: (context) => 'App-Sperre',
            subtitle: (context) async => _onOff(
              appLockKey,
              'An – Fingerabdruck oder Geräte-PIN beim Öffnen',
              'Aus – tippen zum Einschalten',
              defaultOn: false,
            ),
            screen: (context) async {
              final container = ProviderScope.containerOf(context);
              final settings = container.read(sharedOverAccountSettingsProvider);
              final messenger = ScaffoldMessenger.of(context);
              final on = settings.getString(appLockKey) == '1';
              final ok = await authenticateDevice(
                on ? 'App-Sperre ausschalten' : 'App-Sperre einschalten',
              );
              if (!ok) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Nicht bestätigt (oder keine Display-Sperre am Gerät eingerichtet).',
                    ),
                  ),
                );
                return;
              }
              settings.setString(appLockKey, on ? '0' : '1');
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    on ? 'App-Sperre ausgeschaltet' : 'App-Sperre eingeschaltet',
                  ),
                ),
              );
            },
          ),
          SettingsTile(
            title: (context) => AppLocalizations.of(context).userData,
            subtitle: (context) async =>
                AppLocalizations.of(context).ageNameClassList,
            icon: Icons.account_circle_rounded,
            routePath: SettingsDeepLinks.userdata,
            screen: (context) async =>
                context.push(SettingsDeepLinks.userdata),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Speicher & App',
        tiles: [
          SettingsTile(
            title: (context) => AppLocalizations.of(context).clearCache,
            subtitle: (context) async {
              Map<String, int> cacheStats = {'fileNum': 0, 'size': 0};

              final storage = ref.read(storageManagerProvider);
              if (storage != null) {
                final dir = storage.getDocumentCacheDirectory();
                cacheStats = CacheSettings.dirStatSync(dir.path);
              }

              return "${cacheStats['fileNum']} ${cacheStats['fileNum'] == 1 ? (context.mounted ? AppLocalizations.of(context).file : 'Datei') : (context.mounted ? AppLocalizations.of(context).files : 'Dateien')} (${cacheStats['size']! ~/ 1024} KB)";
            },
            icon: Icons.storage_rounded,
            routePath: SettingsDeepLinks.cache,
            screen: (context) async => context.push(SettingsDeepLinks.cache),
          ),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            show: () async => true,
            title: (context) => 'Version',
            subtitle: (context) async => 'Build, Updates, Über diese App',
            screen: (context) async => showLocalUpdateInfo(context),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(supportedAppletPhpUrlsProvider);
    final settingsTiles = _buildSettingsTiles();
    final isTablet =
        Responsive.isSplitView(context) || widget.embeddedInTabletShell;
    final currentPath = GoRouterState.of(context).uri.path;

    final double availableHeight =
        MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top;

    Widget settingsList = SizedBox(
      height: availableHeight,
      child: ListView.builder(
        itemCount: settingsTiles.length,
        itemBuilder: (context, groupIndex) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settingsTiles[groupIndex].title != null)
                  SettingsSectionHeader(
                    settingsTiles[groupIndex].title!,
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  ),
                ...List.generate(settingsTiles[groupIndex].tiles.length, (
                tileIndex,
              ) {
                final tile = settingsTiles[groupIndex].tiles[tileIndex];
                final selected =
                    isTablet &&
                    tile.routePath != null &&
                    currentPath == tile.routePath;
                return SettingsTileWidget(
                  tile: tile,
                  index: tileIndex,
                  length: settingsTiles[groupIndex].tiles.length,
                  foregroundColor: foregroundColor,
                  selected: selected,
                  onSelect: isTablet
                      ? (tile) {
                          if (tile.routePath == null) {
                            return tile.screen(context);
                          }
                          context.go(tile.routePath!);
                        }
                      : null,
                );
              }),
              ],
            ),
          );
        },
      ),
    );

    if (widget.embeddedInTabletShell) {
      return ColoredBox(
        color: backgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(AppLocalizations.of(context).settings),
              backgroundColor: backgroundColor,
              automaticallyImplyLeading: false,
            ),
            Expanded(child: settingsList),
          ],
        ),
      );
    }

    if (!isTablet) {
      final canPop = Navigator.of(context).canPop();
      if (!canPop) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            title: Text(AppLocalizations.of(context).settings),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/dashboard'),
            ),
          ),
          body: settingsList,
        );
      }
      return SettingsPage(
        backgroundColor: backgroundColor,
        title: Text(AppLocalizations.of(context).settings),
        showBackButton: true,
        children: [settingsList],
      );
    }

    // Phone-sized but somehow tablet flag: list only (detail via routes).
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        backgroundColor: backgroundColor,
        automaticallyImplyLeading: false,
      ),
      body: settingsList,
    );
  }
}

class SettingsTileWidget extends StatefulWidget {
  final SettingsTile tile;
  final int index;
  final int length;
  final Color foregroundColor;
  final bool disableSetState;
  final bool selected;
  final Function(SettingsTile)? onSelect;
  final bool preventNavigation;

  const SettingsTileWidget({
    super.key,
    required this.tile,
    required this.foregroundColor,
    required this.index,
    required this.length,
    this.disableSetState = false,
    this.selected = false,
    this.onSelect,
    this.preventNavigation = false,
  });

  static BorderRadius getRadius(int index, int length) {
    if (index == 0 && length > 1) {
      return BorderRadius.only(
        topLeft: Radius.circular(12.0),
        topRight: Radius.circular(12.0),
      );
    } else if (index == 0) {
      return BorderRadius.circular(12.0);
    } else if (index == length - 1) {
      return BorderRadius.only(
        bottomLeft: Radius.circular(12.0),
        bottomRight: Radius.circular(12.0),
      );
    } else {
      return BorderRadius.zero;
    }
  }

  @override
  State<SettingsTileWidget> createState() => _SettingsTileWidgetState();
}

class _SettingsTileWidgetState extends State<SettingsTileWidget> {
  String subtitle = "";

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([widget.tile.show(), widget.tile.subtitle(context)]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildTile(subtitle);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildTile(AppLocalizations.of(context).error);
        }

        subtitle = snapshot.data![1] as String;

        return Visibility(
          visible: snapshot.data![0] as bool,
          child: _buildTile(subtitle),
        );
      },
    );
  }

  Widget _buildTile(String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: PressTile(
        title: widget.tile.title(context),
        subtitle: subtitle,
        icon: widget.tile.icon,
        selected: widget.selected,
        onPressed: () async {
          if (widget.onSelect != null) {
            widget.onSelect!(widget.tile);
          } else {
            await widget.tile.screen(context);
          }
          // Untertitel (z. B. An/Aus) nach der Änderung neu lesen.
          if (mounted) setState(() {});
        },
        foregroundColor: widget.foregroundColor,
        borderRadius: SettingsTileWidget.getRadius(widget.index, widget.length),
      ),
    );
  }
}
