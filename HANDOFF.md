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

## Stand 2026-11-28
- Untere Leiste: Beschriftungen haben seitlichen Abstand und kleinere Schrift (`labelSmall`), damit "Stundenplan"/"Vertretungen" nicht mehr quetschen.
- Aussehen-Einstellungen werden sofort gespeichert (kein "Übernehmen" mehr); Theme-Neuaufbau gebündelt (300 ms). Behebt: Animationen-Auswahl blieb nicht bestehen.
- `lib/core/school_schedule.dart`: gemeinsame Unterrichtszeiten (Dashboard, Wear, Garmin-Sync `idx`).
- Garmin-Sync: Bluetooth-Berechtigungen (Android 12+) im Manifest, `<queries>` für Garmin Connect, Laufzeit-Abfrage von `bluetoothConnect`, deutsche Fehlermeldungen, `idx` im Payload (Garmin-App 0.1.5 scrollt dorthin).
- Updater: fragt `/releases` ab und filtert strikt auf `build-` (Handy und Uhr, Uhr mit arm64/arm32-ABI), Desktop auf `windows-`/`macos-` (öffnet die Release-Seite im Browser). `kIsPlayStore` (`--dart-define=PLAY_STORE=true`) schaltet Update-Suche, Download und die Update-Karte in `version_page.dart` ab. Kein eigenes Play-Store-Manifest (`REQUEST_INSTALL_PACKAGES` bleibt im normalen Manifest).
- Wear-Akku: Applet-Prüfungen im Hintergrund laufen mit `Future.wait` parallel (Fehler einzelner Applets stoppen die anderen nicht); `RepaintBoundary` um Logo und Ringe.
- Namespace und Kotlin-Package: `de.palexi.schulportal` (applicationId war schon so).
- Links auf `Palexi-Debug/Test` (Issues/Releases), Fehlerberichte als GitHub-Issue statt Mail an Upstream; Hinweis "inoffizieller Client" in "Über" und "Version".
- Build-Status: Push 7820334, CI-Ergebnis siehe GitHub Actions (Build APK + Wear OS APK).

## Stand 2026-11-28 (neue Funktionen)
- **Änderungsliste beim Update:** `updater.dart` sammelt die Release-Notizen aller `build-N`-Releases, die neuer sind als der installierte Build (max. 25), und zeigt sie im Update-Dialog.
- **Wochenübersicht + Bild teilen:** `lib/applets/timetable/student/week_preview.dart`, geöffnet über das Wochen-Symbol in der Stundenplan-Leiste. Raster Mo–Fr (Sa/So nur mit Stunden) mit eingesetzten Vertretungen und ausgegrauten Ausfällen; Teilen-Symbol rendert das Raster per `RepaintBoundary` als PNG (3-fach) und teilt es (`share_plus`).
- **Termin-/Klausur-Erinnerung:** `lib/applets/calendar/background.dart` (Hintergrund-Task, an `calendarDefinition.notificationTask` gehängt, deshalb erscheint "Kalender" unter Einstellungen > Benachrichtigungen). Erinnert am Vortag ab 16 Uhr ("Morgen: …") und am Tag ab 6 Uhr ("Heute: …"). Standard nur Titel mit Klausur/Arbeit/Test/Prüfung/…; Schalter "Kalender: auch normale Termine erinnern" (`calendar-remind-all`) schaltet alle ein. Läuft mit dem normalen Hintergrund-Takt, keine exakten Alarme.
- **Homescreen-Widget (Android):** `ScheduleWidgetProvider.kt` + `res/layout/schedule_widget.xml`, `res/xml/schedule_widget_info.xml`, Receiver im Manifest. Die App schickt den Wochenplan als JSON über den Kanal `de.palexi.schulportal/widget` (`lib/utils/schedule_widget.dart`, aufgerufen aus der Stundenplan-Ansicht), das Widget rechnet die laufende/nächste Stunde selbst aus (Aktualisierung alle 30 Min. und bei jedem Öffnen des Stundenplans). Klick öffnet die App. Hinweis: Plan kommt nur, wenn der Stundenplan (aktuelle Woche) geöffnet wurde.
- **Nicht umgesetzt:** Garmin-Freunde-Sync / eigene Stunden auf der Uhr (braucht neue Nachrichtenstruktur + neue .prg).
- Build-Status: nach dem Push in GitHub Actions prüfen.
