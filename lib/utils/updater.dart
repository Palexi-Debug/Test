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
  const UpdateInfo(this.build, this.notes, this.apkUrl);
}

enum UpdateCheckResult { newer, upToDate, failed }

class UpdateCheck {
  final UpdateCheckResult result;
  final UpdateInfo? info;
  const UpdateCheck(this.result, [this.info]);
}

/// Fragt das neueste Release ab. Funktioniert nur, wenn das Repo öffentlich
/// ist (oder die Releases sonst ohne Anmeldung erreichbar sind).
Future<UpdateCheck> checkForUpdate() async {
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
    for (final a in assets) {
      final name = (a['name'] ?? '').toString();
      if (name.endsWith('.apk')) {
        apk = a['browser_download_url']?.toString();
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
        UpdateInfo(build, (data['body'] ?? '').toString(), apk),
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
    await Dio().download(
      info.apkUrl,
      file.path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );
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
