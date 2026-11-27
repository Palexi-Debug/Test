# Schulportal – Philipp-Reis-Schule

Eigene App-Oberfläche für das Schulportal Hessen (Schule 6110): Handy (Android), Wear OS,
Garmin Venu Sq 2 sowie Test-/Eigenbauten für Windows, macOS und iOS/iPadOS.

## Basiert auf Lanis Mobile

Die Anbindung an das Schulportal stammt vom freien Projekt
[Lanis Mobile](https://github.com/lanis-mobile/lanis) (GPLv3). Dieses Projekt
steht deshalb ebenfalls unter der GPLv3, der Quellcode liegt in diesem Repository.
Danke an alle Mitwirkenden von Lanis Mobile!

## Branches und Update-Kanäle

Gebaut wird ausschließlich per GitHub Actions. Jede Plattform hat einen eigenen Release-Kanal
(Tag `<plattform>-<Nr>`, Nr = Anzahl Commits des Branches):

| Branch | Inhalt | Release-Tag |
| --- | --- | --- |
| `main` | Android-App (Flutter) + Wear OS (`-arm64`/`-arm32`) | `build-N` |
| `garmin` | Garmin Connect IQ (Monkey C) | `garmin-N` |
| `windows`, `macos` | Flutter-Desktop-Builds (Vorabversion, zip) | `windows-N`, `macos-N` |
| `ios` | native SwiftUI-App für iPhone + iPad (`ios-swift/`, unsigniert) | `ios-N` |
| `webview` | alte WebView-Version (nicht mehr gepflegt) | – |

Die Apps suchen unter Einstellungen → Version nach Updates im jeweils eigenen Kanal.
Übergabe-Notizen: `HANDOFF.md`.
