# Schulportal fuer Garmin Venu Sq 2 (Testversion)

Eigenstaendige Connect-IQ-App (Monkey C) fuer die **Venu Sq 2** (`venusq2`, 320x360, rechteckig).
Seiten: **Jetzt / Heute / Vertretungen** (wischen oder tippen).
Ohne Daten zeigt sie Beispieldaten. Echte Daten schickt die Schulportal-Handy-App
(Einstellungen > "An Garmin-Uhr senden", ab Build 36). Ein gelber Punkt oben rechts
auf der Uhr = echte Daten empfangen.

App-ID (muss in der Handy-App `lib/utils/garmin_sync.dart` stehen):
`a310ed80-12b3-4086-9623-15db0f0699c2` (= `id` in `manifest.xml`, ohne Bindestriche)

---------------------------------------------------------------------
## Anleitung fuer den Besitzer der Uhr (Schritt fuer Schritt)

### A) Einmalig: Garmin-Entwicklerkonto
1. Auf https://developer.garmin.com mit einem (kostenlosen) Garmin-Konto anmelden/registrieren.
2. Lizenz-Hash holen (am PC, einmalig):
   - `connect-iq-sdk-manager` installieren:
     `curl -s https://raw.githubusercontent.com/lindell/connect-iq-sdk-manager-cli/master/install.sh | sh`
   - `connect-iq-sdk-manager agreement view` ausfuehren, den angezeigten **Hash** notieren.

### B) Bauen mit GitHub (Fork)
1. Dieses Repo auf GitHub **forken** (alle Branches, mindestens `garmin`).
2. Im Fork: Settings > Secrets and variables > Actions:
   - Secret `GARMIN_USERNAME` = Garmin-Login (E-Mail)
   - Secret `GARMIN_PASSWORD` = Garmin-Passwort
   - Variable `AGREEMENT_HASH` = der Hash aus A)
3. Im Fork: Actions > "Garmin Build (Venu Sq 2)" > Run workflow (Branch `garmin`).
4. Fertig: unter Releases liegt `Schulportal-venusq2.prg`.

(Alternativ ohne GitHub: VS Code + Garmin "Monkey C"-Erweiterung, Ordner `garmin/`
oeffnen, "Build for Device" > `venusq2`.)

### C) Auf die Uhr
1. Uhr per USB an den PC. Datei `Schulportal-venusq2.prg` nach `GARMIN/Apps` kopieren.
2. Uhr abziehen. Die App "Schulportal" erscheint in der App-Liste.

### D) Daten vom Handy
1. Handy: Schulportal-App **Build 36 oder neuer** (Android), Garmin Connect App installiert
   und mit der Uhr verbunden.
2. In der Schulportal-App einmal Stundenplan und Vertretungen oeffnen.
3. Einstellungen > "An Garmin-Uhr senden" tippen.
4. Auf der Uhr die App oeffnen (gelber Punkt = Daten da).

Bei einer Fehlermeldung am Handy: Text notieren und im Chat melden.

---------------------------------------------------------------------
## Stand / bekannte Luecken (Testversion)
- Nichts davon wurde auf einer echten Uhr oder im Simulator getestet.
- Senden ist manuell (keine automatische Aktualisierung).
- Nur Stundenplan (eigener Plan, heute/naechster Schultag) und Vertretungen dieses Tages.
- Die Monkey-C-Quellen wurden nicht kompiliert; erste Build-Fehler sind moeglich.
