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

## Stand 2026-11-28 (später): Basis-Funktionen
- Tabs: Heute, Stundenplan, Vertretungen, Nachrichten, Termine; Einstellungen per Zahnrad auf "Heute" (Sheet).
- Heute: laufende/nächste Stunde mit Fortschritt, heutige Stunden, Vertretungen heute, nächste Termine.
- Termine: Port von `CalendarParser` (kalender.php, Kategorien per Regex, getEvents-JSON), Zeitraum -14 bis +200 Tage.
- Nachrichten (nur lesen): `Crypto.swift` portiert den RSA-Handshake (Public Key -> PKCS#1, `SecKeyCreateEncryptedData`) und AES im
  "Salted__"-Format (MD5-Schlüsselableitung, CommonCrypto). `Extras.swift`: Liste (`a=headers`) und Unterhaltung (`a=read`).
  Der Sitzungsschlüssel gilt pro Login (`PortalClient.cryptoKey`).
- App-Sperre (`AppLock.swift`): Face ID / Touch ID / Gerätecode, sperrt nach 30 s im Hintergrund; Schalter in den Einstellungen.
- Alles ungetestet auf Geräten. Wenn "Nachrichten" einen Fehler zeigt: Text nennt die Stufe (Schlüssel, RSA, Handshake, Nachrichten).

## Noch offen
- Nachrichten schreiben/antworten, Unterricht, Dateispeicher, Lerngruppen, Widgets, Benachrichtigungen im Hintergrund.
- Aussehen-Einstellungen wie auf Android (Farben, Kachel-Layout) fehlen.
- Alles ungetestet auf Geräten; es gibt keinen lokalen Swift-Compiler (CI ist der Compiler).
