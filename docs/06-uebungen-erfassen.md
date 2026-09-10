# Übungen erfassen und pflegen

Die Übungsbibliothek besteht aus zwei Ebenen, die dasselbe Format teilen:

1. **Dateien im Repo** (`content/exercises/*.json`): die mitgelieferten 60 Übungen und alles, was
   du am Mac oder in einem Texteditor ergänzt. Geprüft und gebündelt mit `tools/exercises.py`.
2. **Editor in der App** (`PlayLenseUI/ExerciseEditorView`): eigene Übungen direkt auf dem iPad
   anlegen, bearbeiten, exportieren und importieren. Gleiche Validierungsregeln wie das Werkzeug.

Beide Wege erzeugen JSON im Format aus `content/TEMPLATE.exercise.json`.

## 1. Was mitgeliefert ist

| Datei | Inhalt | Anzahl |
|---|---|---|
| `01-aktivierung.json` | Aufwärmen mit Ball, Rondo 4v1, Koordination, Handball, Passformen | 10 |
| `02-rondos-positionsspiele.json` | 5v2, 6v2 dritter Mann, 4v4+3, 5v5+2, drei Zonen, Doppelrondo, 7v7+3 | 10 |
| `03-spielaufbau-pressing.json` | 6v4 gegen Pressing, TW+4v3, Schablone dritter Mann, 8v6 Tiefenzone, Pressingzone, Pressingauslöser Rückpass, Gegenpressing, 11v8, Jagdform | 10 |
| `04-umschalten-defensive.json` | Umschaltspiele, Restverteidigung mit Konterspielern, Schattenlaufen, Verschieben, Konter 3v2+1, Kompaktheit, Seitenverteidigung, Umschaltturnier | 10 |
| `05-torabschluss-angriff.json` | Doppelpass mit Sechser, Flanke und Strafraumbesetzung, 1v1 Flügel, 2v1, Tiefenläufe, Außenzonen, Torschusswettkampf, zweite Reihe, 5v4+TW, Kopfball | 10 |
| `06-spielformen-standards-abschluss.json` | 8v8 Umschaltregel, 9v9 Drittel, 7v7 Aufbauzone, Ecken defensiv/offensiv, Freistöße defensiv, zweite Bälle, Cooldown, Lattenschießen, Kleinfeld intensiv | 10 |

Zwölf Übungen haben eine 2D-Animation. Abdeckung je Ziel zeigt `python3 tools/exercises.py stats`.

## 2. Eine Übung in der Datei anlegen

```bash
python3 tools/exercises.py new mein-neues-rondo          # hängt eine Vorlage an content/exercises/99-eigene.json
# Datei im Editor ausfüllen
python3 tools/exercises.py validate                      # meldet jeden Fehler mit Datei, Position und Slug
python3 tools/exercises.py bundle                        # schreibt content/exercises.seed.json und die Kopie im Swift-Package
```

Der Slug ist der stabile Schlüssel. Die App leitet daraus die UUID ab (UUID v5, fester Namensraum),
sodass ein erneuter Import dieselbe Übung aktualisiert statt zu duplizieren.

### Felder

| Feld | Pflicht | Regel |
|---|---|---|
| `slug` | ja | Kleinbuchstaben, Ziffern, Bindestriche. Eindeutig. |
| `name` | ja | Anzeigename |
| `goal_primary` | ja | Schlüssel aus `content/goals.json` |
| `goals_secondary` | ja (darf leer sein) | Schlüssel aus `goals.json`, nicht gleich Hauptziel |
| `players_min` / `players_max` | ja | 1–30, min ≤ max |
| `duration_min` / `duration_max` | ja | 3–60 Minuten |
| `intensity` | ja | 1 (locker) bis 5 (maximal) |
| `field_width_m` / `field_length_m` | ja | Meter |
| `material` | ja | Liste `{item, count}`, `item` aus `content/material.json` |
| `description` | ja | Was und warum, mindestens 30 Zeichen |
| `procedure` | ja | Aufbau, Ablauf, Regeln, Wertung, mindestens 60 Zeichen |
| `coaching_points` | ja | mindestens 3 |
| `variations` | ja | `easier` und `harder`, je mindestens ein Eintrag |
| `tags` | ja | aus `content/tags.json`, mindestens ein Tag der Kategorie `form` |
| `animation` | nein | Format siehe `05-animationsformat.md` oder `null` |
| `source` | nein | `seed`, `eigene`, oder Herkunft (z. B. „Trainerlizenz C“) |

Die Vorlage-Texte werden vom Validator erkannt. Eine unausgefüllte Vorlage ist nie valide.

### Neue Ziele, Tags oder Material

Vokabular liegt in `content/goals.json`, `content/tags.json`, `content/material.json`. Ein neuer
Tag braucht `key`, `label`, `category` (`form`, `ziel`, `organisation`). Ein neues Ziel braucht
`default_tags`, damit der Generator Übungen dafür findet. Nach jeder Vokabularänderung
`validate` und `bundle` laufen lassen.

## 3. Eine Übung in der App anlegen

`ExerciseLibraryView` zeigt links die Liste mit Suche und Filtern (Ziel, Form, Favoriten), rechts
die Detailansicht mit Animation. Über **+** öffnet sich der Editor:

- Formular mit allen Feldern, Slug wird aus dem Namen vorgeschlagen.
- Mehrfachauswahl für Nebenziele und Tags, Stepper für Zahlen, Material aus dem Vokabular.
- Coaching Points und Variationen als editierbare Listen.
- Animation vorerst als JSON-Textfeld mit Sofortprüfung. Der grafische Keyframe-Editor kommt in
  Ausbaustufe 3 (siehe Planung).
- Live-Validierung: Speichern ist erst möglich, wenn kein Befund mehr offen ist.

Mitgelieferte Übungen lassen sich bearbeiten (die Änderung überdeckt das Original), ausblenden
und mit „Original wiederherstellen“ zurücksetzen. Eigene Übungen werden in
`Application Support/PlayLense/exercises.user.json` gespeichert, offline, und sind im
`.playlense`-Bundle enthalten, sobald der Export in Ausbaustufe 0 gebaut ist.

**Export/Import:** Jede Übung lässt sich per Teilen-Menü als JSON exportieren (AirDrop, Dateien,
Mail) und über „Importieren“ wieder einlesen, auch als Liste. So können Übungen zwischen iPad
und Mac oder mit anderen Trainern getauscht werden.

## 4. Schreibregeln für gute Übungen

- **Beschreibung** beantwortet: Was wird trainiert, in welcher Form, warum passt das zum Problem?
- **Ablauf** enthält Feldmaße, Aufstellung, Regeln, Wertung und Wechsel. Wer den Ablauf liest,
  kann die Übung ohne Rückfrage aufbauen.
- **Coaching Points** sind beobachtbare Verhaltensweisen („Ballferner Außenverteidiger rückt bis
  auf Pfostenhöhe ein“), keine Ziele („gut verschieben“).
- **Variationen** verändern eine Stellschraube: Feldgröße, Kontakte, Spielerzahl, Zeitlimit,
  Gegnerdruck.
- **Tags** ehrlich vergeben. Der Generator sucht über Tags; eine Übung mit zu vielen Tags
  landet in Einheiten, in die sie nicht gehört.

## 5. Was der Generator daraus macht

Aus `goal_primary` (volle Punktzahl) und den `default_tags` der Ziele (Teilpunktzahl) findet der
Generator passende Übungen, filtert nach Spielerzahl, Dauer, Material und zuletzt verwendeten
Übungen und ordnet sie in die Blockstruktur (Form-Tags `aktivierung`, `isoliert`,
`spielform_klein`, `spielform_gross`, `abschluss`). Details in `04-regelwerk-und-generator.md`.
