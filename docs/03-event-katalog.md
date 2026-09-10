# Event-Katalog

Jeder Event-Typ hat eine feste Definition. Die Definition ist wichtiger als die Vollständigkeit:
Ein Saisonvergleich funktioniert nur, wenn „Ballverlust“ im August dasselbe bedeutet wie im April.

Legende Tap-Folge: `E` = Event-Button, `Z` = Zone auf dem Spielfeld, `S` = Seite (Spalte),
`R` = Ergebnis-Overlay, `T` = Typ-Overlay, `P` = Spieler (immer optional, vorher über Spielerleiste).

## 1. Team-Events (Wir und Gegner)

| Event | Schlüssel | Tap-Folge | Zusatzdaten | Definition |
|---|---|---|---|---|
| Ballgewinn | `ballgewinn` | E Z | Zone | Wir erobern den Ball im Spiel (Zweikampf, abgefangener Pass, Fehler des Gegners) und kontrollieren ihn danach mindestens einen Pass oder eine Dribblingaktion lang. Kein Ballgewinn: Abstoß, Einwurf, Foul. **Zone Angriffsdrittel = hoher Ballgewinn / Pressingerfolg.** |
| Ballverlust | `ballverlust` | E Z | Zone | Der Gegner erobert den Ball kontrolliert (siehe Ballgewinn). Ins Aus gespielt zählt, wenn der Gegner dadurch Ballbesitz bekommt. **Zone eigenes Drittel = Ballverlust im Aufbau.** |
| Abschluss | `abschluss` | E Z R | Zone, Ergebnis `tor / aufs_tor / vorbei / geblockt`, optional Tor-Art `spiel / standard / konter / elfmeter / eigentor` | Jeder Versuch, ein Tor zu erzielen. Kopfball zählt. Zone Angriffsdrittel Zentrum ≈ Strafraum. |
| Großchance | `grosschance` | E Z | Zone | Situation, in der ein Tor mit hoher Wahrscheinlichkeit zu erwarten wäre (frei vor dem Torwart, Abschluss aus dem Fünfer, Elfmeter). Kann zusätzlich zu einem Abschluss erfasst werden oder ohne (Chance vertändelt). |
| Angriff | `angriff` | E S | Seite | Kontrollierter Ballbesitz wird ins Angriffsdrittel getragen oder gespielt. Ein Angriff endet mit Ballverlust, Abschluss, Standard oder Rückzug ins Mittelfeld. Seite = Spalte, über die der Ball ins Drittel kommt. |
| Konter | `konter` | E Z | Zone (Startpunkt) | Nach Ballgewinn wird innerhalb weniger Sekunden mit Tempo Richtung Tor gespielt, bevor sich der Gegner ordnet. Der eigentliche Angriff wird nicht zusätzlich als `angriff` erfasst. |
| Pressing überspielt | `pressing_ueberspielt` | E Z | Zone (wo die Linie fällt) | Der Gegner überspielt unsere erste oder zweite Pressinglinie mit einem Pass oder Dribbling und hat danach freien Raum. Nur für „Wir“ sinnvoll; beim Gegner entspricht es unserem Ballgewinn im Angriffsdrittel. |
| Standard | `standard` | E T | Typ `ecke / freistoss / einwurf / elfmeter`, optional gefährlich ja/nein | Ruhender Ball in der gegnerischen Hälfte (Einwurf nur im Angriffsdrittel). |

## 2. Spieler-Events (nur Wir)

| Event | Schlüssel | Tap-Folge | Zusatzdaten | Definition |
|---|---|---|---|---|
| Schlüsselzweikampf | `zweikampf` | P E R | Spieler, Ergebnis `gewonnen / verloren` | Zweikampf mit direkter Auswirkung (verhindert Chance oder führt zu Chance). Nicht jeder Zweikampf. |
| Karte | `karte` | E P T | Spieler, `gelb / gelbrot / rot` | Rote und Gelb-Rote Karte entfernen den Spieler aus der Leiste. |
| Verletzung | `verletzung` | E P | Spieler | Spieler kann nicht weiterspielen oder wird behandelt. Setzt Status im Profil. |
| Wechsel | `wechsel` | E P P | Raus, Rein, Position | Marker auf der Zeitachse. Einsatzminuten und Vor/Nach-Fenster werden daraus berechnet. |
| Gegner-Wechsel | `wechsel_gegner` | E | keine | Marker ohne Spielerdaten. |

Jedes Team-Event kann zusätzlich einen Spieler tragen, wenn vorher eine Nummer in der
Spielerleiste getippt wurde (z. B. `#9 → Abschluss`, `#6 → Ballverlust`).

## 3. Flags und Notizen

| Event | Schlüssel | Tap-Folge | Zusatzdaten |
|---|---|---|---|
| Flag | `flag` | E T (Z) | Flag-Schlüssel, optional Zone |
| Notiz | `notiz` | E + Text | Freitext, Diktat über die iPad-Tastatur (Offline-Diktat für Deutsch ist auf aktuellen iPads verfügbar) |

### Flag-Katalog (Startbelegung, in den Einstellungen editierbar)

| Gruppe | Schlüssel | Bezeichnung |
|---|---|---|
| Defensive | `def_ueberladung_links` | Überladung links |
| Defensive | `def_ueberladung_rechts` | Überladung rechts |
| Defensive | `def_abstand_iv_av` | Abstand IV–AV |
| Defensive | `def_tiefe_hinter_kette` | Tiefe hinter der Kette |
| Defensive | `def_zentrum_offen` | Zentrum offen |
| Defensive | `def_zweite_baelle` | Zweite Bälle verloren |
| Defensive | `def_abstand_iv_zm` | Abstand IV–ZM |
| Defensive | `def_restverteidigung` | Restverteidigung |
| Offensive | `off_aufbauproblem` | Aufbauproblem |
| Offensive | `off_keine_tiefe` | Keine Tiefe |
| Offensive | `off_keine_breite` | Keine Breite |
| Offensive | `off_strafraumbesetzung` | Zu wenig Strafraumbesetzung |
| Offensive | `off_tempo_umschalten` | Zu langsam beim Umschalten |
| Positiv | `pos_pressing_greift` | Pressing greift |
| Positiv | `pos_aufbau_sauber` | Aufbau sauber |
| Positiv | `pos_umschalten_stark` | Umschaltmoment stark |
| Positiv | `pos_standard_gefaehrlich` | Standards gefährlich |

Jeder Flag hat ein `weight` (Standard 1.0) und eine optionale Zuordnung zu Trainingszielen
(siehe Regelwerk). Eigene Flags können jederzeit angelegt werden.

## 4. Erfassungsprofile

| Profil | Enthaltene Events |
|---|---|
| Voll | alles |
| Kompakt | ballgewinn, ballverlust, abschluss, grosschance, angriff, standard, wechsel, karte, flag, notiz |
| Minimal | abschluss (beide), wechsel, karte, flag, notiz |

Profile blenden nur Buttons aus. Ein im Profil ausgeblendetes Event bleibt im Datenmodell
vorhanden, alte Spiele bleiben vollständig auswertbar.

## 5. Tap-Budget

| Event | Taps | Zielzeit |
|---|---|---|
| Ballgewinn, Ballverlust, Großchance, Konter, Pressing überspielt | 2 | < 1,5 s |
| Angriff | 2 | < 1 s |
| Standard | 2 | < 1,5 s |
| Abschluss | 3 | < 2,5 s |
| Flag | 2 (3 mit Zone) | < 2 s |
| Wechsel | 3 | < 5 s (nicht zeitkritisch) |
| Jedes Event mit Spieler | +1 | +0,5 s |

Regel: Bleibt Stufe 2 länger als 4 Sekunden aus, wird das Event ohne Zone gespeichert und der
Zustand zurückgesetzt. Kein Event geht dadurch verloren.

## 6. Zonen

```
                 GEGNER-TOR
        ┌──────────┬──────────┬──────────┐
 Angr.  │  links   │ zentrum  │  rechts  │   angriffsdrittel
        ├──────────┼──────────┼──────────┤
 Mitte  │  links   │ zentrum  │  rechts  │   mittelfeld
        ├──────────┼──────────┼──────────┤
 Eig.   │  links   │ zentrum  │  rechts  │   eigenes_drittel
        └──────────┴──────────┴──────────┘
                 EIGENES TOR
```

- `zone_row ∈ {eigenes_drittel, mittelfeld, angriffsdrittel}`
- `zone_lane ∈ {links, zentrum, rechts}`
- Immer aus **unserer** Angriffsperspektive, auch für Gegner-Events.
- Für spätere Verfeinerung sind `zone_x` und `zone_y` (0–1, normalisiert) als optionale
  Felder vorgesehen. Ein Tap speichert die Rasterzone und zusätzlich die genaue Tap-Position.
