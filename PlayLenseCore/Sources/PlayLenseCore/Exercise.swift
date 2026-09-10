import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Eine Trainingsübung. Das JSON-Format ist in docs/02-datenmodell.md und docs/06-uebungen-erfassen.md
/// beschrieben. Schlüssel im JSON sind snake_case, die Codierung läuft über `ExerciseJSON`.
public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var slug: String
    public var name: String
    public var goalPrimary: String
    public var goalsSecondary: [String]
    public var playersMin: Int
    public var playersMax: Int
    public var durationMin: Int
    public var durationMax: Int
    public var intensity: Int
    public var fieldWidthM: Int
    public var fieldLengthM: Int
    public var material: [MaterialItem]
    public var description: String
    public var procedure: String
    public var coachingPoints: [String]
    public var variations: Variations
    public var tags: [String]
    public var animation: ExerciseAnimation?
    public var source: String
    public var isFavorite: Bool
    public var isArchived: Bool

    public init(
        id: UUID? = nil,
        slug: String,
        name: String,
        goalPrimary: String,
        goalsSecondary: [String] = [],
        playersMin: Int,
        playersMax: Int,
        durationMin: Int,
        durationMax: Int,
        intensity: Int,
        fieldWidthM: Int,
        fieldLengthM: Int,
        material: [MaterialItem] = [],
        description: String,
        procedure: String,
        coachingPoints: [String] = [],
        variations: Variations = Variations(),
        tags: [String] = [],
        animation: ExerciseAnimation? = nil,
        source: String = "eigene",
        isFavorite: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id ?? Exercise.stableID(forSlug: slug)
        self.slug = slug
        self.name = name
        self.goalPrimary = goalPrimary
        self.goalsSecondary = goalsSecondary
        self.playersMin = playersMin
        self.playersMax = playersMax
        self.durationMin = durationMin
        self.durationMax = durationMax
        self.intensity = intensity
        self.fieldWidthM = fieldWidthM
        self.fieldLengthM = fieldLengthM
        self.material = material
        self.description = description
        self.procedure = procedure
        self.coachingPoints = coachingPoints
        self.variations = variations
        self.tags = tags
        self.animation = animation
        self.source = source
        self.isFavorite = isFavorite
        self.isArchived = isArchived
    }

    /// Leere Vorlage für den Editor.
    public static func blank() -> Exercise {
        Exercise(
            id: UUID(),
            slug: "",
            name: "",
            goalPrimary: "spielaufbau",
            playersMin: 8,
            playersMax: 12,
            durationMin: 10,
            durationMax: 20,
            intensity: 3,
            fieldWidthM: 30,
            fieldLengthM: 30,
            material: [MaterialItem(item: "huetchen", count: 4), MaterialItem(item: "baelle", count: 6)],
            description: "",
            procedure: "",
            coachingPoints: ["", "", ""],
            variations: Variations(easier: [""], harder: [""]),
            tags: []
        )
    }

    /// UUID v5 aus dem Slug, derselbe Namensraum wie in tools/exercises.py. Gleicher Slug → gleiche ID.
    public static func stableID(forSlug slug: String) -> UUID {
        #if canImport(CryptoKit)
        let namespace = UUID(uuidString: "7d0a2c2e-4d3b-4a5e-9c1f-3e2f9b6a1d10")!
        var data = Data(withUnsafeBytes(of: namespace.uuid) { Array($0) })
        data.append(contentsOf: Array(slug.utf8))
        var hash = Array(Insecure.SHA1.hash(data: data)).prefix(16).map { $0 }
        hash[6] = (hash[6] & 0x0F) | 0x50 // Version 5
        hash[8] = (hash[8] & 0x3F) | 0x80 // Variant RFC 4122
        let uuid = (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                    hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15])
        return UUID(uuid: uuid)
        #else
        return UUID()
        #endif
    }

    // MARK: Codable mit Defaults für optionale Felder

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, goalPrimary, goalsSecondary, playersMin, playersMax, durationMin, durationMax
        case intensity, fieldWidthM, fieldLengthM, material, description, procedure, coachingPoints
        case variations, tags, animation, source, isFavorite, isArchived
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let slug = try c.decode(String.self, forKey: .slug)
        self.slug = slug
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? Exercise.stableID(forSlug: slug)
        self.name = try c.decode(String.self, forKey: .name)
        self.goalPrimary = try c.decode(String.self, forKey: .goalPrimary)
        self.goalsSecondary = try c.decodeIfPresent([String].self, forKey: .goalsSecondary) ?? []
        self.playersMin = try c.decode(Int.self, forKey: .playersMin)
        self.playersMax = try c.decode(Int.self, forKey: .playersMax)
        self.durationMin = try c.decode(Int.self, forKey: .durationMin)
        self.durationMax = try c.decode(Int.self, forKey: .durationMax)
        self.intensity = try c.decode(Int.self, forKey: .intensity)
        self.fieldWidthM = try c.decode(Int.self, forKey: .fieldWidthM)
        self.fieldLengthM = try c.decode(Int.self, forKey: .fieldLengthM)
        self.material = try c.decodeIfPresent([MaterialItem].self, forKey: .material) ?? []
        self.description = try c.decode(String.self, forKey: .description)
        self.procedure = try c.decode(String.self, forKey: .procedure)
        self.coachingPoints = try c.decodeIfPresent([String].self, forKey: .coachingPoints) ?? []
        self.variations = try c.decodeIfPresent(Variations.self, forKey: .variations) ?? Variations()
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.animation = try c.decodeIfPresent(ExerciseAnimation.self, forKey: .animation)
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "eigene"
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

public struct MaterialItem: Codable, Hashable, Sendable, Identifiable {
    public var item: String
    public var count: Int
    public var id: String { item }

    public init(item: String, count: Int) {
        self.item = item
        self.count = count
    }
}

public struct Variations: Codable, Hashable, Sendable {
    public var easier: [String]
    public var harder: [String]

    public init(easier: [String] = [], harder: [String] = []) {
        self.easier = easier
        self.harder = harder
    }
}

/// Gemeinsame JSON-Konfiguration: snake_case im Dateiformat, camelCase im Code.
public enum ExerciseJSON {
    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }
}
