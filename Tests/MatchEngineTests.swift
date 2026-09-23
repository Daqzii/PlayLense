import XCTest
import PlayLenseCore

final class MatchEngineTests: XCTestCase {
    let matchId = UUID()

    func event(_ type: EventType, side: Side = .wir, period: Int = 1, second: Int, zone: Zone? = nil, outcome: String? = nil,
               player: UUID? = nil, player2: UUID? = nil, subtype: String? = nil, flag: String? = nil, seq: Int) -> MatchEvent {
        MatchEvent(matchId: matchId, seq: seq, period: period, matchSecond: second, side: side, type: type, subtype: subtype,
                   outcome: outcome, zoneRow: zone?.row, zoneLane: zone?.lane, playerId: player, playerId2: player2, flagKey: flag)
    }

    func testMatchTimeDisplay() {
        XCTAssertEqual(MatchTime(period: 1, second: 27 * 60 + 34).display(), "27:34")
        XCTAssertEqual(MatchTime(period: 1, second: 47 * 60 + 10).display(), "45+2:10")
        XCTAssertEqual(MatchTime(period: 2, second: 5 * 60).display(), "50:00")
        XCTAssertEqual(MatchTime(period: 2, second: 0).minuteLabel(), "46.")
        XCTAssertTrue(MatchTime(period: 1, second: 2800) < MatchTime(period: 2, second: 0))
    }

    func testPitchGeometryRoundTrip() {
        for right in [true, false] {
            for flipped in [true, false] {
                let g = PitchGeometry(attackingRight: right, observerFlipped: flipped)
                for c in 0..<3 {
                    for r in 0..<3 {
                        let z = g.zone(column: c, row: r)
                        let cell = g.cell(for: z)
                        XCTAssertEqual(cell.column, c)
                        XCTAssertEqual(cell.row, r)
                    }
                }
            }
        }
        let g = PitchGeometry(attackingRight: true)
        XCTAssertEqual(g.zone(column: 2, row: 0), Zone(row: .angriffsdrittel, lane: .links))
        XCTAssertEqual(g.zone(column: 0, row: 2), Zone(row: .eigenesDrittel, lane: .rechts))
        let second = PitchGeometry(attackDirectionFirstHalf: .rechts, period: 2, observerFlipped: false)
        XCTAssertFalse(second.attackingRight)
    }

    func testClockStates() {
        var p1 = MatchPeriod(matchId: matchId, number: 1)
        let p2 = MatchPeriod(matchId: matchId, number: 2)
        XCTAssertEqual(MatchClock.state(periods: [p1, p2], status: .geplant), .notStarted)
        let kickoff = Date(timeIntervalSince1970: 1_000_000)
        p1.startedAt = kickoff
        let state = MatchClock.state(periods: [p1, p2], status: .laeuft, now: kickoff.addingTimeInterval(125))
        XCTAssertEqual(state, .running(period: 1, elapsed: 125))
        p1.endedAt = kickoff.addingTimeInterval(2760)
        XCTAssertEqual(MatchClock.state(periods: [p1, p2], status: .laeuft, now: kickoff.addingTimeInterval(3000)), .paused(afterPeriod: 1))
        XCTAssertEqual(MatchClock.currentTime(periods: [p1, p2], status: .laeuft, now: kickoff.addingTimeInterval(3000)), MatchTime(period: 1, second: 2760))
        XCTAssertEqual(MatchClock.nextPeriodNumber(periods: [p1, p2]), 2)
        XCTAssertEqual(MatchClock.state(periods: [p1, p2], status: .beendet), .finished)
    }

    func testLineupWithRollingSubstitutionAndRedCard() {
        let a = UUID(), b = UUID(), c = UUID()
        let lineup = [
            MatchLineup(matchId: matchId, playerId: a, role: .start, positionKey: .st),
            MatchLineup(matchId: matchId, playerId: b, role: .start, positionKey: .dm),
            MatchLineup(matchId: matchId, playerId: c, role: .bank),
        ]
        var events = [
            event(.wechsel, second: 3000, player: a, player2: c, seq: 1),
        ]
        var s = LineupEngine.state(lineup: lineup, events: events)
        XCTAssertEqual(s.position(of: c), .st)
        XCTAssertTrue(s.bench.contains(a))
        events.append(event(.wechsel, period: 2, second: 600, player: c, player2: a, seq: 2))
        s = LineupEngine.state(lineup: lineup, events: events)
        XCTAssertEqual(s.position(of: a), .st, "Rückwechsel muss den Spieler wieder auf den Platz bringen")
        XCTAssertTrue(s.bench.contains(c))
        events.append(event(.karte, period: 2, second: 900, player: b, subtype: CardType.rot.rawValue, seq: 3))
        s = LineupEngine.state(lineup: lineup, events: events)
        XCTAssertTrue(s.sentOff.contains(b))
        XCTAssertFalse(s.onPitch.contains(b))
        XCTAssertNil(s.position(of: b))

        let kickoff = Date(timeIntervalSince1970: 1_000_000)
        let periods = [
            MatchPeriod(matchId: matchId, number: 1, startedAt: kickoff, endedAt: kickoff.addingTimeInterval(2700)),
            MatchPeriod(matchId: matchId, number: 2, startedAt: kickoff.addingTimeInterval(3600), endedAt: kickoff.addingTimeInterval(6300)),
        ]
        let secs = LineupEngine.secondsPlayed(lineup: lineup, events: events, periods: periods, status: .beendet)
        // a: 0–3000 auf dem Platz, ab 3300 (HZ2 10:00) wieder bis Ende 5400.
        XCTAssertEqual(secs[a], 3000 + 2100)
        // b: bis zur Roten Karte bei HZ2 15:00 = absolut 3600.
        XCTAssertEqual(secs[b], 3600)
        // c: 3000–3300.
        XCTAssertEqual(secs[c], 300)
    }

    func testStatsAndReport() {
        let p9 = UUID()
        var events: [MatchEvent] = []
        var seq = 1
        for i in 0..<7 {
            events.append(event(.ballverlust, second: 100 * i, zone: Zone(row: .mittelfeld, lane: .zentrum), seq: seq)); seq += 1
        }
        for i in 0..<5 {
            events.append(event(.ballverlust, second: 1000 + 50 * i, zone: Zone(row: .eigenesDrittel, lane: .links), seq: seq)); seq += 1
        }
        events.append(event(.abschluss, second: 1500, zone: Zone(row: .angriffsdrittel, lane: .zentrum), outcome: "tor", player: p9, seq: seq)); seq += 1
        events.append(event(.abschluss, second: 1600, zone: Zone(row: .angriffsdrittel, lane: .zentrum), outcome: "vorbei", player: p9, seq: seq)); seq += 1
        events.append(event(.abschluss, side: .gegner, second: 1700, zone: Zone(row: .eigenesDrittel, lane: .zentrum), outcome: "aufs_tor", seq: seq)); seq += 1
        for i in 0..<6 {
            events.append(event(.angriff, side: .gegner, second: 1800 + 30 * i, zone: Zone(row: .angriffsdrittel, lane: .links), seq: seq)); seq += 1
        }
        events.append(event(.angriff, side: .gegner, second: 2100, zone: Zone(row: .angriffsdrittel, lane: .rechts), seq: seq)); seq += 1
        for i in 0..<3 {
            events.append(event(.flag, second: 2200 + i, flag: "def_zentrum_offen", seq: seq)); seq += 1
        }
        var deleted = event(.abschluss, second: 2300, outcome: "tor", seq: seq); seq += 1
        deleted.isDeleted = true
        events.append(deleted)

        let stats = MatchStats.compute(events: events)
        XCTAssertEqual(stats.ballLosses.wir, 12)
        XCTAssertEqual(stats.ballLossesCentre, 7)
        XCTAssertEqual(stats.ballLossesBuildUp, 5)
        XCTAssertEqual(stats.shots.wir, 2)
        XCTAssertEqual(stats.goals.wir, 1, "Gelöschte Events zählen nicht")
        XCTAssertEqual(stats.shotsOnTarget.gegner, 1)
        XCTAssertEqual(stats.attackShares(.gegner)[.links], 86)
        XCTAssertEqual(stats.playerCounts[p9]?.goals, 1)
        XCTAssertEqual(stats.flagCounts["def_zentrum_offen"], 3)

        let firstHalfOnly = MatchStats.compute(events: events, window: TimeWindow(start: nil, end: MatchTime(period: 1, second: 1000)))
        XCTAssertEqual(firstHalfOnly.ballLosses.wir, 8)

        let match = Match(seasonId: UUID(), kickoffPlanned: Date(), opponentName: "SV Test")
        let report = ReportBuilder.build(kind: .halbzeit, teamName: "TSV", match: match, events: events, insights: [])
        XCTAssertEqual(report.score.wir, 1)
        XCTAssertTrue(report.findings.contains { $0.id == "bv_zentrum" })
        XCTAssertTrue(report.findings.contains { $0.id == "bv_aufbau" })
        XCTAssertTrue(report.findings.contains { $0.id == "gegner_seite" })
        XCTAssertTrue(report.findings.contains { $0.id == "flag_def_zentrum_offen" })
        XCTAssertFalse(report.plainText().isEmpty)
        let stored = MatchReport.make(matchId: matchId, payload: report)
        XCTAssertEqual(stored.payload()?.findings.count, report.findings.count)
    }

    func testLiveInsightClusterAndCooldown() {
        var events: [MatchEvent] = []
        for i in 0..<5 {
            events.append(event(.ballverlust, second: 60 * i, zone: Zone(row: .mittelfeld, lane: .links), seq: i + 1))
        }
        let timeline = PeriodTimeline(durations: [1: 300, 2: 0])
        let now = MatchTime(period: 1, second: 300)
        let fresh = LiveInsightEngine.evaluate(matchId: matchId, events: events, now: now, timeline: timeline, existing: [])
        XCTAssertEqual(fresh.count, 1)
        XCTAssertTrue(fresh[0].text.contains("5 der letzten 5"))
        let again = LiveInsightEngine.evaluate(matchId: matchId, events: events, now: MatchTime(period: 1, second: 400), timeline: timeline, existing: fresh)
        XCTAssertTrue(again.isEmpty, "Cooldown muss die Wiederholung verhindern")
    }
}
