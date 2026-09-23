import Foundation

public enum Side: String, Codable, CaseIterable, Sendable, Identifiable {
    case wir, gegner, neutral
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .wir: return "Wir"
        case .gegner: return "Gegner"
        case .neutral: return "Neutral"
        }
    }
}

public enum ZoneRow: String, Codable, CaseIterable, Sendable, Identifiable {
    case eigenesDrittel = "eigenes_drittel", mittelfeld, angriffsdrittel
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .eigenesDrittel: return "Eigenes Drittel"
        case .mittelfeld: return "Mittelfeld"
        case .angriffsdrittel: return "Angriffsdrittel"
        }
    }
    public var short: String {
        switch self {
        case .eigenesDrittel: return "Eig."
        case .mittelfeld: return "Mitte"
        case .angriffsdrittel: return "Angr."
        }
    }
}

public enum ZoneLane: String, Codable, CaseIterable, Sendable, Identifiable {
    case links, zentrum, rechts
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
    public var short: String {
        switch self {
        case .links: return "L"
        case .zentrum: return "Z"
        case .rechts: return "R"
        }
    }
}

public struct Zone: Hashable, Sendable, Codable {
    public var row: ZoneRow
    public var lane: ZoneLane
    public init(row: ZoneRow, lane: ZoneLane) {
        self.row = row
        self.lane = lane
    }
    public var label: String { "\(row.short) \(lane.short)" }
}

/// Zweite Stufe der Erfassung: Was braucht der Event-Typ nach dem ersten Tap?
public enum SecondStep: Sendable, Hashable {
    case none
    case zone
    case lane
    case standardType
    case cardType
    case player
    case substitution
    case flag
    case note
}

public enum EventType: String, Codable, CaseIterable, Sendable, Identifiable {
    case ballgewinn, ballverlust, abschluss, grosschance, angriff, konter
    case pressingUeberspielt = "pressing_ueberspielt"
    case standard, zweikampf, karte, verletzung, wechsel
    case wechselGegner = "wechsel_gegner"
    case flag, notiz

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .ballgewinn: return "Ballgewinn"
        case .ballverlust: return "Ballverlust"
        case .abschluss: return "Abschluss"
        case .grosschance: return "Großchance"
        case .angriff: return "Angriff"
        case .konter: return "Konter"
        case .pressingUeberspielt: return "Pressing überspielt"
        case .standard: return "Standard"
        case .zweikampf: return "Zweikampf"
        case .karte: return "Karte"
        case .verletzung: return "Verletzung"
        case .wechsel: return "Wechsel"
        case .wechselGegner: return "Gegner-Wechsel"
        case .flag: return "Flag"
        case .notiz: return "Notiz"
        }
    }

    /// Events, die als Spalte für Wir und Gegner angeboten werden.
    public static let teamEvents: [EventType] = [.ballgewinn, .ballverlust, .abschluss, .grosschance, .angriff, .konter, .pressingUeberspielt, .standard]

    /// Events in der Mittelleiste (nur eigene Seite oder neutral).
    public static let utilityEvents: [EventType] = [.flag, .notiz, .wechsel, .wechselGegner, .karte, .verletzung, .zweikampf]

    public var secondStep: SecondStep {
        switch self {
        case .ballgewinn, .ballverlust, .grosschance, .konter, .pressingUeberspielt, .abschluss: return .zone
        case .angriff: return .lane
        case .standard: return .standardType
        case .karte: return .cardType
        case .zweikampf, .verletzung: return .player
        case .wechsel: return .substitution
        case .wechselGegner: return .none
        case .flag: return .flag
        case .notiz: return .note
        }
    }

    /// Abschluss hat eine dritte Stufe: das Ergebnis.
    public var needsOutcome: Bool { self == .abschluss || self == .zweikampf }

    public var availableForOpponent: Bool {
        switch self {
        case .zweikampf, .karte, .verletzung, .wechsel, .flag, .notiz, .wechselGegner: return false
        default: return true
        }
    }
}

public enum ShotOutcome: String, Codable, CaseIterable, Sendable, Identifiable {
    case tor, aufsTor = "aufs_tor", vorbei, geblockt
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .tor: return "Tor"
        case .aufsTor: return "Aufs Tor"
        case .vorbei: return "Vorbei"
        case .geblockt: return "Geblockt"
        }
    }
}

public enum DuelOutcome: String, Codable, CaseIterable, Sendable, Identifiable {
    case gewonnen, verloren
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum StandardType: String, Codable, CaseIterable, Sendable, Identifiable {
    case ecke, freistoss, einwurf, elfmeter
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .ecke: return "Ecke"
        case .freistoss: return "Freistoß"
        case .einwurf: return "Einwurf"
        case .elfmeter: return "Elfmeter"
        }
    }
}

public enum CardType: String, Codable, CaseIterable, Sendable, Identifiable {
    case gelb, gelbrot, rot
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .gelb: return "Gelb"
        case .gelbrot: return "Gelb-Rot"
        case .rot: return "Rot"
        }
    }
    public var removesPlayer: Bool { self != .gelb }
}

public enum GoalKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case spiel, standard, konter, elfmeter, eigentor
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

/// Zeitpunkt im Spiel: Periode plus Sekunden seit Anpfiff dieser Periode. Vergleichbar über Perioden hinweg.
public struct MatchTime: Hashable, Comparable, Codable, Sendable {
    public var period: Int
    public var second: Int

    public init(period: Int, second: Int) {
        self.period = period
        self.second = max(0, second)
    }

    public static func < (a: MatchTime, b: MatchTime) -> Bool {
        (a.period, a.second) < (b.period, b.second)
    }

    /// "27:34" oder "45+2:10" für Nachspielzeit.
    public func display(nominalSeconds: Int = 2700) -> String {
        let base = (period - 1) * (nominalSeconds / 60)
        let nominalMinutes = nominalSeconds / 60
        let minute = second / 60
        let sec = second % 60
        if minute >= nominalMinutes {
            let extra = minute - nominalMinutes
            return String(format: "%d+%d:%02d", base + nominalMinutes, extra, sec)
        }
        return String(format: "%d:%02d", base + minute, sec)
    }

    /// Spielminute für Berichte ("27." oder "45+2.").
    public func minuteLabel(nominalSeconds: Int = 2700) -> String {
        let base = (period - 1) * (nominalSeconds / 60)
        let nominalMinutes = nominalSeconds / 60
        let minute = second / 60 + 1
        if minute > nominalMinutes {
            return "\(base + nominalMinutes)+\(minute - nominalMinutes)."
        }
        return "\(base + minute)."
    }
}

public struct MatchEvent: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var matchId: UUID
    public var seq: Int
    public var period: Int
    public var matchSecond: Int
    public var occurredAt: Date
    public var side: Side
    public var type: EventType
    public var subtype: String?
    public var outcome: String?
    public var zoneRow: ZoneRow?
    public var zoneLane: ZoneLane?
    public var zoneX: Double?
    public var zoneY: Double?
    public var playerId: UUID?
    public var playerId2: UUID?
    public var positionKey: Position?
    public var flagKey: String?
    public var note: String?
    public var isDeleted: Bool
    public var editedAt: Date?
    public var createdAt: Date

    public init(id: UUID = UUID(), matchId: UUID, seq: Int, period: Int, matchSecond: Int, occurredAt: Date = Date(),
                side: Side, type: EventType, subtype: String? = nil, outcome: String? = nil,
                zoneRow: ZoneRow? = nil, zoneLane: ZoneLane? = nil, zoneX: Double? = nil, zoneY: Double? = nil,
                playerId: UUID? = nil, playerId2: UUID? = nil, positionKey: Position? = nil,
                flagKey: String? = nil, note: String? = nil, isDeleted: Bool = false, editedAt: Date? = nil,
                createdAt: Date = Date()) {
        self.id = id
        self.matchId = matchId
        self.seq = seq
        self.period = period
        self.matchSecond = matchSecond
        self.occurredAt = occurredAt
        self.side = side
        self.type = type
        self.subtype = subtype
        self.outcome = outcome
        self.zoneRow = zoneRow
        self.zoneLane = zoneLane
        self.zoneX = zoneX
        self.zoneY = zoneY
        self.playerId = playerId
        self.playerId2 = playerId2
        self.positionKey = positionKey
        self.flagKey = flagKey
        self.note = note
        self.isDeleted = isDeleted
        self.editedAt = editedAt
        self.createdAt = createdAt
    }

    public var time: MatchTime { MatchTime(period: period, second: matchSecond) }

    public var zone: Zone? {
        get {
            guard let r = zoneRow, let l = zoneLane else { return nil }
            return Zone(row: r, lane: l)
        }
        set {
            zoneRow = newValue?.row
            zoneLane = newValue?.lane
        }
    }

    public var shotOutcome: ShotOutcome? { outcome.flatMap(ShotOutcome.init(rawValue:)) }
    public var isGoal: Bool { type == .abschluss && shotOutcome == .tor }
    public var standardType: StandardType? { subtype.flatMap(StandardType.init(rawValue:)) }
    public var cardType: CardType? { subtype.flatMap(CardType.init(rawValue:)) }

    /// Kurzbeschreibung für das Log: "Ballverlust · Mitte Z" oder "Abschluss · Tor".
    public func logSummary(flagLabel: ((String) -> String)? = nil) -> String {
        var parts: [String] = []
        switch type {
        case .flag:
            parts.append(flagKey.map { flagLabel?($0) ?? $0 } ?? "Flag")
        case .notiz:
            parts.append(note.map { "Notiz: \($0)" } ?? "Notiz")
        case .standard:
            parts.append(standardType?.label ?? "Standard")
        case .karte:
            parts.append(cardType?.label ?? "Karte")
        default:
            parts.append(type.label)
        }
        if let s = shotOutcome { parts.append(s.label) }
        if type == .zweikampf, let o = outcome.flatMap(DuelOutcome.init(rawValue:)) { parts.append(o.label) }
        if type == .angriff, let l = zoneLane { parts.append(l.label) } else if let z = zone { parts.append(z.label) }
        return parts.joined(separator: " · ")
    }
}

/// Flag-Katalog. Startbelegung aus docs/03-event-katalog.md; in Stufe 2 in der Datenbank editierbar.
public struct FlagDefinition: Codable, Hashable, Sendable, Identifiable {
    public var key: String
    public var label: String
    public var group: String
    public var weight: Double
    public var id: String { key }

    public init(key: String, label: String, group: String, weight: Double = 1.0) {
        self.key = key
        self.label = label
        self.group = group
        self.weight = weight
    }

    public static let defaults: [FlagDefinition] = [
        .init(key: "def_ueberladung_links", label: "Überladung links", group: "Defensive"),
        .init(key: "def_ueberladung_rechts", label: "Überladung rechts", group: "Defensive"),
        .init(key: "def_abstand_iv_av", label: "Abstand IV–AV", group: "Defensive"),
        .init(key: "def_tiefe_hinter_kette", label: "Tiefe hinter der Kette", group: "Defensive"),
        .init(key: "def_zentrum_offen", label: "Zentrum offen", group: "Defensive"),
        .init(key: "def_zweite_baelle", label: "Zweite Bälle verloren", group: "Defensive"),
        .init(key: "def_abstand_iv_zm", label: "Abstand IV–ZM", group: "Defensive"),
        .init(key: "def_restverteidigung", label: "Restverteidigung", group: "Defensive"),
        .init(key: "off_aufbauproblem", label: "Aufbauproblem", group: "Offensive"),
        .init(key: "off_keine_tiefe", label: "Keine Tiefe", group: "Offensive"),
        .init(key: "off_keine_breite", label: "Keine Breite", group: "Offensive"),
        .init(key: "off_strafraumbesetzung", label: "Zu wenig Strafraumbesetzung", group: "Offensive"),
        .init(key: "off_tempo_umschalten", label: "Zu langsam beim Umschalten", group: "Offensive"),
        .init(key: "pos_pressing_greift", label: "Pressing greift", group: "Positiv"),
        .init(key: "pos_aufbau_sauber", label: "Aufbau sauber", group: "Positiv"),
        .init(key: "pos_umschalten_stark", label: "Umschaltmoment stark", group: "Positiv"),
        .init(key: "pos_standard_gefaehrlich", label: "Standards gefährlich", group: "Positiv"),
    ]

    public static func label(for key: String) -> String {
        defaults.first { $0.key == key }?.label ?? key
    }

    public static let groups: [String] = ["Defensive", "Offensive", "Positiv"]
}
