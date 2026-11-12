import 'package:lanis/utils/updater.dart';

/// Versionsnummer aus der Build-Nummer: Zehner = Minor, Einer = Patch.
/// Build 30 = 0.1.0, 31 = 0.1.1, 40 = 0.2.0, 41 = 0.2.1 …
String versionName() {
  final n = int.tryParse(currentBuildId) ?? 0;
  if (n < 30) return '0.0.$n';
  return '0.${n ~/ 10 - 2}.${n % 10}';
}

/// "v0.1.2 · Build 32" (davor nur "Build N").
String versionLabel() {
  final n = int.tryParse(currentBuildId) ?? 0;
  if (n >= 30) return 'v${versionName()} · Build $n';
  return n > 0 ? 'Build $n' : 'Entwicklerversion';
}
