# Schulportal fuer Garmin Venu Sq 2 (Testversion)

Eigenstaendige Connect-IQ-App (Monkey C), Geraet `venusq2` (320x360, rechteckig).
Zeigt Seiten **Jetzt / Heute / Vertretungen** (Wischen oder Tippen zum Blaettern).
Aktuell mit **Beispieldaten**. Spaeter sollen echte Daten von der Schulportal-Handy-App
per Connect-IQ-Nachricht kommen (`registerForPhoneAppMessages` ist schon eingebaut).

## Bauen (GitHub Actions)
Noetig, damit der Build laeuft:
1. Secrets `GARMIN_USERNAME` und `GARMIN_PASSWORD` (Garmin-Entwicklerkonto, kostenlos).
2. Variable `AGREEMENT_HASH`: einmal lokal `connect-iq-sdk-manager agreement view` ausfuehren
   und den angezeigten Hash eintragen (Lizenzbestaetigung).
3. Push auf den Branch `garmin` -> Release `garmin-<Nr>` enthaelt `Schulportal-venusq2.prg`.

## Auf die Uhr
Uhr per USB an den PC, `Schulportal-venusq2.prg` nach `GARMIN/Apps` kopieren, Uhr trennen.
