import Foundation
import Observation

// MARK: - Vokabular und Seed-Bundle

public struct TrainingGoal: Codable, Hashable, Sendable, Identifiable {
    public var key: String
    public var label: String
    public var defaultTags: [String]
    public var id: String { key }
}

public struct ExerciseTag: Codable, Hashable, Sendable, Identifiable {
    public var key: String
    public var label: String
    public var category: String
    public var id: String { key }
}

public struct ExerciseVocabulary: Codable, Hashable, Sendable {
    public var goals: [TrainingGoal]
    public var tags: [ExerciseTag]
    public var material: [String]

    public func goal(_ key: String) -> TrainingGoal? { goals.first { $0.key == key } }
    public func tag(_ key: String) -> ExerciseTag? { tags.first { $0.key == key } }
    public func tags(in category: String) -> [ExerciseTag] { tags.filter { $0.category == category } }
}

/// Inhalt von exercises.seed.json, erzeugt durch `python3 tools/exercises.py bundle`.
public struct ExerciseSeedBundle: Codable, Sendable {
    public var schemaVersion: Int
    public var goals: [TrainingGoal]
    public var tags: [ExerciseTag]
    public var material: [String]
    public var exercises: [Exercise]

    public var vocabulary: ExerciseVocabulary {
        ExerciseVocabulary(goals: goals, tags: tags, material: material)
    }

    public static func load(from data: Data) throws -> ExerciseSeedBundle {
        try ExerciseJSON.decoder().decode(ExerciseSeedBundle.self, from: data)
    }

    /// Lädt das mitgelieferte Seed-Bundle aus den Package-Ressourcen.
    public static func loadBundled() throws -> ExerciseSeedBundle {
        guard let url = Bundle.module.url(forResource: "exercises.seed", withExtension: "json") else {
            throw LibraryError.seedMissing
        }
        return try load(from: Data(contentsOf: url))
    }
}

public enum LibraryError: Error, LocalizedError {
    case seedMissing
    case invalid([ValidationIssue])
    case notFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .seedMissing: return "Seed-Datei exercises.seed.json fehlt im Package."
        case .invalid(let issues): return issues.map { "\($0.field): \($0.message)" }.joined(separator: "\n")
        case .notFound(let id): return "Übung \(id) nicht gefunden."
        }
    }
}

// MARK: - Nutzerdatei

/// Was der Nutzer selbst angelegt oder geändert hat. Wird als JSON in Application Support gespeichert.
/// Seed-Übungen bleiben unverändert im Package; eine geänderte Seed-Übung landet mit derselben ID hier
/// und überdeckt das Original. Bis die SQLite-Datenbank (Ausbaustufe 0) steht, ist dies die Persistenz.
public struct UserLibraryFile: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var exercises: [Exercise] = []
    public var hiddenSeedIDs: [UUID] = []

    public init() {}
}

// MARK: - Bibliothek

@MainActor
@Observable
public final class ExerciseLibrary {
    public let vocabulary: ExerciseVocabulary
    public private(set) var seedExercises: [Exercise]
    public private(set) var userFile: UserLibraryFile
    public private(set) var lastError: String?

    private let userFileURL: URL?

    public init(seed: ExerciseSeedBundle, userFile: UserLibraryFile = UserLibraryFile(), userFileURL: URL? = nil) {
        self.vocabulary = seed.vocabulary
        self.seedExercises = seed.exercises
        self.userFile = userFile
        self.userFileURL = userFileURL
    }

    /// Standardinstanz: Seed aus dem Package, Nutzerdatei aus Application Support/PlayLense.
    public static func live() throws -> ExerciseLibrary {
        let seed = try ExerciseSeedBundle.loadBundled()
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
            .appendingPathComponent("PlayLense", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("exercises.user.json")
        var file = UserLibraryFile()
        if let data = try? Data(contentsOf: url) {
            file = try ExerciseJSON.decoder().decode(UserLibraryFile.self, from: data)
        }
        return ExerciseLibrary(seed: seed, userFile: file, userFileURL: url)
    }

    // MARK: Lesen

    /// Alle sichtbaren Übungen: Nutzerübungen überdecken Seed-Übungen mit gleicher ID.
    public var exercises: [Exercise] {
        let hidden = Set(userFile.hiddenSeedIDs)
        let userByID = Dictionary(userFile.exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
        var result: [Exercise] = []
        for seed in seedExercises where !hidden.contains(seed.id) {
            result.append(userByID[seed.id] ?? seed)
        }
        let seedIDs = Set(seedExercises.map(\.id))
        result.append(contentsOf: userFile.exercises.filter { !seedIDs.contains($0.id) })
        return result.filter { !$0.isArchived }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func exercise(id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    public func isSeed(_ id: UUID) -> Bool {
        seedExercises.contains { $0.id == id }
    }

    public struct Query: Hashable, Sendable {
        public var text: String = ""
        public var goal: String? = nil
        public var tag: String? = nil
        public var players: Int? = nil
        public var maxDuration: Int? = nil
        public var onlyFavorites: Bool = false
        public init() {}
    }

    public func search(_ q: Query) -> [Exercise] {
        exercises.filter { ex in
            if q.onlyFavorites && !ex.isFavorite { return false }
            if let g = q.goal, ex.goalPrimary != g, !ex.goalsSecondary.contains(g) { return false }
            if let t = q.tag, !ex.tags.contains(t) { return false }
            if let p = q.players, !(ex.playersMin...ex.playersMax).contains(p) { return false }
            if let d = q.maxDuration, ex.durationMin > d { return false }
            if !q.text.isEmpty {
                let hay = (ex.name + " " + ex.description + " " + ex.tags.joined(separator: " ")).lowercased()
                if !hay.contains(q.text.lowercased()) { return false }
            }
            return true
        }
    }

    // MARK: Schreiben

    public func validate(_ ex: Exercise) -> [ValidationIssue] {
        let others = Set(exercises.filter { $0.id != ex.id }.map(\.slug))
        return ExerciseValidator(vocabulary: vocabulary).validate(ex, existingSlugs: others)
    }

    /// Legt eine Übung an oder überschreibt sie. Wirft bei Validierungsfehlern.
    public func save(_ ex: Exercise) throws {
        let issues = validate(ex)
        guard issues.isEmpty else { throw LibraryError.invalid(issues) }
        if let i = userFile.exercises.firstIndex(where: { $0.id == ex.id }) {
            userFile.exercises[i] = ex
        } else {
            userFile.exercises.append(ex)
        }
        userFile.hiddenSeedIDs.removeAll { $0 == ex.id }
        try persist()
    }

    /// Löscht eine Nutzerübung oder blendet eine Seed-Übung aus.
    public func delete(id: UUID) throws {
        userFile.exercises.removeAll { $0.id == id }
        if isSeed(id), !userFile.hiddenSeedIDs.contains(id) {
            userFile.hiddenSeedIDs.append(id)
        }
        try persist()
    }

    /// Setzt eine geänderte oder ausgeblendete Seed-Übung auf das Original zurück.
    public func resetToSeed(id: UUID) throws {
        guard isSeed(id) else { throw LibraryError.notFound(id) }
        userFile.exercises.removeAll { $0.id == id }
        userFile.hiddenSeedIDs.removeAll { $0 == id }
        try persist()
    }

    public func toggleFavorite(id: UUID) throws {
        guard var ex = exercise(id: id) else { throw LibraryError.notFound(id) }
        ex.isFavorite.toggle()
        try save(ex)
    }

    // MARK: Austausch

    /// Eine Übung als JSON, im selben Format wie die Dateien in content/exercises.
    public func exportJSON(_ ex: Exercise) throws -> Data {
        try ExerciseJSON.encoder().encode(ex)
    }

    /// Liest eine einzelne Übung oder eine Liste von Übungen ein und speichert sie nach Validierung.
    @discardableResult
    public func importJSON(_ data: Data) throws -> [Exercise] {
        let decoder = ExerciseJSON.decoder()
        let list: [Exercise]
        if let many = try? decoder.decode([Exercise].self, from: data) {
            list = many
        } else {
            list = [try decoder.decode(Exercise.self, from: data)]
        }
        for ex in list { try save(ex) }
        return list
    }

    private func persist() throws {
        guard let url = userFileURL else { return }
        let data = try ExerciseJSON.encoder().encode(userFile)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
