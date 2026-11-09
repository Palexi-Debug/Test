import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Erkennt, ob die App auf einer Wear-OS-Uhr läuft (experimentell).
///
/// Auf der Uhr startet die App mit einer sehr einfachen Ansicht, die nur den
/// Vertretungsplan zeigt.
class WearMode {
  static bool enabled = false;

  static Future<void> detect() async {
    try {
      if (!Platform.isAndroid) return;
      final info = await DeviceInfoPlugin().androidInfo;
      enabled = info.systemFeatures.contains('android.hardware.type.watch');
    } catch (_) {
      enabled = false;
    }
  }
}
