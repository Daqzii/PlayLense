import Foundation

public enum Position: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case tw, lv, liv, iv, riv, rv, dm, zm, lm, rm, om, la, ra, st

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .tw: return "Torwart"
        case .lv: return "Linker Verteidiger"
        case .liv: return "Linker Innenverteidiger"
        case .iv: return "Innenverteidiger"
        case .riv: return "Rechter Innenverteidiger"
        case .rv: return "Rechter Verteidiger"
        case .dm: return "Sechser"
        case .zm: return "Zentrales Mittelfeld"
        case .lm: return "Linkes Mittelfeld"
        case .rm: return "Rechtes Mittelfeld"
        case .om: return "Zehner"
        case .la: return "Linksaußen"
        case .ra: return "Rechtsaußen"
        case .st: return "Stürmer"
        }
    }

    public var short: String { rawValue.uppercased() }

    public var group: PositionGroup {
        switch self {
        case .tw: return .tor
        case .lv, .liv, .iv, .riv, .rv: return .abwehr
        case .dm, .zm, .lm, .rm, .om: return .mittelfeld
        case .la, .ra, .st: return .angriff
        }
    }
}

public enum PositionGroup: String, Codable, CaseIterable, Sendable {
    case tor, abwehr, mittelfeld, angriff

    public var label: String {
        switch self {
        case .tor: return "Tor"
        case .abwehr: return "Abwehr"
        case .mittelfeld: return "Mittelfeld"
        case .angriff: return "Angriff"
        }
    }
}

public enum Foot: String, Codable, CaseIterable, Sendable, Identifiable {
    case rechts, links, beide
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum PlayerStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case aktiv, verletzt, abwesend, inaktiv
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public struct Player: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var teamId: UUID
    public var firstName: String
    public var lastName: String
    public var nickname: String?
    public var number: Int?
    public var primaryPosition: Position?
    public var secondaryPositions: [Position]
    public var foot: Foot
    public var birthYear: Int?
    public var status: PlayerStatus
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), teamId: UUID, firstName: String, lastName: String, nickname: String? = nil,
                number: Int? = nil, primaryPosition: Position? = nil, secondaryPositions: [Position] = [],
                foot: Foot = .rechts, birthYear: Int? = nil, status: PlayerStatus = .aktiv, notes: String = "",
                createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.teamId = teamId
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.number = number
        self.primaryPosition = primaryPosition
        self.secondaryPositions = secondaryPositions
        self.foot = foot
        self.birthYear = birthYear
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var displayName: String {
        if let n = nickname, !n.isEmpty { return n }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    /// "#9 Max M." für die Spielerleiste und das Log.
    public var shortLabel: String {
        let num = number.map { "#\($0) " } ?? ""
        let last = lastName.first.map { "\(String($0))." } ?? ""
        return "\(num)\(firstName) \(last)".trimmingCharacters(in: .whitespaces)
    }

    public var numberLabel: String { number.map(String.init) ?? "–" }
}
