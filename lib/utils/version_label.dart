import 'package:lanis/utils/updater.dart';

/// Ab Build 30: "v0.1.0 · Build N", davor nur "Build N".
String versionLabel() {
  final n = int.tryParse(currentBuildId) ?? 0;
  if (n >= 30) return 'v0.1.0 · Build $n';
  return n > 0 ? 'Build $n' : 'Entwicklerversion';
}
