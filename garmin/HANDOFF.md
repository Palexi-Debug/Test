# Garmin Venu Sq 2 - Uebergabe fuer den Extra-Chat

## Ziel
Schulportal-Hessen (Philipp-Reis-Schule, Schul-ID 6110) auf der Garmin **Venu Sq 2** (rechteckig, 320x360):
Stundenplan + Vertretungen, **gleichwertig zur Wear-OS-Version** (Seiten Jetzt / Heute / Vertretungen),
Daten kommen automatisch vom Handy, Updates moeglichst automatisch.

## Architektur
- Garmin-App (Monkey C) im Branch `garmin`, Ordner `garmin/` (manifest, source/*.mc, resources).
- Daten holt die **Handy-App** (Flutter, Branch `main`) und schickt sie per Connect-IQ-Nachricht
  (`watch_connectivity_garmin`). Die Uhr loggt sich NICHT selbst ins Schulportal ein.
- App-ID: `a310ed80-12b3-4086-9623-15db0f0699c2` (manifest `id` ohne Bindestriche; in
  `lib/utils/garmin_sync.dart` mit Bindestrichen).
- Nachrichtenformat: `{ "lessons": [ {s,e (Minuten ab 0 Uhr), n (Fach), r (Raum)} ],
  "subs": [ {std, fach, art, vertr, raum} ] }`.

## Build (funktioniert)
- Workflow `.github/workflows/garmin.yml` (Branch `garmin`): Garmin SDK-Manager-CLI
  (lindell/connect-iq-sdk-manager-cli), Login per Secrets `GARMIN_USERNAME`/`GARMIN_PASSWORD`,
  Variable `AGREEMENT_HASH`; Flag heisst `--agreement-hash` (vom Nutzer mit Gemini korrigiert).
  Ergebnis: Release `garmin-<Nr>` (Vorabversion) mit `Schulportal-venusq2.prg` + Artifact.
- Installation: .prg per USB nach `GARMIN/Apps` kopieren.
- Der Build lief erfolgreich und die App startet auf der echten Uhr (Fotos vom Nutzer).

## Stand (aktualisiert 14.11.2026)
- Neuestes Release: `garmin-15` (Datei `Schulportal-venusq2.prg`), Build gruen. Das neue Layout kompiliert
  (Fix: Schriften als `Graphics.FontType` typisiert, `fit()` gibt `Graphics.FontType` zurueck).
  Launcher-Icon ist jetzt 40x40. Auf der Uhr ist das neue Layout NOCH NICHT getestet.
- Version 0.1.1 (Commit "Info-Seite"): neue 4. Seite "Info" mit Versionsnummer (`DataStore.VERSION`, muss zu
  `manifest.xml` passen), Sync-Stand und Hinweis Live/Beispiel. Ungetestet auf der Uhr.
- Seiten Jetzt/Heute/Vertretungen laufen, wischen/tippen blaettert. Anfangs Beispieldaten.
- Layout im ersten Stand war schlecht (Texte ueberlappten, Vertretungen unuebersichtlich) ->
  neu gebaut (Commit "Layout neu"): feste Zeilenhoehen, Karten, Fortschrittsbalken, "Stand HH:MM".
  Ob es auf der Uhr gut aussieht: vom Nutzer pruefen lassen (Foto).
- Handy-App (ab Build 36, Auto-Abgleich ab dem naechsten Build): Einstellungen > "An Garmin-Uhr
  senden". Nach dem ersten erfolgreichen Senden schickt die App alle ~10 Min automatisch, solange
  sie offen ist (Startseite).

## Wuensche des Nutzers (offen)
1. **Sync sobald Internet/Handy verfuegbar, automatisch** - bisher nur bei offener Handy-App.
   Echter Hintergrund-Abgleich (Android-Hintergrunddienst im Flutter-Projekt: `lib/background_service.dart`)
   und Wecken des Handys von der Uhr aus sind noch nicht gebaut.
2. **Auto-Update der Garmin-App** - fuer sideloadete .prg nicht moeglich. Echter Weg:
   Veroeffentlichung im Connect IQ Store (kostenlos, Pruefung) -> Garmin Connect aktualisiert dann selbst.
   Alternativ: Versionsnummer in Nachricht mitschicken, Handy meldet "neues Update".
3. Gleichwertig zur Wear-OS-Version: Wear hat ausserdem Update-Seite, Secret (Versions-Tipp), eigene
   Eingaben. Garmin hat noch keine Versionsanzeige/Secret.
4. Eigene Stunden/AGs und Lehrernamen auf der Uhr (Handy-Daten enthalten sie teils schon im Plan).

## Bekannte Risiken
- Alles nur auf einer Uhr getestet (Freund des Nutzers); Simulator fehlt.
- Garmin-Konto-Zugang liegt als Secret im Repo `Palexi-Debug/Test`.
- Nachrichtengroesse: Connect IQ begrenzt Nachrichten; aktuell max. 10 Stunden + 8 Vertretungen.
- Versionsschema der Apps: Build 30 = 0.1.0, 31 = 0.1.1, 40 = 0.2.0 (Zehner = Minor).
