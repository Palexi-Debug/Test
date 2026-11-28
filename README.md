# Schulportal (iOS / iPadOS) – Philipp-Reis-Schule

Native SwiftUI-App für das Schulportal Hessen (Schule 6110). Inoffizieller
Open-Source-Client, nicht von der Schule oder dem Schulportal Hessen betrieben.

## Basiert auf Lanis Mobile

Die Anbindung an das Schulportal stammt vom freien Projekt
[Lanis Mobile](https://github.com/lanis-mobile/lanis) (GPLv3). Dieses Projekt steht
deshalb ebenfalls unter der GPLv3.

## Aufbau

- `ios-swift/` – XcodeGen-Projekt (`project.yml`) und Quellcode (`Sources/`), SwiftSoup per SPM.
- `.github/workflows/ios.yml` – baut mit dem neuesten Xcode eine unsignierte IPA (iPhone + iPad) und
  veröffentlicht sie als Release `ios-<Nr>`.
- Die Android-/Wear-App, Garmin und die Desktop-Builds liegen auf den Branches `main`, `garmin`,
  `windows`, `macos`.

## Installieren

IPA aus dem Release `ios-<Nr>` laden und per AltStore/Sideloadly signieren und installieren.
