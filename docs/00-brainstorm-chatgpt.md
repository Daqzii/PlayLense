# Brainstorm (Referenz)

Zusammenfassung des ursprünglichen Brainstormings (ChatGPT, September 2026). Dient als
Herkunftsnachweis für Ideen. Verbindlich ist ausschließlich `01-planung.md`. Der dortige
Abschnitt zu einem MVP wurde bewusst nicht übernommen.

## Ausgangsfrage

Trainerlizenz und Rolle als Co-Trainer: einzelne Trainingseinheiten übernehmen, Taktik
mitbesprechen, hauptsächlich als Analyst. Gewünscht ist eine All-in-one-App für iPad/Tablet, weil
Spielaufzeichnungen in der Bayern A-Klasse nicht zulässig sind. Anforderungen:

- Einzelne Statistiken im Spiel schnell erfassen (wichtigster Punkt).
- Aus Spiel- und Trainingsstatistiken über Flags und einen Algorithmus einen passenden,
  bearbeitbaren Trainingsplan mit Übungen vorschlagen.
- Jede Übung mit 2D-Animation von oben und Beschreibung.
- Spieler anlegen, Einzelstatistiken erfassen.
- Gesamtdashboard über den Verein mit Team- und Spielerstatistiken.
- Input, wie andere Vereine oder Unternehmen das machen.

## Kernideen aus der Antwort

1. **Live Match Tracking als Homescreen im Spiel.** Zwei Spalten (eigenes Team / Gegner) mit
   Event-Buttons, darunter Taktik/Spieler/Notiz, unten das Log der letzten Events.
2. **Zwei-Stufen-System.** Event tippen, dann für 2–3 Sekunden ein Overlay für Zone (eigenes
   Drittel / Mittelfeld / Angriffsdrittel, optional links/zentrum/rechts). Keine langen Ketten.
3. **Spielfeld direkt antippbar.** 3×3-Raster, Tap auf die Zone ersetzt die Zonen-Buttons.
4. **10–15 Kernevents** statt Opta nachzubauen: Ballgewinn, Ballverlust, Abschluss, Großchance,
   Tor/Gegentor, Angriff, Standard, Pressingerfolg, Pressing überspielt, Konter (beide),
   Fehlpass Aufbau, Schlüsselzweikampf, taktisches Problem, gute taktische Situation.
5. **Quick Flags** in Gruppen Defensive/Offensive (Überladung links/rechts, Abstand IV–AV, Tiefe
   hinter Kette, Zentrum offen, zweite Bälle, Aufbauproblem, keine Tiefe, keine Breite,
   Restverteidigung, Strafraumbesetzung). Ein Tap speichert Minute + Flag; Wiederholungen
   erhöhen das Gewicht.
6. **Halbzeitmodus.** Auf Knopfdruck eine Halbzeitanalyse mit Auffälligkeiten, Abschlüssen,
   Angriffsrichtung in Prozent und Coach Notes, um mit Zahlen statt Gefühl zum Trainer zu gehen.
7. **Spieler im Spiel.** Team-Events per Tap, Spieler-Events per Long-Press oder über eine
   permanente Nummernleiste („Tap auf 10 → nächstes Event gehört Spieler 10“).
8. **Aufstellung vor dem Spiel** mit Formation, damit positionsbezogen ausgewertet werden kann
   („rechter Außenverteidiger: 7 Ballverluste“).
9. **Spielerprofile** mit Stats der letzten 5 Spiele, Entwicklungspfeilen und Coach-Ratings 1–5
   (Technik, taktisches Verständnis, Entscheidungsverhalten, Zweikampf, Intensität,
   Kommunikation).
10. **Vereinsdashboard** mit Saisonwerten und Trends über die letzten 5 Spiele.
11. **Analyse → Training über ein Regelwerk**, keine KI. Beispiel: Ballverluste Aufbau >
    Saisonschnitt × 1,25 und ≥ 5 im eigenen Drittel → Flag „Spielaufbau unter Druck“ →
    Trainingsziel Pressingresistenz → Übungskategorien Rondo, Positionsspiel, 6v4, Aufbau unter Druck.
12. **Trainingsgenerator** mit Zeitblöcken (Aktivierung, Rondos, Positionsspiel, Aufbau gegen
    Pressing, Spielform mit Umschaltregel, Cooldown) und „Warum diese Übung?“.
13. **2D-Animationen** von oben (Spieler, Gegner, Ball, Laufwege, Passwege), nur 2D.
14. **Übungsbibliothek** mit strukturierten Attributen (Ziel, Spielerzahl, Dauer, Intensität,
    Feldgröße, Material, Coaching Points, Variationen) und Tags für den Algorithmus.
15. **Problem-Scores** (z. B. Spielaufbau 82, Restverteidigung 71, Chancenverwertung 44) → Anteile
    der Einheit (40 % / 30 % / 15 % / 15 %) → Übungsauswahl nach Spielerzahl, Dauer, Feld,
    Intensität, Ziel und zuletzt verwendeten Übungen. Nicht ständig dieselben Übungen.
16. **Training tracken:** Anwesenheit, Bewertung je Übung (funktioniert, Intensität, verstanden),
    Spielerflags, die ins Profil fließen.
17. **Taktikboard** mit Formationen, Gegnerformation, Verschieben, Pfeilen, Räumen, Animation,
    Presets.
18. **Wie Profis arbeiten:** Hudl Sportscode (konfigurierbare Coding-Workflows, iPad-Live-Coding),
    Nacsport (Tagging Windows, Deskriptoren, bis 24 Buttons, iOS-Live-Tagging), Once Sport
    (Actions + Spieler + Labels, sekundäre Labels), TacticalPad (Trainingsplanung, 2D/3D-Szenen).
    Nische: Live-Tagging + Training + Spielerdatenbank + automatische Verbindung, ohne Video.
19. **Live-Insights** während des Spiels („4 der letzten 5 Ballverluste im linken Zentrum“).
20. **Zeitfenster:** Gesamtspiel, letzte 15 Minuten, seit Halbzeit, seit Wechsel.
21. **Wechsel als Analysepunkt** mit Vor/Nach-Vergleich.
22. **Acht Hauptbereiche:** Match Center, Match Analysis, Squad, Training, Exercise Library,
    Training Generator, Tactics, Club Dashboard.
