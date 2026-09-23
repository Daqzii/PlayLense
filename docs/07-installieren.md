# Installieren und Bauen

## Einmalig am Mac

1. Xcode aus dem App Store installieren und einmal starten (Lizenz bestätigen, Komponenten laden).
2. Homebrew installieren (https://brew.sh), dann:
   ```bash
   brew install xcodegen
   ```
3. Repo klonen und Projekt erzeugen:
   ```bash
   git clone https://github.com/Daqzii/PlayLense.git
   cd PlayLense
   git checkout claude/offline-ipad-app-planning-l4pswu
   make project
   open PlayLense.xcodeproj
   ```
   `make project` erzeugt `PlayLense.xcodeproj` aus `project.yml`. Die Projektdatei liegt nicht im Repo;
   nach jeder Änderung an `project.yml` einfach erneut `make project`.

## Auf dem iPad starten (ohne Developer-Account)

1. iPad per Kabel anschließen, in Xcode oben als Ziel auswählen.
2. Xcode → Target „PlayLense“ → Signing & Capabilities → Team: deine Apple-ID als „Personal Team“.
   Falls die Bundle-ID kollidiert, `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` ändern.
3. Auf dem iPad: Einstellungen → Datenschutz & Sicherheit → Entwicklermodus einschalten (Neustart).
4. Xcode → Run (⌘R). Beim ersten Start auf dem iPad: Einstellungen → Allgemein → VPN & Geräteverwaltung →
   Entwickler-App vertrauen.

**Wichtig ohne bezahlten Developer-Account:** Die App läuft 7 Tage, danach startet sie nicht mehr,
bis du sie erneut aus Xcode installierst. Die Daten bleiben dabei erhalten (Neuinstallation über
Xcode überschreibt nur die App, nicht den Container). Trotzdem vor jedem Spieltag prüfen, ob die
App startet, und regelmäßig ein Backup-Bundle in den Einstellungen erzeugen. Mit dem bezahlten
Account (99 €/Jahr) entfällt die 7-Tage-Grenze.

## Tests

```bash
make test        # baut und testet im iPad-Simulator
```

Oder in Xcode ⌘U.

## CI auf GitHub

`.github/workflows/ios.yml` baut und testet auf einem macOS-Runner bei jedem Push, der Swift-Code
oder das Projekt berührt. macOS-Minuten werden bei privaten Repos zehnfach gezählt; ein Lauf
kostet etwa 60 bis 120 Minuten des Monatskontingents. Der Workflow lässt sich unter „Actions“
manuell starten oder abschalten.

## Übungsdaten aktualisieren

```bash
make bundle      # prüft content/exercises und schreibt exercises.seed.json ins Package
```
