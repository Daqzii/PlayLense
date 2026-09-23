import Foundation
import GRDB
import PlayLenseCore

public enum DataError: Error, LocalizedError {
    case notFound(String)
    public var errorDescription: String? {
        switch self {
        case .notFound(let what): return "\(what) nicht gefunden."
        }
    }
}

// MARK: - Team und Saison

extension AppDatabase {
    /// Liefert das aktive Team und die aktuelle Saison, legt beides beim ersten Start an.
    public func ensureTeamAndSeason(defaultName: String = "TSV Thundorf", defaultShort: String = "TSV") throws -> (Team, Season) {
        try dbQueue.write { db in
            let team: Team
            if let t = try Team.filter(Column("isActive") == true).fetchOne(db) {
                team = t
            } else {
                team = Team(name: defaultName, shortName: defaultShort)
                try team.insert(db)
            }
            let season: Season
            if let s = try Season.filter(Column("teamId") == team.id && Column("isCurrent") == true).fetchOne(db) {
                season = s
            } else {
                season = Season(teamId: team.id, label: Season.defaultLabel())
                try season.insert(db)
            }
            return (team, season)
        }
    }

    public func saveTeam(_ team: Team) throws {
        var t = team
        t.updatedAt = Date()
        try dbQueue.write { db in try t.save(db) }
    }

    public func fetchSeasons(teamId: UUID) throws -> [Season] {
        try dbQueue.read { db in
            try Season.filter(Column("teamId") == teamId).order(Column("label").desc).fetchAll(db)
        }
    }

    public func saveSeason(_ season: Season) throws {
        var s = season
        s.updatedAt = Date()
        try dbQueue.write { db in
            if s.isCurrent {
                try db.execute(sql: "UPDATE season SET isCurrent = 0 WHERE teamId = ?", arguments: [s.teamId])
            }
            try s.save(db)
        }
    }
}

// MARK: - Spieler

extension AppDatabase {
    public func fetchPlayers(teamId: UUID, includeInactive: Bool = false) throws -> [Player] {
        try dbQueue.read { db in
            var q = Player.filter(Column("teamId") == teamId)
            if !includeInactive { q = q.filter(Column("status") != PlayerStatus.inaktiv.rawValue) }
            return try q.order(Column("number").ascNullsLast, Column("lastName")).fetchAll(db)
        }
    }

    public func fetchPlayers(ids: [UUID]) throws -> [Player] {
        try dbQueue.read { db in try Player.filter(ids.contains(Column("id"))).fetchAll(db) }
    }

    public func savePlayer(_ player: Player) throws {
        var p = player
        p.updatedAt = Date()
        try dbQueue.write { db in try p.save(db) }
    }

    public func deletePlayer(id: UUID) throws {
        _ = try dbQueue.write { db in try Player.deleteOne(db, key: id) }
    }
}

// MARK: - Spiele

public struct MatchBundle: Sendable {
    public var match: Match
    public var periods: [MatchPeriod]
    public var lineup: [MatchLineup]
    public var events: [MatchEvent]
    public var insights: [MatchInsight]
    public var reports: [MatchReport]

    public init(match: Match, periods: [MatchPeriod], lineup: [MatchLineup], events: [MatchEvent], insights: [MatchInsight], reports: [MatchReport]) {
        self.match = match
        self.periods = periods
        self.lineup = lineup
        self.events = events
        self.insights = insights
        self.reports = reports
    }
}

extension AppDatabase {
    public func fetchMatches(seasonId: UUID) throws -> [Match] {
        try dbQueue.read { db in
            try Match.filter(Column("seasonId") == seasonId).order(Column("kickoffPlanned").desc).fetchAll(db)
        }
    }

    public func fetchMatch(id: UUID) throws -> Match? {
        try dbQueue.read { db in try Match.fetchOne(db, key: id) }
    }

    /// Das Spiel mit Status „läuft“, falls die App mitten im Spiel beendet wurde.
    public func fetchRunningMatch() throws -> Match? {
        try dbQueue.read { db in try Match.filter(Column("status") == MatchStatus.laeuft.rawValue).fetchOne(db) }
    }

    public func fetchMatchBundle(id: UUID) throws -> MatchBundle {
        try dbQueue.read { db in
            guard let match = try Match.fetchOne(db, key: id) else { throw DataError.notFound("Spiel") }
            return MatchBundle(
                match: match,
                periods: try MatchPeriod.filter(Column("matchId") == id).order(Column("number")).fetchAll(db),
                lineup: try MatchLineup.filter(Column("matchId") == id).fetchAll(db),
                events: try MatchEvent.filter(Column("matchId") == id).order(Column("seq")).fetchAll(db),
                insights: try MatchInsight.filter(Column("matchId") == id).order(Column("period"), Column("matchSecond")).fetchAll(db),
                reports: try MatchReport.filter(Column("matchId") == id).order(Column("generatedAt")).fetchAll(db)
            )
        }
    }

    /// Legt ein Spiel mit Perioden und Aufstellung an oder aktualisiert es.
    public func saveMatch(_ match: Match, lineup: [MatchLineup]? = nil, periodCount: Int = 2, nominalSeconds: Int = 2700) throws {
        var m = match
        m.updatedAt = Date()
        try dbQueue.write { db in
            try m.save(db)
            let existing = try MatchPeriod.filter(Column("matchId") == m.id).fetchCount(db)
            if existing == 0 {
                for n in 1...periodCount {
                    try MatchPeriod(matchId: m.id, number: n, nominalSeconds: nominalSeconds).insert(db)
                }
            }
            if let lineup = lineup {
                try MatchLineup.filter(Column("matchId") == m.id).deleteAll(db)
                for var l in lineup {
                    l.matchId = m.id
                    try l.insert(db)
                }
            }
        }
    }

    public func deleteMatch(id: UUID) throws {
        _ = try dbQueue.write { db in try Match.deleteOne(db, key: id) }
    }

    public func savePeriod(_ period: MatchPeriod) throws {
        try dbQueue.write { db in try period.save(db) }
    }

    /// Fügt eine Verlängerungsperiode hinzu (Pokal).
    public func addPeriod(matchId: UUID, nominalSeconds: Int = 900) throws -> MatchPeriod {
        try dbQueue.write { db in
            let maxNumber = try Int.fetchOne(db, sql: "SELECT MAX(number) FROM matchPeriod WHERE matchId = ?", arguments: [matchId]) ?? 0
            let p = MatchPeriod(matchId: matchId, number: maxNumber + 1, nominalSeconds: nominalSeconds)
            try p.insert(db)
            return p
        }
    }

    public func setMatchStatus(id: UUID, status: MatchStatus) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE match SET status = ?, updatedAt = ? WHERE id = ?", arguments: [status.rawValue, Date(), id])
        }
    }

    // MARK: Events

    /// Hängt ein Event an das Log an und vergibt die nächste laufende Nummer. Eine Transaktion pro Tap.
    @discardableResult
    public func appendEvent(_ event: MatchEvent) throws -> MatchEvent {
        try dbQueue.write { db in
            var e = event
            let maxSeq = try Int.fetchOne(db, sql: "SELECT MAX(seq) FROM matchEvent WHERE matchId = ?", arguments: [e.matchId]) ?? 0
            e.seq = maxSeq + 1
            try e.insert(db)
            try db.execute(sql: "UPDATE match SET updatedAt = ? WHERE id = ?", arguments: [Date(), e.matchId])
            return e
        }
    }

    public func updateEvent(_ event: MatchEvent) throws {
        var e = event
        e.editedAt = Date()
        try dbQueue.write { db in try e.update(db) }
    }

    public func setEventDeleted(id: UUID, deleted: Bool) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE matchEvent SET isDeleted = ?, editedAt = ? WHERE id = ?", arguments: [deleted, Date(), id])
        }
    }

    public func fetchEvents(matchId: UUID) throws -> [MatchEvent] {
        try dbQueue.read { db in try MatchEvent.filter(Column("matchId") == matchId).order(Column("seq")).fetchAll(db) }
    }

    public func insertInsights(_ insights: [MatchInsight]) throws {
        guard !insights.isEmpty else { return }
        try dbQueue.write { db in for i in insights { try i.insert(db) } }
    }

    public func saveReport(_ report: MatchReport) throws {
        try dbQueue.write { db in
            try MatchReport.filter(Column("matchId") == report.matchId && Column("kind") == report.kind.rawValue).deleteAll(db)
            try report.insert(db)
        }
    }

    // MARK: Saisonstatistik

    /// Alle Events beendeter Spiele einer Saison, gruppiert nach Spiel. Grundlage für Dashboard und Baselines.
    public func fetchSeasonEvents(seasonId: UUID) throws -> [UUID: [MatchEvent]] {
        try dbQueue.read { db in
            let matches = try Match.filter(Column("seasonId") == seasonId && Column("status") == MatchStatus.beendet.rawValue).fetchAll(db)
            var out: [UUID: [MatchEvent]] = [:]
            for m in matches {
                out[m.id] = try MatchEvent.filter(Column("matchId") == m.id && Column("isDeleted") == false).order(Column("seq")).fetchAll(db)
            }
            return out
        }
    }
}

// MARK: - Meta

extension AppDatabase {
    public func meta(_ key: String) throws -> String? {
        try dbQueue.read { db in try AppMeta.fetchOne(db, key: key)?.value }
    }

    public func setMeta(_ key: String, _ value: String) throws {
        try dbQueue.write { db in try AppMeta(key: key, value: value).save(db) }
    }
}
