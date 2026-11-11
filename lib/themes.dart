import 'package:flutter/material.dart';

enum AmoledColor { background, secondary, third }

// Only a collection of themes
// Used for ColorModeNotifier to set the app theme dynamically
/// Ruhiger Seitenwechsel: nur kurzes Überblenden, keine Bewegung
/// (vermeidet Übelkeit und graue Flächen bei schnellem Wechseln).
class SoftFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftFadePageTransitionsBuilder();

  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

class Themes {
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;

  Themes(this.lightTheme, this.darkTheme);

  static Themes getNewTheme(Color seedColor) {
    // The basic theme, global theme data changes should be put here.
    ThemeData basicTheme(Brightness brightness) {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      );
      final roundedShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SoftFadePageTransitionsBuilder(),
          },
        ),
        // Eigenes Aussehen: weiche, runde Karten ohne Schatten
        cardTheme: CardThemeData(
          elevation: 0,
          shape: roundedShape,
          color: colorScheme.surfaceContainerHigh,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        // Eingabefelder (Login) gefüllt und abgerundet
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            minimumSize: const Size(64, 48),
          ),
        ),
        listTileTheme: ListTileThemeData(shape: roundedShape),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        drawerTheme: DrawerThemeData(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    return Themes(basicTheme(Brightness.light), basicTheme(Brightness.dark));
  }

  static final Map<String, Themes> flutterColorThemes = {
    "pink": getNewTheme(Colors.pink),
    "red": getNewTheme(Colors.red),
    "orange": getNewTheme(Colors.orange),
    "yellow": getNewTheme(Colors.yellow),
    "lime": getNewTheme(Colors.lime),
    "light_green": getNewTheme(Colors.lightGreen),
    "green": getNewTheme(Colors.green),
    "teal": getNewTheme(Colors.teal),
    "cyan": getNewTheme(Colors.cyan),
    "blue": getNewTheme(Colors.blue),
    "indigo": getNewTheme(Colors.indigo),
    "purple": getNewTheme(Colors.purple),
  };

  // Will be later set by DynamicColorBuilder in main.dart App().
  static Themes dynamicTheme = Themes(null, null);

  // Will be set by ColorModeNotifier.init() or _getSchoolTheme() in client.dart.
  static Themes schoolTheme = Themes(null, null);

  static Themes standardTheme = getNewTheme(Colors.indigo);

  static Themes getAmoledThemes(Themes themes) {
    // Colors for Amoled Mode
    final Map<AmoledColor, Color> amoledColors = {
      AmoledColor.background: Colors.black,
      AmoledColor.secondary: const Color(0xFF0f0f0f),
      AmoledColor.third: const Color(0xFF0a0a0a),
    };

    return Themes(
      themes.lightTheme,
      themes.darkTheme?.copyWith(
        // Amoled Background & Themes for required Components
        scaffoldBackgroundColor: amoledColors[AmoledColor.background],
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: amoledColors[AmoledColor.background],
        ),
        navigationDrawerTheme: NavigationDrawerThemeData(
          backgroundColor: amoledColors[AmoledColor.background],
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: amoledColors[AmoledColor.background],
          surfaceTintColor: amoledColors[AmoledColor.background],
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: amoledColors[AmoledColor.secondary],
          surfaceTintColor: amoledColors[AmoledColor.secondary],
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: amoledColors[AmoledColor.third],
          surfaceTintColor: amoledColors[AmoledColor.third],
        ),
        colorScheme: themes.darkTheme?.colorScheme.copyWith(
          surfaceContainer: amoledColors[AmoledColor.background],
          surfaceContainerHighest: themes.darkTheme?.cardColor,
          surfaceContainerHigh: amoledColors[AmoledColor.third],
          surfaceContainerLow: amoledColors[AmoledColor.secondary],
          surfaceContainerLowest: amoledColors[AmoledColor.third],
        ),
      ),
    );
  }
}
