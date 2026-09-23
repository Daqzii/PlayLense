import Foundation

public enum Venue: String, Codable, CaseIterable, Sendable, Identifiable {
    case heim, auswaerts
    public var id: String { rawValue }
    public var label: String { self == .heim ? "Heim" : "Auswärts" }
}

public enum Competition: String, Codable, CaseIterable, Sendable, Identifiable {
    case liga, pokal, test
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

/// Auf welches Tor wir in der 1. Halbzeit spielen, aus Sicht des Beobachters.
public enum AttackDirection: String, Codable, CaseIterable, Sendable, Identifiable {
    case links, rechts
    public var id: String { rawValue }
    public var label: String { self == .links ? "Nach links" : "Nach rechts" }
    public var flipped: AttackDirection { self == .links ? .rechts : .links }
}

public enum TrackingProfile: String, Codable, CaseIterable, Sendable, Identifiable {
    case voll, kompakt, minimal
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }

    public var eventTypes: [EventType] {
        switch self {
        case .voll: return EventType.allCases
        case .kompakt: return [.ballgewinn, .ballverlust, .abschluss, .grosschance, .angriff, .standard,
                               .wechsel, .wechselGegner, .karte, .verletzung, .flag, .notiz]
        case .minimal: return [.abschluss, .wechsel, .wechselGegner, .karte, .verletzung, .flag, .notiz]
        }
    }
}

public enum MatchStatus: String, Codable, CaseIterable, Sendable {
    case geplant, laeuft, beendet
}

public struct Match: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var seasonId: UUID
    public var kickoffPlanned: Date
    public var opponentName: String
    public var venue: Venue
    public var competition: Competition
    public var attackDirectionFirstHalf: AttackDirection
    public var observerSideFlipped: Bool
    public var trackingProfile: TrackingProfile
    public var formation: String
    public var status: MatchStatus
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), seasonId: UUID, kickoffPlanned: Date, opponentName: String,
                venue: Venue = .heim, competition: Competition = .liga,
                attackDirectionFirstHalf: AttackDirection = .rechts, observerSideFlipped: Bool = false,
                trackingProfile: TrackingProfile = .voll, formation: String = "4-2-3-1",
                status: MatchStatus = .geplant, notes: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.seasonId = seasonId
        self.kickoffPlanned = kickoffPlanned
        self.opponentName = opponentName
        self.venue = venue
        self.competition = competition
        self.attackDirectionFirstHalf = attackDirectionFirstHalf
        self.observerSideFlipped = observerSideFlipped
        self.trackingProfile = trackingProfile
        self.formation = formation
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct MatchPeriod: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var matchId: UUID
    public var number: Int
    public var startedAt: Date?
    public var endedAt: Date?
    public var nominalSeconds: Int

    public init(id: UUID = UUID(), matchId: UUID, number: Int, startedAt: Date? = nil, endedAt: Date? = nil,
                nominalSeconds: Int = 2700) {
        self.id = id
        self.matchId = matchId
        self.number = number
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.nominalSeconds = nominalSeconds
    }

    public var label: String {
        switch number {
        case 1: return "1. Halbzeit"
        case 2: return "2. Halbzeit"
        case 3: return "1. Verlängerung"
        case 4: return "2. Verlängerung"
        default: return "Periode \(number)"
        }
    }
}

public enum LineupRole: String, Codable, CaseIterable, Sendable {
    case start, bank
}

public struct MatchLineup: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var matchId: UUID
    public var playerId: UUID
    public var role: LineupRole
    public var positionKey: Position?
    public var numberInMatch: Int?

    public init(id: UUID = UUID(), matchId: UUID, playerId: UUID, role: LineupRole,
                positionKey: Position? = nil, numberInMatch: Int? = nil) {
        self.id = id
        self.matchId = matchId
        self.playerId = playerId
        self.role = role
        self.positionKey = positionKey
        self.numberInMatch = numberInMatch
    }
}

/// Formationsvorlagen: Positionsschlüssel in Reihen von hinten nach vorn.
public struct Formation: Hashable, Sendable, Identifiable {
    public var name: String
    public var rows: [[Position]]
    public var id: String { name }

    public var positions: [Position] { rows.flatMap { $0 } }

    public static let all: [Formation] = [
        Formation(name: "4-2-3-1", rows: [[.tw], [.lv, .liv, .riv, .rv], [.dm, .zm], [.la, .om, .ra], [.st]]),
        Formation(name: "4-4-2", rows: [[.tw], [.lv, .liv, .riv, .rv], [.lm, .dm, .zm, .rm], [.st, .st]]),
        Formation(name: "4-3-3", rows: [[.tw], [.lv, .liv, .riv, .rv], [.dm, .zm, .om], [.la, .st, .ra]]),
        Formation(name: "4-1-4-1", rows: [[.tw], [.lv, .liv, .riv, .rv], [.dm], [.lm, .zm, .om, .rm], [.st]]),
        Formation(name: "3-5-2", rows: [[.tw], [.liv, .iv, .riv], [.lm, .dm, .zm, .om, .rm], [.st, .st]]),
        Formation(name: "3-4-3", rows: [[.tw], [.liv, .iv, .riv], [.lm, .dm, .zm, .rm], [.la, .st, .ra]]),
        Formation(name: "5-3-2", rows: [[.tw], [.lv, .liv, .iv, .riv, .rv], [.dm, .zm, .om], [.st, .st]]),
    ]

    public static func named(_ name: String) -> Formation {
        all.first { $0.name == name } ?? all[0]
    }
}
