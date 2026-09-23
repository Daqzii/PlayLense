import Foundation
import GRDB
import PlayLenseCore

/// SQLite-Datenbank der App. Eine Datei in Application Support, WAL-Modus, versionierte Migrationen.
public final class AppDatabase: Sendable {
    public let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try Self.migrator.migrate(dbQueue)
    }

    /// Standarddatei unter Application Support/PlayLense/playlense.sqlite.
    public static func openDefault() throws -> AppDatabase {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PlayLense", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try open(at: dir.appendingPathComponent("playlense.sqlite"))
    }

    public static func open(at url: URL) throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
        return try AppDatabase(dbQueue: queue)
    }

    /// Für Tests und Vorschauen.
    public static func inMemory() throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return try AppDatabase(dbQueue: try DatabaseQueue(configuration: config))
    }

    public var databaseURL: URL? {
        let path = dbQueue.path
        return path.isEmpty || path == ":memory:" ? nil : URL(fileURLWithPath: path)
    }

    // MARK: Migrationen

    static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_stammdaten_und_spiel") { db in
            try db.create(table: "team") { t in
                t.column("id", .blob).primaryKey()
                t.column("name", .text).notNull()
                t.column("shortName", .text).notNull()
                t.column("colorHex", .text).notNull()
                t.column("isActive", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "season") { t in
                t.column("id", .blob).primaryKey()
                t.column("teamId", .blob).notNull().references("team", onDelete: .cascade)
                t.column("label", .text).notNull()
                t.column("startsOn", .datetime)
                t.column("endsOn", .datetime)
                t.column("isCurrent", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "player") { t in
                t.column("id", .blob).primaryKey()
                t.column("teamId", .blob).notNull().references("team", onDelete: .cascade)
                t.column("firstName", .text).notNull()
                t.column("lastName", .text).notNull()
                t.column("nickname", .text)
                t.column("number", .integer)
                t.column("primaryPosition", .text)
                t.column("secondaryPositions", .text).notNull().defaults(to: "[]")
                t.column("foot", .text).notNull()
                t.column("birthYear", .integer)
                t.column("status", .text).notNull()
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "match") { t in
                t.column("id", .blob).primaryKey()
                t.column("seasonId", .blob).notNull().references("season", onDelete: .cascade)
                t.column("kickoffPlanned", .datetime).notNull()
                t.column("opponentName", .text).notNull()
                t.column("venue", .text).notNull()
                t.column("competition", .text).notNull()
                t.column("attackDirectionFirstHalf", .text).notNull()
                t.column("observerSideFlipped", .boolean).notNull().defaults(to: false)
                t.column("trackingProfile", .text).notNull()
                t.column("formation", .text).notNull()
                t.column("status", .text).notNull()
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "matchPeriod") { t in
                t.column("id", .blob).primaryKey()
                t.column("matchId", .blob).notNull().references("match", onDelete: .cascade).indexed()
                t.column("number", .integer).notNull()
                t.column("startedAt", .datetime)
                t.column("endedAt", .datetime)
                t.column("nominalSeconds", .integer).notNull().defaults(to: 2700)
            }
            try db.create(table: "matchLineup") { t in
                t.column("id", .blob).primaryKey()
                t.column("matchId", .blob).notNull().references("match", onDelete: .cascade).indexed()
                t.column("playerId", .blob).notNull().references("player", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("positionKey", .text)
                t.column("numberInMatch", .integer)
            }
            try db.create(table: "matchEvent") { t in
                t.column("id", .blob).primaryKey()
                t.column("matchId", .blob).notNull().references("match", onDelete: .cascade)
                t.column("seq", .integer).notNull()
                t.column("period", .integer).notNull()
                t.column("matchSecond", .integer).notNull()
                t.column("occurredAt", .datetime).notNull()
                t.column("side", .text).notNull()
                t.column("type", .text).notNull()
                t.column("subtype", .text)
                t.column("outcome", .text)
                t.column("zoneRow", .text)
                t.column("zoneLane", .text)
                t.column("zoneX", .double)
                t.column("zoneY", .double)
                t.column("playerId", .blob)
                t.column("playerId2", .blob)
                t.column("positionKey", .text)
                t.column("flagKey", .text)
                t.column("note", .text)
                t.column("isDeleted", .boolean).notNull().defaults(to: false)
                t.column("editedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_matchEvent_match_seq", on: "matchEvent", columns: ["matchId", "seq"])
            try db.create(table: "matchInsight") { t in
                t.column("id", .blob).primaryKey()
                t.column("matchId", .blob).notNull().references("match", onDelete: .cascade).indexed()
                t.column("period", .integer).notNull()
                t.column("matchSecond", .integer).notNull()
                t.column("ruleId", .text).notNull()
                t.column("text", .text).notNull()
                t.column("severity", .text).notNull()
                t.column("acknowledged", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "matchReport") { t in
                t.column("id", .blob).primaryKey()
                t.column("matchId", .blob).notNull().references("match", onDelete: .cascade).indexed()
                t.column("kind", .text).notNull()
                t.column("generatedAt", .datetime).notNull()
                t.column("payloadJSON", .text).notNull()
            }
            try db.create(table: "appMeta") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }
        return m
    }
}

// MARK: - Record-Konformanzen

extension Team: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "team"
}
extension Season: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "season"
}
extension Player: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "player"
}
extension Match: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "match"
}
extension MatchPeriod: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "matchPeriod"
}
extension MatchLineup: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "matchLineup"
}
extension MatchEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "matchEvent"
}
extension MatchInsight: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "matchInsight"
}
extension MatchReport: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "matchReport"
}

struct AppMeta: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "appMeta"
    var key: String
    var value: String
}
