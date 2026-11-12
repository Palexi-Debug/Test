import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

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

/// Fragt das neueste Release ab. Funktioniert nur, wenn das Repo öffentlich
/// ist (oder die Releases sonst ohne Anmeldung erreichbar sind).
Future<UpdateCheck> checkForUpdate({bool wear = false}) async {
  try {
    final response = await Dio().get(
      'https://api.github.com/repos/$updateRepo/releases/latest',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    final data = response.data;
    if (data is! Map) return const UpdateCheck(UpdateCheckResult.failed);
    final tag = (data['tag_name'] ?? '').toString();
    final build = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), ''));
    final assets = (data['assets'] as List?) ?? const [];
    String? apk;
    int apkSize = 0;
    for (final a in assets) {
      final name = (a['name'] ?? '').toString();
      final isWear = name.toLowerCase().contains('wear');
      if (name.endsWith('.apk') && isWear == wear) {
        apk = a['browser_download_url']?.toString();
        apkSize = (a['size'] as num?)?.toInt() ?? 0;
        break;
      }
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

/// Lädt die APK herunter und startet den Android-Installer.
/// Gibt eine Fehlermeldung zurück oder null bei Erfolg.
Future<String?> downloadAndInstall(
  UpdateInfo info,
  void Function(double progress) onProgress,
) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/schulportal-update-${info.build}.apk');
    // Bis zu 3 Versuche; unvollständige Dateien werden verworfen.
    var complete = false;
    for (var attempt = 0; attempt < 3 && !complete; attempt++) {
      try {
        if (await file.exists()) await file.delete();
        await Dio().download(
          info.apkUrl,
          file.path,
          onReceiveProgress: (received, total) {
            if (total > 0) onProgress(received / total);
          },
        );
        final len = await file.length();
        complete = info.size <= 0 ? len > 0 : len == info.size;
      } catch (_) {
        complete = false;
      }
    }
    if (!complete) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
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
  }
}
