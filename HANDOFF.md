# Schulportal-App (Philipp-Reis-Schule, ID 6110) – Übergabe

Repo `Palexi-Debug/Test`. Gebaut wird NUR per GitHub Actions (kein Flutter lokal; "Analyze" ca. 2 Min, APK ca. 10 Min).
Branches/Kanäle: siehe README. Ungetestet auf Geräten, sofern nicht anders vermerkt.

## Architektur (main)
- Flutter (Riverpod, go_router), Portal-Anbindung im vendored Paket `packages/liblanis` (Basis Lanis Mobile, eigene Anpassungen).
- Auth: `lib/features/auth/auth_controller.dart` (Offline-Start mit Cache, Retry alle 20 s; Kontoprobleme wie Passwortwechsel/Sperre → Fehlerseite mit deutscher Meldung, `lib/utils/login_errors.dart`).
- Session (`liblanis/session/session.dart`): aus Upstream 0.3.6 übernommen (503 = Portal down, Re-Login ohne Doppelanmeldung, robuste Menü-/Benutzerdaten), Timeouts bewusst 15 s/30 s.
- Stundenplan-Modell: Mo–Fr bleiben auch ohne Stunden erhalten (Index = Wochentag, `weekdayIndices`).
- Uhr-Sync: `lib/utils/watch_sync.dart` (Wear OS), `garmin_sync.dart` (Garmin, Payload mit Vertretungen + Woche `wk`).

## UI-Struktur
- Startseite: `lib/view/dashboard/` – Raster-Modell in `dashboard_layout.dart` (Größe je Kachel Breite×Höhe, gespeichert in `dashboard-tile-spans`; altes `dashboard-tile-sizes` wird migriert). Zieh-Stück liegt über den Kacheln (`_ResizeHandle`, Eager-Gesten, kein Scrollen beim Ziehen), grüne Umrandung der Kachel nur, solange der Zieh-Pfeil gedrückt ist, Layout-Menü per "Layout"-Knopf.
- Einstellungen: `lib/view/settings/settings.dart`, Gruppen Darstellung / Bereiche / Geräte & Sicherheit / Speicher & App. Eigene Seite Vertretungsplan: `applets/substitutions/substitutions_settings.dart` (Vertretungen im Stundenplan, Ausfall grau, Filter).
- Gemeinsame Bausteine: `lib/widgets/settings_widgets.dart` (Abschnittstitel, Schalter, Auswahlleiste).
- Aussehen: Navigationsleiste wird direkt in der Vorschau per Halten+Ziehen sortiert (`AnimatedBottomBar.onReorder`). Einstellung "Animationen" (Aus/Dezent/Lebendig) steuert Übergänge, Leiste und Logo (`AppLook`).
- Wear OS (`lib/view/wear/`): Seiten Jetzt/Heute/Vertretungen/Update, Einstellungen (Text, Scroll-Tempo, Animationen + Tempo, Startseite, Vertretungen im Plan), Cache vom Handy, ABI-getrennte Updates.

## Andere Plattformen
- Windows/macOS: Branches `windows`/`macos`, Flutter-Test-Apps, Release `windows-N`/`macos-N` (zip, Vorabversion). Updater öffnet die Release-Seite.
- iOS: Branch `ios`, native SwiftUI (`ios-swift/`, XcodeGen + SwiftSoup, Login/Stundenplan/Vertretungen/Update-Prüfung), unsigniertes IPA (AltStore/Sideloadly), Tag `ios-N`.
- Garmin: Branch `garmin`, eigene Doku `garmin/HANDOFF.md`.

## Offen
- Homescreen-Widget, Klausur-/Termin-Erinnerung, Wochenvorschau, Stundenplan als Bild teilen, Änderungsliste beim Update.
- Garmin: eigene Stunden, Freund-Sync (braucht neue .prg).
- iOS: Nachrichten, Kalender u. a. noch nicht portiert; App-Sperre/Widgets fehlen.
- Test auf Geräten: Kachel-Ziehen (Breite+Höhe), Leiste verschieben, Uhr-Animationen, schlechtes Netz, Nachrichten (äöüß/#), G/U am Wochenende.
