import XCTest
import PlayLenseCore
import PlayLenseData

final class DatabaseTests: XCTestCase {
    func testTeamSeasonPlayersAndMatchFlow() throws {
        let db = try AppDatabase.inMemory()
        let (team, season) = try db.ensureTeamAndSeason()
        let (team2, season2) = try db.ensureTeamAndSeason()
        XCTAssertEqual(team.id, team2.id)
        XCTAssertEqual(season.id, season2.id)

        let p9 = Player(teamId: team.id, firstName: "Max", lastName: "Muster", number: 9, primaryPosition: .st)
        let p6 = Player(teamId: team.id, firstName: "Leon", lastName: "Sechs", number: 6, primaryPosition: .dm)
        try db.savePlayer(p9)
        try db.savePlayer(p6)
        XCTAssertEqual(try db.fetchPlayers(teamId: team.id).map(\.number), [6, 9])

        let match = Match(seasonId: season.id, kickoffPlanned: Date(), opponentName: "SV Test")
        let lineup = [
            MatchLineup(matchId: match.id, playerId: p9.id, role: .start, positionKey: .st),
            MatchLineup(matchId: match.id, playerId: p6.id, role: .bank),
        ]
        try db.saveMatch(match, lineup: lineup)
        var bundle = try db.fetchMatchBundle(id: match.id)
        XCTAssertEqual(bundle.periods.count, 2)
        XCTAssertEqual(bundle.lineup.count, 2)

        var p1 = bundle.periods[0]
        p1.startedAt = Date()
        try db.savePeriod(p1)
        try db.setMatchStatus(id: match.id, status: .laeuft)
        XCTAssertEqual(try db.fetchRunningMatch()?.id, match.id)

        let e1 = try db.appendEvent(MatchEvent(matchId: match.id, seq: 0, period: 1, matchSecond: 30, side: .wir, type: .ballverlust, zoneRow: .mittelfeld, zoneLane: .zentrum))
        let e2 = try db.appendEvent(MatchEvent(matchId: match.id, seq: 0, period: 1, matchSecond: 90, side: .wir, type: .abschluss, outcome: "tor", playerId: p9.id))
        XCTAssertEqual(e1.seq, 1)
        XCTAssertEqual(e2.seq, 2)
        try db.setEventDeleted(id: e1.id, deleted: true)
        bundle = try db.fetchMatchBundle(id: match.id)
        XCTAssertEqual(bundle.events.count, 2)
        XCTAssertTrue(bundle.events[0].isDeleted)
        XCTAssertEqual(MatchStats.compute(events: bundle.events).goals.wir, 1)

        let payload = ReportBuilder.build(kind: .halbzeit, teamName: team.shortName, match: match, events: bundle.events, insights: [])
        try db.saveReport(MatchReport.make(matchId: match.id, payload: payload))
        try db.saveReport(MatchReport.make(matchId: match.id, payload: payload))
        XCTAssertEqual(try db.fetchMatchBundle(id: match.id).reports.count, 1, "Pro Art nur ein Bericht")

        try db.deleteMatch(id: match.id)
        XCTAssertEqual(try db.fetchEvents(matchId: match.id).count, 0, "Cascade löscht Events")
    }

    func testSnapshotMergeIntoSecondDatabase() throws {
        let source = try AppDatabase.inMemory()
        let (team, season) = try source.ensureTeamAndSeason()
        try source.savePlayer(Player(teamId: team.id, firstName: "A", lastName: "B", number: 1))
        let match = Match(seasonId: season.id, kickoffPlanned: Date(), opponentName: "X")
        try source.saveMatch(match, lineup: [])
        _ = try source.appendEvent(MatchEvent(matchId: match.id, seq: 0, period: 1, matchSecond: 10, side: .gegner, type: .abschluss, outcome: "vorbei"))

        let service = ExportService(database: source)
        let snap = try service.snapshot()
        XCTAssertEqual(snap.players.count, 1)
        XCTAssertEqual(snap.events.count, 1)

        let target = try AppDatabase.inMemory()
        let summary = try ExportService(database: target).merge(snap)
        XCTAssertEqual(summary.inserted, 1 + 1 + 1 + 1 + 2 + 1) // team, season, player, match, 2 periods, event
        let again = try ExportService(database: target).merge(snap)
        XCTAssertEqual(again.inserted, 0)
        XCTAssertEqual(try target.fetchPlayers(teamId: team.id).count, 1)
        XCTAssertEqual(try target.fetchEvents(matchId: match.id).count, 1)
    }
}
