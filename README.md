# PlayLense

Offline-Coach- und Analyst-App für das iPad. Gebaut für den Einsatz als Co-Trainer/Analyst
im Amateurfußball (Bayern, A-Klasse), wo Videoaufzeichnungen nicht erlaubt sind und ein
einzelner Beobachter am Spielfeldrand Statistiken erfassen muss.

**Status:** Planungsphase. Es gibt noch keinen Code. Die Planung liegt in `docs/`.

## Dokumente

| Datei | Inhalt |
|---|---|
| [docs/01-planung.md](docs/01-planung.md) | Hauptplanung: Ziel, Leitplanken, Offline-Architektur, Tech-Stack, alle Module, Match Center im Detail, Umsetzungsreihenfolge, Vergleich mit anderen Tools, offene Entscheidungen |
| [docs/02-datenmodell.md](docs/02-datenmodell.md) | Entitäten und Tabellen (SQLite), Event-Log, abgeleitete Kennzahlen |
| [docs/03-event-katalog.md](docs/03-event-katalog.md) | Welche Events live erfasst werden, mit Definitionen, Tap-Folgen und Flag-Katalog |
| [docs/04-regelwerk-und-generator.md](docs/04-regelwerk-und-generator.md) | Kennzahlen, Problemerkennung als Regelwerk, Trainingsgenerator |
| [docs/05-animationsformat.md](docs/05-animationsformat.md) | Keyframe-Format für 2D-Übungsanimationen, Editor und Playback |
| [docs/00-brainstorm-chatgpt.md](docs/00-brainstorm-chatgpt.md) | Ursprüngliches Brainstorming (Referenz, nicht verbindlich) |

## Kernprinzipien

1. **Offline-first.** Kein Server, kein Login, kein Netz nötig. Alle Daten liegen auf dem iPad.
2. **Zwei-Sekunden-Regel.** Jede Live-Aktion im Spiel braucht höchstens zwei bis drei Taps und höchstens zwei Sekunden Blick aufs Gerät.
3. **Nichts geht verloren.** Jedes Event wird sofort persistiert. Ein App-Absturz in der 70. Minute kostet kein einziges Event.
4. **Nachvollziehbar statt magisch.** Problemerkennung und Trainingsvorschläge laufen über ein lesbares Regelwerk, nicht über eine Black Box.
