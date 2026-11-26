import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lanis/utils/logger.dart';

/// Repo, in dem die Builds als GitHub-Releases veröffentlicht werden.
const updateRepo = 'Palexi-Debug/Test';

/// Build-Nummer dieser App (kommt aus dem CI-Lauf, lokal "dev").
const currentBuildId = String.fromEnvironment('BUILD_ID', defaultValue: '0');

class UpdateInfo {
  final int build;
  final String notes;
  final String apkUrl;
  final int size;
  const UpdateInfo(this.build, this.notes, this.apkUrl, [this.size = 0]);
}

enum UpdateCheckResult { newer, upToDate, failed }

class UpdateCheck {
  final UpdateCheckResult result;
  final UpdateInfo? info;
  const UpdateCheck(this.result, [this.info]);
}

/// Eigener Update-Kanal je Plattform. Android/Uhr nutzen weiter die Releases
/// "build-N" (neuestes Release), Desktop hat eigene Tags (windows-N, macos-N).
String? _desktopChannel() {
  if (kIsWeb) return null;
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  return null;
}

/// Fragt das neueste Release ab. Funktioniert nur, wenn das Repo öffentlich
/// ist (oder die Releases sonst ohne Anmeldung erreichbar sind).
Future<UpdateCheck> checkForUpdate({bool wear = false}) async {
  try {
    final channel = wear ? null : _desktopChannel();
    final response = await Dio().get(
      channel == null
          ? 'https://api.github.com/repos/$updateRepo/releases/latest'
          : 'https://api.github.com/repos/$updateRepo/releases?per_page=30',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    var data = response.data;
    if (channel != null && data is List) {
      data = data.firstWhere(
        (r) =>
            r is Map &&
            r['draft'] != true &&
            (r['tag_name'] ?? '').toString().startsWith('$channel-'),
        orElse: () => null,
      );
    }
    if (data is! Map) return const UpdateCheck(UpdateCheckResult.failed);
    final tag = (data['tag_name'] ?? '').toString();
    final build = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), ''));
    final assets = (data['assets'] as List?) ?? const [];
    String? apk;
    int apkSize = 0;
    // Uhr: passende 64-Bit- oder 32-Bit-Datei für dieses Gerät wählen.
    var want = '';
    if (wear) {
      try {
        final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
        want = abis.contains('arm64-v8a') ? 'arm64' : 'arm32';
      } catch (_) {}
    }
    for (final pass in [true, false]) {
      for (final a in assets) {
        final name = (a['name'] ?? '').toString();
        final isWear = name.toLowerCase().contains('wear');
        if (!name.endsWith(channel == null ? '.apk' : '.zip') || isWear != wear) {
          continue;
        }
        // 1. Durchlauf: genau passende ABI; 2. Durchlauf: irgendeine Datei.
        if (pass && wear && want.isNotEmpty && !name.contains(want)) continue;
        apk = a['browser_download_url']?.toString();
        apkSize = (a['size'] as num?)?.toInt() ?? 0;
        break;
      }
      if (apk != null) break;
    }
    if (build == null || apk == null) {
      return const UpdateCheck(UpdateCheckResult.failed);
    }
    final mine = int.tryParse(currentBuildId) ?? 0;
    if (build > mine) {
      return UpdateCheck(
        UpdateCheckResult.newer,
        UpdateInfo(build, (data['body'] ?? '').toString(), apk, apkSize),
      );
    }
    return const UpdateCheck(UpdateCheckResult.upToDate);
  } catch (_) {
    return const UpdateCheck(UpdateCheckResult.failed);
  }
}

final Map<int, Future<File?>> _downloadJobs = {};
final Map<int, ValueNotifier<double>> _downloadProgress = {};

/// Fortschritt (0–1) des Downloads für ein Build.
ValueNotifier<double> updateProgressOf(int build) =>
    _downloadProgress.putIfAbsent(build, () => ValueNotifier<double>(0));

Future<File> _apkFile(UpdateInfo info) async {
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/schulportal-update-${info.build}.apk');
}

/// Ist die APK schon vollständig heruntergeladen?
Future<bool> isUpdateDownloaded(UpdateInfo info) async {
  try {
    final f = await _apkFile(info);
    if (!await f.exists()) return false;
    final len = await f.length();
    return info.size <= 0 ? len > 0 : len == info.size;
  } catch (_) {
    return false;
  }
}

/// Startet den Download im Hintergrund (oder hängt sich an einen laufenden
/// an). Eine fertige Datei wird wiederverwendet. Gibt null bei Fehlschlag.
Future<File?> prefetchUpdate(UpdateInfo info) {
  if (_desktopChannel() != null) return Future<File?>.value(null);
  return _downloadJobs.putIfAbsent(info.build, () async {
    logger.i('Update: Download Build ${info.build} gestartet');
    final file = await _downloadApk(info);
    logger.i(
      file == null
          ? 'Update: Download Build ${info.build} fehlgeschlagen'
          : 'Update: Build ${info.build} heruntergeladen',
    );
    if (file == null) _downloadJobs.remove(info.build);
    return file;
  });
}

Future<File?> _downloadApk(UpdateInfo info) async {
  final progress = updateProgressOf(info.build);
  try {
    final file = await _apkFile(info);
    if (await isUpdateDownloaded(info)) {
      progress.value = 1;
      return file;
    }
    // Alte Update-Dateien anderer Builds aufräumen.
    try {
      await for (final e in file.parent.list()) {
        final name = e.path.split('/').last;
        if (e is File &&
            name.startsWith('schulportal-update-') &&
            e.path != file.path) {
          await e.delete();
        }
      }
    } catch (_) {}
    // In eine .part-Datei laden, damit nie eine halbe APK als fertig gilt.
    final part = File('${file.path}.part');
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await part.exists()) await part.delete();
        progress.value = 0;
        await Dio().download(
          info.apkUrl,
          part.path,
          onReceiveProgress: (received, total) {
            if (total > 0) progress.value = received / total;
          },
        );
        final len = await part.length();
        final ok = info.size <= 0 ? len > 0 : len == info.size;
        if (ok) {
          if (await file.exists()) await file.delete();
          await part.rename(file.path);
          progress.value = 1;
          return file;
        }
      } catch (_) {}
    }
    try {
      if (await part.exists()) await part.delete();
    } catch (_) {}
    return null;
  } catch (_) {
    return null;
  }
}

/// Installiert das Update. Ist der Download schon (im Hintergrund) fertig,
/// startet der Installer sofort. Gibt eine Fehlermeldung zurück oder null.
Future<String?> downloadAndInstall(
  UpdateInfo info,
  void Function(double progress) onProgress,
) async {
  if (_desktopChannel() != null) {
    // Desktop: Download im Browser starten, Installation von Hand.
    final ok = await launchUrl(
      Uri.parse(info.apkUrl),
      mode: LaunchMode.externalApplication,
    );
    return ok ? null : 'Download-Seite konnte nicht geöffnet werden.';
  }
  final notifier = updateProgressOf(info.build);
  void listener() => onProgress(notifier.value);
  notifier.addListener(listener);
  try {
    onProgress(notifier.value);
    var file = await prefetchUpdate(info);
    // Wurde die Datei inzwischen vom System gelöscht, neu laden.
    if (file != null && !await file.exists()) {
      _downloadJobs.remove(info.build);
      file = await prefetchUpdate(info);
    }
    if (file == null) {
      return 'Download unvollständig. Bitte mit stabiler Verbindung erneut versuchen.';
    }
    final result = await OpenFile.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      return 'Installation konnte nicht gestartet werden: ${result.message}';
    }
    return null;
  } catch (e) {
    return 'Download fehlgeschlagen. Bist du online?';
  } finally {
    notifier.removeListener(listener);
  }
}
