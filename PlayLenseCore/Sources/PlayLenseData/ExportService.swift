import Foundation
import GRDB
import ZIPFoundation
import PlayLenseCore

/// Vollständiger Datenbestand als Codable-Struktur. Grundlage des `.playlense`-Bundles.
public struct ExportSnapshot: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var appVersion: String
    public var exportedAt: Date
    public var teams: [Team]
    public var seasons: [Season]
    public var players: [Player]
    public var matches: [Match]
    public var periods: [MatchPeriod]
    public var lineups: [MatchLineup]
    public var events: [MatchEvent]
    public var insights: [MatchInsight]
    public var reports: [MatchReport]
}

public struct ImportSummary: Sendable {
    public var inserted = 0
    public var updated = 0
    public var skipped = 0
}

/// Export als ZIP mit Datenbank-Snapshot und lesbarem JSON; Import mit Merge nach UUID.
public struct ExportService: Sendable {
    let database: AppDatabase
    let appVersion: String

    public init(database: AppDatabase, appVersion: String = "0.1.0") {
        self.database = database
        self.appVersion = appVersion
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func snapshot() throws -> ExportSnapshot {
        try database.dbQueue.read { db in
            ExportSnapshot(
                appVersion: appVersion,
                exportedAt: Date(),
                teams: try Team.fetchAll(db),
                seasons: try Season.fetchAll(db),
                players: try Player.fetchAll(db),
                matches: try Match.fetchAll(db),
                periods: try MatchPeriod.fetchAll(db),
                lineups: try MatchLineup.fetchAll(db),
                events: try MatchEvent.fetchAll(db),
                insights: try MatchInsight.fetchAll(db),
                reports: try MatchReport.fetchAll(db)
            )
        }
    }

    /// Schreibt `<name>.playlense` (ZIP) in das Zielverzeichnis und liefert die URL.
    public func exportBundle(to directory: URL, name: String? = nil) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let bundleName = name ?? "PlayLense-\(stamp)"
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = work.appendingPathComponent(bundleName, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("json"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let snap = try snapshot()
        let enc = Self.encoder()
        try enc.encode(snap).write(to: root.appendingPathComponent("json/snapshot.json"))
        let manifest: [String: String] = [
            "app_version": appVersion,
            "schema_version": "1",
            "exported_at": ISO8601DateFormatter().string(from: snap.exportedAt),
            "team": snap.teams.first?.name ?? "",
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: root.appendingPathComponent("manifest.json"))
        if database.databaseURL != nil {
            let dbCopy = root.appendingPathComponent("playlense.sqlite")
            try database.dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: "VACUUM INTO ?", arguments: [dbCopy.path])
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let zipURL = directory.appendingPathComponent("\(bundleName).playlense")
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.zipItem(at: root, to: zipURL, shouldKeepParent: false)
        return zipURL
    }

    /// Liest ein `.playlense`-Bundle oder eine `snapshot.json` und führt die Daten nach UUID zusammen.
    /// Bei gleicher ID gewinnt der neuere `updatedAt`-Stand; Tabellen ohne `updatedAt` werden nur ergänzt.
    @discardableResult
    public func importBundle(from url: URL) throws -> ImportSummary {
        let data: Data
        if url.pathExtension.lowercased() == "json" {
            data = try Data(contentsOf: url)
        } else {
            let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: work) }
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: url, to: work)
            guard let json = Self.findFile(named: "snapshot.json", in: work) else {
                throw DataError.notFound("json/snapshot.json im Bundle")
            }
            data = try Data(contentsOf: json)
        }
        let snap = try Self.decoder().decode(ExportSnapshot.self, from: data)
        return try merge(snap)
    }

    static func findFile(named name: String, in dir: URL) -> URL? {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return nil }
        for case let u as URL in e where u.lastPathComponent == name { return u }
        return nil
    }

    public func merge(_ snap: ExportSnapshot) throws -> ImportSummary {
        var summary = ImportSummary()
        try database.dbQueue.write { db in
            func upsertTimestamped<R: PersistableRecord & FetchableRecord & Identifiable>(_ rows: [R], updatedAt: (R) -> Date) throws where R.ID == UUID {
                for r in rows {
                    if let existing = try R.fetchOne(db, key: r.id) {
                        if updatedAt(r) > updatedAt(existing) { try r.update(db); summary.updated += 1 } else { summary.skipped += 1 }
                    } else {
                        try r.insert(db); summary.inserted += 1
                    }
                }
            }
            func insertMissing<R: PersistableRecord & FetchableRecord & Identifiable>(_ rows: [R]) throws where R.ID == UUID {
                for r in rows {
                    if try R.exists(db, key: r.id) { summary.skipped += 1 } else { try r.insert(db); summary.inserted += 1 }
                }
            }
            try upsertTimestamped(snap.teams, updatedAt: { $0.updatedAt })
            try upsertTimestamped(snap.seasons, updatedAt: { $0.updatedAt })
            try upsertTimestamped(snap.players, updatedAt: { $0.updatedAt })
            try upsertTimestamped(snap.matches, updatedAt: { $0.updatedAt })
            try insertMissing(snap.periods)
            try insertMissing(snap.lineups)
            try upsertTimestamped(snap.events, updatedAt: { $0.editedAt ?? $0.createdAt })
            try insertMissing(snap.insights)
            try insertMissing(snap.reports)
        }
        return summary
    }
}
