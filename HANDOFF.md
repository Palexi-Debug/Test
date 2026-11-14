# Schulportal-App (Philipp-Reis-Schule, ID 6110) - Uebergabe

Repo `Palexi-Debug/Test`: `main` = native Flutter-App, `webview` = alte App, `garmin` = Garmin-Venu-Sq-2-App (eigene Doku: `garmin/HANDOFF.md` auf dem Branch).
Gebaut wird NUR per GitHub Actions (kein Flutter lokal): "Analyze" ca. 1-2 Min, APK ca. 10 Min. Releases `build-N` mit Handy- und Wear-APK.
Aktuell: Build 43 (v0.3.3). Versionsschema: Build 30 = 0.1.0, 40 = 0.2.0 (Zehner = Minor).

## Fertig (alle Builds gruen, nur teils auf Geraeten getestet)
- Eigenes Aussehen: Akzent, Radius, Dichte, Animationen, Kartenstil, Leiste sortierbar, Vorschau + Uebernehmen/Verwerfen.
- Logo (Buch) in App, Splash, Uhr. Stundenplan: Farbintensitaet, Plus-Button fuer eigene Stunde.
- Eigene Stunde: Tag waehlbar, Tastatur verdeckt Eingabe nicht mehr (Build 41/42, ungetestet).
- Ausfall grau: Stunden mit "Entfall/Ausfall" im Vertretungsplan werden grau + durchgestrichen (Einstellungen > Aussehen > Stundenplan, abschaltbar). Zuordnung ueber Datum, Stundennummer, Fach (`applets/timetable/student/cancelled.dart`). Ungetestet.
- Nachrichten: Text beim Neu-Erstellen, Umlaute (HTML-Entities), Lerngruppen-Parser null-sicher (vendored `packages/liblanis`).
- Wear OS: Seiten Jetzt/Heute/Vertretungen/Update, Login vom Handy (`utils/watch_sync.dart`), Secret, Ladeanimation.
  Neu: eigene + ausgeblendete Stunden + Farben werden vom Handy zur Uhr synchronisiert (`syncTimetableToWatch`, `applyTimetableFromPhone`). Ungetestet.
- Updater: Groessenpruefung + 3 Versuche. Uhr-APK arm+arm64 (~41 MB; Galaxy Watch 5 braucht 32 Bit). Update langsam -> WLAN an der Uhr.
- Signatur-Key fest (sha256 6d7973c4...c675).

## Offen / ungetestet
- Login-Sync Handy->Uhr, Wear-Installation Build 38+, eigene Stunden auf der Uhr, Ausfall grau.
- Garmin: siehe `garmin/HANDOFF.md`.
