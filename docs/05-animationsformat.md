# 2D-Animationsformat

Ein Format für Übungen und Taktik-Presets. Sicht von oben, Keyframe-basiert, als JSON in der
Datenbank gespeichert. Der Player interpoliert zwischen Keyframes; der Editor nimmt Keyframes auf.

## 1. Format

```json
{
  "version": 1,
  "pitch": { "width_m": 35, "length_m": 30, "markings": "none", "orientation": "landscape" },
  "tokens": [
    { "id": "a1", "kind": "player", "team": "own", "label": "6" },
    { "id": "a2", "kind": "player", "team": "own", "label": "8" },
    { "id": "b1", "kind": "player", "team": "opp", "label": "" },
    { "id": "n1", "kind": "neutral", "label": "N" },
    { "id": "c1", "kind": "cone", "color": "orange" },
    { "id": "g1", "kind": "minigoal", "rotation_deg": 0 }
  ],
  "static": [
    { "kind": "zone", "rect_m": [10, 5, 15, 20], "color": "blue", "opacity": 0.15 },
    { "kind": "line", "from_m": [0, 15], "to_m": [35, 15], "style": "dashed" },
    { "kind": "text", "at_m": [17, 2], "text": "6v4 + 2 neutrale" }
  ],
  "keyframes": [
    { "t": 0.0,
      "positions": { "a1": [5, 15], "a2": [12, 8], "b1": [17, 15], "c1": [0, 0], "g1": [34, 15] },
      "ball": { "holder": "a1" } },
    { "t": 1.5,
      "positions": { "a1": [6, 14], "b1": [12, 15] },
      "ball": { "holder": "a2" },
      "transition": { "pass": ["a1", "a2"], "runs": [["b1", "curve"]] } },
    { "t": 3.0,
      "positions": { "a2": [14, 10] },
      "ball": { "holder": "a2" },
      "transition": { "dribble": "a2" } }
  ],
  "loop": true
}
```

Regeln:

- Positionen in Metern, Ursprung links unten. Ein Token, das in einem Keyframe fehlt, behält
  seine letzte Position.
- `ball.holder` gibt an, wer den Ball am Ende des Keyframes hat. `ball.at_m` alternativ für
  einen freien Ball.
- `transition.pass` zeichnet während des Übergangs eine Passlinie und lässt den Ball von Token
  zu Token fliegen. `dribble` bindet den Ball an den Spieler. `runs` markiert Laufwege mit Pfeil.
- Interpolation linear mit leichtem Ease-in/out. Passgeschwindigkeit ist konstant, unabhängig
  von der Keyframe-Dauer, damit Pässe realistisch aussehen.
- `markings`: `none`, `half`, `full`, `box` (nur Strafraum). Für Rondos `none`.

## 2. Darstellung

| Element | Darstellung |
|---|---|
| Eigener Spieler | ausgefüllter Kreis, Teamfarbe, Nummer weiß |
| Gegner | ausgefüllter Kreis, rot |
| Neutraler | ausgefüllter Kreis, gelb |
| Ball | kleiner weißer Kreis mit dunklem Rand |
| Hütchen | kleines Dreieck |
| Minitor / Tor | offener Rahmen |
| Laufweg | Pfeil, durchgezogen |
| Passweg | Pfeil, gestrichelt |
| Dribbling | Wellenlinie |
| Zone | halbtransparentes Rechteck |

Gezeichnet mit SwiftUI `Canvas` in einer `TimelineView(.animation)`. Skalierung: Meter →
Punkte anhand der Pitch-Größe, sodass die Übung immer den verfügbaren Platz ausfüllt.

## 3. Player

- Play / Pause, Scrubber über die Gesamtzeit, Geschwindigkeit 0,5× / 1× / 2×, Schleife.
- Keyframe-Marker auf dem Scrubber, Tap springt dorthin.
- Vollbild-Modus fürs Training (nur Animation und Coaching Points).

## 4. Editor

Keyframe-Editor, keine Frame-für-Frame-Arbeit:

1. **Setup:** Pitch-Größe wählen, Tokens aus einer Palette aufs Feld ziehen (Spieler, Gegner,
   Neutral, Hütchen, Tor, Ball). Statische Elemente (Zonen, Linien, Text) zeichnen.
2. **Keyframe 0** ist die Startaufstellung.
3. **Keyframe hinzufügen:** Kopie des letzten Keyframes. Tokens per Drag an ihre neue Position
   ziehen. Ball auf einen Spieler ziehen = Pass zu diesem Spieler. Ball mit Spieler ziehen =
   Dribbling.
4. Dauer je Keyframe-Übergang per Stepper (0,5 s Schritte).
5. Vorschau jederzeit mit Play.
6. Keyframes duplizieren, löschen, umsortieren.

Der Editor speichert nach jeder Änderung. Undo/Redo über eine einfache Snapshot-Liste.

## 5. Nutzung im Taktikboard

Das Taktikboard verwendet dasselbe Format mit `markings: "full"`, 11 eigenen und 11
gegnerischen Tokens aus den Formationen. Freihand-Zeichnungen aus PencilKit werden als
zusätzliches `drawing_base64` neben der Animation im Preset gespeichert, nicht im
Animationsformat selbst.

## 6. Austausch

Eine Übung samt Animation ist eine einzelne JSON-Datei. Damit kann die Bibliothek auch am Mac
gepflegt oder mit anderen Trainern getauscht werden, ohne dass die App online sein muss.
