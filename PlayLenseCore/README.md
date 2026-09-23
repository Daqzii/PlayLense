# PlayLenseCore

Swift-Package mit der gesamten Logik und Oberfläche der App. Das App-Target in `App/` ist nur die
dünne Hülle darum.

| Target | Inhalt |
|---|---|
| `PlayLenseCore` | Domäne (Team, Saison, Spieler, Spiel, Events, Flags), Match-Engine (Uhr, Aufstellung mit Rückwechseln, Statistik je Zeitfenster, Berichte, Live-Hinweise, Spielfeld-Geometrie), Übungsmodell, Animationsformat, Validator, Übungsbibliothek, Seed-Bundle |
| `PlayLenseData` | SQLite über GRDB: Migrationen, Repositories, Event-Log, Export/Import als `.playlense`-ZIP |
| `PlayLenseUI` | SwiftUI: Root-Navigation, Kader, Spiele und Aufstellung, Match Center, Berichte (Text/PDF), Statistik, Übungsbibliothek und Editor, Einstellungen |

**Status:** baut und testet auf GitHub Actions (macOS-Runner, iPad-Simulator, Xcode 16.4).
Tests liegen in `../Tests` und laufen über das Xcode-Projekt (`make test` oder ⌘U).

## Seed aktualisieren

`Sources/PlayLenseCore/Resources/exercises.seed.json` wird von `python3 tools/exercises.py bundle`
geschrieben. Nicht von Hand ändern, sondern `content/exercises/` bearbeiten und neu bündeln.
