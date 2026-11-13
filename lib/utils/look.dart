import 'package:flutter/material.dart';

/// Globale Optik-Einstellungen (werden in main.dart bei jeder Änderung gesetzt).
class AppLook {
  /// 0 = aus, 1 = dezent, 2 = lebendig
  static int anim = 1;

  /// Farbintensität der Stundenplan-Kacheln (0.3 – 1.0)
  static double ttIntensity = 1.0;

  /// Ausgefallene Stunden im Stundenplan grau darstellen
  static bool greyCancelled = true;

  static Duration dur(int ms) {
    if (anim == 0) return Duration.zero;
    return Duration(milliseconds: anim == 2 ? (ms * 1.4).round() : ms);
  }

  static Color? parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final v = int.tryParse(hex, radix: 16);
    return v == null ? null : Color(v);
  }

  static String toHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
}
