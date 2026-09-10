# PlayLense

Offline-Coach- und Analyst-App für das iPad. Gebaut für den Einsatz als Co-Trainer/Analyst
im Amateurfußball (Bayern, A-Klasse), wo Videoaufzeichnungen nicht erlaubt sind und ein
einzelner Beobachter am Spielfeldrand Statistiken erfassen muss.

**Status:** Planung abgeschlossen, erste Bausteine vorhanden: 60 Übungen als Seed-Daten, ein
Prüf- und Bündel-Werkzeug sowie ein Swift-Package mit Übungsmodell, Validator, Bibliothek und
Editor-Views (noch nicht kompiliert, siehe `PlayLenseCore/README.md`).

## Dokumente

| Datei | Inhalt |
|---|---|
| [docs/01-planung.md](docs/01-planung.md) | Hauptplanung: Ziel, Leitplanken, Offline-Architektur, Tech-Stack, alle Module, Match Center im Detail, Umsetzungsreihenfolge, Vergleich mit anderen Tools, offene Entscheidungen |
| [docs/02-datenmodell.md](docs/02-datenmodell.md) | Entitäten und Tabellen (SQLite), Event-Log, abgeleitete Kennzahlen |
| [docs/03-event-katalog.md](docs/03-event-katalog.md) | Welche Events live erfasst werden, mit Definitionen, Tap-Folgen und Flag-Katalog |
| [docs/04-regelwerk-und-generator.md](docs/04-regelwerk-und-generator.md) | Kennzahlen, Problemerkennung als Regelwerk, Trainingsgenerator |
| [docs/05-animationsformat.md](docs/05-animationsformat.md) | Keyframe-Format für 2D-Übungsanimationen, Editor und Playback |
| [docs/06-uebungen-erfassen.md](docs/06-uebungen-erfassen.md) | Übungen anlegen: Dateien, Werkzeug, Editor in der App, Schreibregeln |
| [docs/00-brainstorm-chatgpt.md](docs/00-brainstorm-chatgpt.md) | Ursprüngliches Brainstorming (Referenz, nicht verbindlich) |

## Verzeichnisse

| Pfad | Inhalt |
|---|---|
| `content/exercises/` | 60 Übungen in sechs Kategorie-Dateien (JSON), je 10 |
| `content/goals.json`, `tags.json`, `material.json` | Vokabular für Ziele, Tags und Material |
| `content/exercises.seed.json` | Gebündelte Übungen mit IDs für die App (generiert) |
| `tools/exercises.py` | `validate`, `list`, `stats`, `new <slug>`, `bundle` |
| `PlayLenseCore/` | Swift-Package: Modelle, Validator, Bibliothek, Animations-Player, Editor |

```bash
python3 tools/exercises.py validate   # alle Übungen prüfen
python3 tools/exercises.py stats      # Abdeckung je Ziel und Form
python3 tools/exercises.py new mein-slug
python3 tools/exercises.py bundle     # Seed für die App erzeugen
```

## Kernprinzipien

1. **Offline-first.** Kein Server, kein Login, kein Netz nötig. Alle Daten liegen auf dem iPad.
2. **Zwei-Sekunden-Regel.** Jede Live-Aktion im Spiel braucht höchstens zwei bis drei Taps und höchstens zwei Sekunden Blick aufs Gerät.
3. **Nichts geht verloren.** Jedes Event wird sofort persistiert. Ein App-Absturz in der 70. Minute kostet kein einziges Event.
4. **Nachvollziehbar statt magisch.** Problemerkennung und Trainingsvorschläge laufen über ein lesbares Regelwerk, nicht über eine Black Box.
