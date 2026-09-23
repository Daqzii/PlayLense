import Foundation
import Observation
import PlayLenseCore
import PlayLenseData

/// Zentraler Zustand der App: Datenbank, Team, Saison, Listen. Alles offline, alles lokal.
@MainActor
@Observable
public final class AppModel {
    public let db: AppDatabase
    public let exercises: ExerciseLibrary
    public private(set) var team: Team
    public private(set) var season: Season
    public private(set) var players: [Player] = []
    public private(set) var matches: [Match] = []
    public var lastError: String?
    public var activeSession: MatchSession?

    public init(db: AppDatabase, exercises: ExerciseLibrary) throws {
        self.db = db
        self.exercises = exercises
        let (t, s) = try db.ensureTeamAndSeason()
        self.team = t
        self.season = s
        reload()
    }

    /// Standardstart: Datenbank und Übungsbibliothek aus Application Support.
    public static func live() throws -> AppModel {
        try AppModel(db: try AppDatabase.openDefault(), exercises: try ExerciseLibrary.live())
    }

    public func reload() {
        do {
            players = try db.fetchPlayers(teamId: team.id, includeInactive: true)
            matches = try db.fetchMatches(seasonId: season.id)
        } catch {
            lastError = error.localizedDescription
        }
    }

    public var activePlayers: [Player] { players.filter { $0.status != .inaktiv } }

    public func player(_ id: UUID) -> Player? { players.first { $0.id == id } }

    // MARK: Team

    public func updateTeam(name: String, shortName: String, colorHex: String) {
        var t = team
        t.name = name
        t.shortName = shortName
        t.colorHex = colorHex
        run { try db.saveTeam(t); team = t }
    }

    // MARK: Spieler

    public func savePlayer(_ p: Player) {
        run { try db.savePlayer(p); reload() }
    }

    public func deletePlayer(_ p: Player) {
        run { try db.deletePlayer(id: p.id); reload() }
    }

    // MARK: Spiele

    public func saveMatch(_ m: Match, lineup: [MatchLineup]?) {
        run { try db.saveMatch(m, lineup: lineup); reload() }
    }

    public func deleteMatch(_ m: Match) {
        run { try db.deleteMatch(id: m.id); reload() }
    }

    public func openMatchCenter(_ m: Match) {
        run {
            activeSession = try MatchSession(db: db, matchId: m.id, teamName: team.shortName)
        }
    }

    public func closeMatchCenter() {
        activeSession = nil
        reload()
    }

    /// Beim Start: Läuft ein Spiel? Dann direkt hinein.
    public func resumeRunningMatchIfAny() {
        run {
            if let m = try db.fetchRunningMatch() {
                activeSession = try MatchSession(db: db, matchId: m.id, teamName: team.shortName)
            }
        }
    }

    // MARK: Export

    public func exportBundle() -> URL? {
        var url: URL?
        run {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PlayLenseExport", isDirectory: true)
            url = try ExportService(database: db).exportBundle(to: dir)
        }
        return url
    }

    public func importBundle(from url: URL) -> ImportSummary? {
        var summary: ImportSummary?
        run {
            summary = try ExportService(database: db).importBundle(from: url)
            let (t, s) = try db.ensureTeamAndSeason()
            team = t
            season = s
            reload()
        }
        return summary
    }

    func run(_ body: () throws -> Void) {
        do { try body() } catch { lastError = error.localizedDescription }
    }
}
