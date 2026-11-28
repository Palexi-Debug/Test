# Übergabe – Branch `ios`

Dieser Branch enthält nur die native iOS-App (`ios-swift/`), den Workflow `.github/workflows/ios.yml`,
`LICENSE`, `README.md` und diese Datei. Die Flutter-Ordner (lib, android, packages, assets, fonts) wurden
am 2026-11-28 entfernt; sie liegen weiter auf `main`.

## Stand 2026-11-28
- Tabs: Stundenplan, Vertretungen, Einstellungen (Login per Schulportal-Protokoll, Parser aus der Dart-App portiert).
- Design: "Liquid Glass". `GlassCard` nutzt `glassEffect` mit dem iOS-26-SDK (`#if compiler(>=6.2)` + `#available`),
  sonst `.ultraThinMaterial` mit Lichtkante und Schatten. Pulsierendes `NowBadge` für die laufende Stunde,
  rote Karten für Entfall, blaue für Raumwechsel, orange für sonstige Änderungen.
- Workflow wählt das neueste (Nicht-Beta-)Xcode des Runners; Deployment-Ziel bleibt iOS 16.
- Updater (`Updater.swift`): fragt `/releases` ab, nimmt das neueste Release mit Tag `ios-N` und `.ipa`-Asset.
- Build-Status: nach dem Push in GitHub Actions prüfen (Workflow "iOS App (SwiftUI)").

## Noch offen
- Tabs "Heute" und "Termine" gibt es noch nicht (Kalender-Parser ist auf iOS nicht portiert).
- Nachrichten, Unterricht, Dateispeicher, App-Sperre, Widgets fehlen.
- Alles ungetestet auf Geräten; es gibt keinen lokalen Swift-Compiler (CI ist der Compiler).
