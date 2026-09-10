# Regelwerk und Trainingsgenerator

Keine KI, sondern ein lesbares Regelwerk in JSON. Jeder Vorschlag kann bis zur Regel und bis zu
den Events zurückverfolgt werden. Alles läuft offline auf dem iPad.

## 1. Pipeline

```
match_event[]  +  season_baseline  +  flag_catalog
      │
      ▼
 Kennzahlen (Statistik-Engine)
      │
      ▼
 Problemregeln  →  Problem-Scores 0..100 je Problemfeld
      │
      ▼
 Problemfeld → Trainingsziele (gewichtet)
      │
      ▼
 Zeitbudget je Ziel  →  Übungsauswahl (Tags + Constraints)
      │
      ▼
 Blockstruktur  →  bearbeitbarer Trainingsplan mit "Warum"
```

## 2. Kennzahlen

Jede Kennzahl hat einen `metric_key`, den Regeln referenzieren. Auszug der Startbelegung:

| metric_key | Bedeutung |
|---|---|
| `abschluss.wir`, `abschluss.gegner` | Abschlüsse |
| `abschluss_aufs_tor.wir`, `.gegner` | Abschlüsse aufs Tor |
| `grosschance.wir`, `.gegner` | Großchancen |
| `ballverlust.wir` | Ballverluste gesamt |
| `ballverlust.aufbau` | Ballverluste im eigenen Drittel |
| `ballverlust.zentrum` | Ballverluste Spalte Zentrum |
| `ballgewinn.hoch` | Ballgewinne im Angriffsdrittel |
| `angriff.wir.links/zentrum/rechts` | Angriffe je Seite |
| `angriff.gegner.links/zentrum/rechts` | Gegner-Angriffe je Seite (aus unserer Sicht) |
| `konter.gegner` | Gegnerische Konter |
| `pressing_ueberspielt` | Überspielte Pressinglinien |
| `standard.gegner.gefaehrlich` | Gefährliche Gegner-Standards |
| `chancenverwertung` | Tore / Großchancen |
| `flag.<key>` | Häufigkeit eines Flags |

Jede Kennzahl liegt in drei Varianten vor: `match` (dieses Spiel), `avg` (Saisondurchschnitt) und
`last5` (gleitender Durchschnitt der letzten 5 Spiele).

## 3. Problemregeln

```json
{
  "id": "aufbau_unter_druck",
  "name": "Spielaufbau unter Druck",
  "kind": "problem",
  "when": {
    "any": [
      { "metric": "ballverlust.aufbau", "op": ">=", "value": 5 },
      { "metric": "ballverlust.aufbau", "op": ">", "ref": "avg", "factor": 1.25 }
    ]
  },
  "score": {
    "base": 50,
    "scale": [
      { "metric": "ballverlust.aufbau", "per_unit_over": { "ref": "avg" }, "points": 6, "max": 30 }
    ],
    "flags": { "off_aufbauproblem": 8, "def_abstand_iv_zm": 4 },
    "max": 100
  },
  "goals": [
    { "goal": "pressingresistenz", "weight": 0.6 },
    { "goal": "spielaufbau", "weight": 0.4 }
  ],
  "explain": "{ballverlust.aufbau} Ballverluste im eigenen Drittel (Saison: {ballverlust.aufbau.avg}), Flag Aufbauproblem {flag.off_aufbauproblem}×."
}
```

- `when`: `all` / `any` aus Bedingungen. Eine Bedingung vergleicht eine Kennzahl mit einem
  Festwert (`value`) oder mit einer Referenz (`ref: avg | last5`, optional `factor`).
- `score`: Basiswert wenn `when` zutrifft, plus Skalierung nach Abweichung, plus Flag-Punkte
  (Anzahl × Punkte), gedeckelt auf `max`. Ohne `when` bleibt der Score 0.
- `goals`: Trainingsziele mit Gewicht, summieren sich zu 1.
- `explain`: Textvorlage mit Platzhaltern für den Bericht.

Bei weniger als 3 beendeten Spielen in der Saison werden `ref`-Bedingungen ignoriert und nur
Festwerte benutzt, damit der Generator ab dem ersten Spiel funktioniert.

### Startbelegung der Problemfelder

| Problemfeld | Auslöser (Kurzform) | Ziele |
|---|---|---|
| Spielaufbau unter Druck | Ballverluste Aufbau ≥ 5 oder > avg × 1,25; Flags Aufbauproblem | Pressingresistenz, Spielaufbau |
| Zentrum instabil | Ballverluste Zentrum > avg × 1,25; Flags Zentrum offen, Abstand IV–ZM | Kompaktheit, Positionsspiel |
| Restverteidigung / Konter | Gegner-Konter ≥ 3; Flag Restverteidigung | Restverteidigung, Umschalten defensiv |
| Seite überladen | Gegner-Angriffe über eine Seite ≥ 50 % und ≥ 6; Flags Überladung | Verschieben, Seitenverteidigung |
| Pressing greift nicht | Pressing überspielt ≥ 4; hohe Ballgewinne < avg × 0,7 | Pressing, Pressingauslöser |
| Chancenverwertung | Großchancen ≥ 4 und Tore/Großchancen < 0,25 | Torabschluss, Entscheidungsverhalten |
| Keine Tiefe / Breite | Angriffe < avg × 0,7; Flags Keine Tiefe, Keine Breite | Angriffsaufbau, Tiefenläufe |
| Standards defensiv | Gefährliche Gegner-Standards ≥ 3 | Standards defensiv |
| Standards offensiv | eigene Standards ≥ 8, davon gefährlich ≤ 1 | Standards offensiv |
| Zweite Bälle | Flag Zweite Bälle ≥ 3 | Zweite Bälle, Kompaktheit |

Die konkreten Schwellen sind Startwerte und in der App editierbar. Nach einer halben Saison
sollten sie an die eigenen Baselines angepasst werden.

## 4. Live-Insight-Regeln

Gleiches Format, aber mit Fenster und Trigger nach jedem Event:

```json
{
  "id": "live_ballverlust_cluster",
  "kind": "live_insight",
  "window": { "last_events_of_type": "ballverlust", "count": 5 },
  "when": { "all": [ { "metric": "share.same_zone", "op": ">=", "value": 0.8 } ] },
  "cooldown_seconds": 300,
  "explain": "{count_same_zone} der letzten 5 Ballverluste in Zone {zone}."
}
```

| Insight | Fenster | Auslöser |
|---|---|---|
| Ballverlust-Cluster | letzte 5 Ballverluste | ≥ 4 in derselben Zone |
| Gegner-Seite | letzte 15 Minuten | ≥ 6 Gegner-Angriffe, davon ≥ 75 % über eine Seite |
| Abschluss-Kippen | seit letztem Wechsel (eigen oder Gegner), mind. 8 Minuten | Abschlussverhältnis dreht sich gegenüber davor (z. B. 8:5 → 1:5) |
| Pressing-Serie | letzte 10 Minuten | ≥ 3 Pressing überspielt |
| Flag-Wiederholung | gesamtes Spiel | derselbe Flag zum 3. Mal |
| Positiv-Serie | letzte 10 Minuten | ≥ 3 hohe Ballgewinne |

`cooldown_seconds` verhindert, dass dieselbe Regel alle 30 Sekunden feuert.

## 5. Trainingsziele und Tags

```json
{ "key": "pressingresistenz", "label": "Pressingresistenz",
  "default_tags": ["spielaufbau", "rondo", "positionsspiel", "unterzahl", "vororientierung"] }
```

Startbelegung der Ziele: `spielaufbau, pressingresistenz, kompaktheit, positionsspiel,
restverteidigung, umschalten_defensiv, umschalten_offensiv, verschieben, pressing,
torabschluss, entscheidungsverhalten, angriffsaufbau, tiefenlaeufe, standards_defensiv,
standards_offensiv, zweite_baelle, technik, ausdauer, spielform`.

Übungen tragen Tags. Eine Übung passt zu einem Ziel, wenn `goal_primary` gleich dem Ziel ist
(volle Punktzahl) oder sie mindestens ein `default_tag` des Ziels trägt (Teilpunktzahl).

## 6. Generator-Algorithmus

Eingabe: Problem-Scores, verfügbare Spieler (aus erwarteter Anwesenheit), Dauer, Feldgröße,
Materialliste, Intensitätswunsch, letzte 3 Trainingseinheiten.

```
1. Ziele gewichten
   für jedes Problemfeld mit Score >= 30:
     für jedes Ziel des Feldes: zielgewicht[ziel] += score * goalweight
   normalisieren; höchstens 3 Ziele behalten; Rest → "spielform" / "technik" als Grundanteil

2. Zeitbudget
   hauptzeit = dauer - aktivierung(10-15) - abschluss(5)
   je Ziel: minuten = hauptzeit * gewicht, gerundet auf 5
   Mindestens 15 Minuten pro Ziel, sonst Ziel streichen und Zeit umverteilen
   Spielform bekommt immer >= 20 % der Hauptzeit

3. Übungen je Ziel bewerten
   score(übung, ziel) =
       ziel_treffer            (primär 1.0 / tag 0.6 / sonst 0)
     + spieleranzahl_passt     (0.3, harte Bedingung: min <= verfügbar <= max)
     + dauer_passt             (0.2 wenn Budget innerhalb min..max)
     + intensität_passt        (0.1)
     + material_verfügbar      (harte Bedingung, sonst raus)
     - zuletzt_verwendet       (0.5 wenn in letzten 3 Einheiten, 0.25 wenn in letzten 6)
     + favorit                 (0.1)
   Bei Gleichstand zufällig mit festem Seed pro Sitzung (reproduzierbar bis zum Neu-Erzeugen)

4. Blockstruktur füllen
   Aktivierung  : Tag "aktivierung" oder "rondo", 10-15 Min
   Hauptteil 1  : Ziel mit höchstem Gewicht, isolierte Form (Tag "isoliert" / "positionsspiel")
   Hauptteil 2  : Ziel 1 oder 2, komplexere Form (Tag "spielform_klein")
   Spielform    : Tag "spielform_gross", mit Regel passend zum Hauptziel (z. B. Umschaltregel)
   Abschluss    : Tag "abschluss" / "cooldown", 5 Min
   Intensitätskurve prüfen: nicht zwei 5er-Intensitäten hintereinander

5. "Warum"-Texte
   je Block: Ziel + Begründung aus explain der Regel + Coaching Points der Übung

6. Ausgabe: training_session (status geplant) mit training_block[] und generator_input_json
```

Der Plan ist danach vollständig editierbar. „Neu würfeln“ erzeugt mit neuem Seed einen
alternativen Plan mit denselben Zielen. „Block ersetzen“ zeigt die nächstbesten drei Übungen
für dasselbe Ziel.

## 7. Rückkopplung aus dem Training

- Bewertung „Funktioniert?“ ≤ 2 senkt den Übungs-Score in den nächsten 10 Einheiten um 0,2.
- Bewertung ≥ 4 markiert die Übung als bewährt (+0,1).
- Trainingsziele einer durchgeführten Einheit dämpfen denselben Problem-Score im nächsten
  Vorschlag um 20 %, damit nicht drei Wochen hintereinander dasselbe trainiert wird, außer das
  Problem tritt im nächsten Spiel erneut auf.

## 8. Transparenz in der App

- Ansicht „Regeln“: alle Regeln als Liste mit Name, Bedingung in Klartext, aktiv/inaktiv,
  Schwellwerte editierbar.
- Ansicht „Warum dieser Plan?“: Problem-Scores, ausgelöste Regeln mit Zahlen, Zielgewichte,
  Zeitbudget, je Block die Auswahlbegründung.
- Jede Regel lässt sich auf ein vergangenes Spiel anwenden („Was hätte die Regel hier gesagt?“),
  um Schwellwerte zu kalibrieren.
