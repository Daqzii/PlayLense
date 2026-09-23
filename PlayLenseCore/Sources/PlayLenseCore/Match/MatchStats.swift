import Foundation

public struct TimeWindow: Hashable, Sendable {
    public var start: MatchTime?
    public var end: MatchTime?
    public var label: String

    public init(start: MatchTime? = nil, end: MatchTime? = nil, label: String = "Gesamt") {
        self.start = start
        self.end = end
        self.label = label
    }

    public static let all = TimeWindow()
    public static func period(_ n: Int) -> TimeWindow {
        TimeWindow(start: MatchTime(period: n, second: 0), end: MatchTime(period: n, second: Int.max), label: n == 1 ? "1. HZ" : "\(n). HZ")
    }

    public func contains(_ t: MatchTime) -> Bool {
        if let s = start, t < s { return false }
        if let e = end, t > e { return false }
        return true
    }
}

public struct SideCounts: Hashable, Sendable, Codable {
    public var wir: Int = 0
    public var gegner: Int = 0

    public init(wir: Int = 0, gegner: Int = 0) {
        self.wir = wir
        self.gegner = gegner
    }

    public subscript(side: Side) -> Int {
        get { side == .wir ? wir : gegner }
        set { if side == .wir { wir = newValue } else { gegner = newValue } }
    }

    public var display: String { "\(wir) : \(gegner)" }
}

public struct PlayerMatchCounts: Hashable, Sendable, Codable {
    public var shots = 0
    public var shotsOnTarget = 0
    public var goals = 0
    public var bigChances = 0
    public var ballLosses = 0
    public var ballWins = 0
    public var duelsWon = 0
    public var duelsLost = 0
    public var yellow = 0
    public var red = 0

    public init() {}
}

/// Alle Kennzahlen eines Spiels für ein Zeitfenster. Wird nie gespeichert, immer berechnet.
public struct MatchStats: Sendable {
    public var window: TimeWindow
    public var shots = SideCounts()
    public var shotsOnTarget = SideCounts()
    public var goals = SideCounts()
    public var bigChances = SideCounts()
    public var ballWins = SideCounts()
    public var ballLosses = SideCounts()
    public var attacks = SideCounts()
    public var counters = SideCounts()
    public var standards = SideCounts()
    public var dangerousStandards = SideCounts()
    public var pressingBypassed = 0
    public var ballLossesBuildUp = 0
    public var ballLossesCentre = 0
    public var highBallWins = 0
    public var attackLanes: [Side: [ZoneLane: Int]] = [.wir: [:], .gegner: [:]]
    public var zoneCounts: [Side: [EventType: [Zone: Int]]] = [.wir: [:], .gegner: [:]]
    public var flagCounts: [String: Int] = [:]
    public var playerCounts: [UUID: PlayerMatchCounts] = [:]
    public var eventCount = 0

    public init(window: TimeWindow = .all) {
        self.window = window
    }

    public static func compute(events: [MatchEvent], window: TimeWindow = .all) -> MatchStats {
        var s = MatchStats(window: window)
        for e in events where !e.isDeleted && window.contains(e.time) {
            s.eventCount += 1
            let side = e.side == .neutral ? Side.wir : e.side
            if let z = e.zone, e.side != .neutral {
                s.zoneCounts[side, default: [:]][e.type, default: [:]][z, default: 0] += 1
            }
            var pc = e.playerId.map { s.playerCounts[$0] ?? PlayerMatchCounts() }
            switch e.type {
            case .abschluss:
                s.shots[side] += 1
                pc?.shots += 1
                if let o = e.shotOutcome {
                    if o == .tor || o == .aufsTor { s.shotsOnTarget[side] += 1; pc?.shotsOnTarget += 1 }
                    if o == .tor { s.goals[side] += 1; pc?.goals += 1 }
                }
            case .grosschance:
                s.bigChances[side] += 1
                pc?.bigChances += 1
            case .ballgewinn:
                s.ballWins[side] += 1
                pc?.ballWins += 1
                if side == .wir, e.zoneRow == .angriffsdrittel { s.highBallWins += 1 }
            case .ballverlust:
                s.ballLosses[side] += 1
                pc?.ballLosses += 1
                if side == .wir {
                    if e.zoneRow == .eigenesDrittel { s.ballLossesBuildUp += 1 }
                    if e.zoneLane == .zentrum { s.ballLossesCentre += 1 }
                }
            case .angriff:
                s.attacks[side] += 1
                if let l = e.zoneLane { s.attackLanes[side, default: [:]][l, default: 0] += 1 }
            case .konter:
                s.counters[side] += 1
            case .pressingUeberspielt:
                if side == .wir { s.pressingBypassed += 1 }
            case .standard:
                s.standards[side] += 1
                if e.outcome == "gefaehrlich" { s.dangerousStandards[side] += 1 }
            case .zweikampf:
                if e.outcome == DuelOutcome.gewonnen.rawValue { pc?.duelsWon += 1 } else { pc?.duelsLost += 1 }
            case .karte:
                if e.cardType == .gelb { pc?.yellow += 1 } else { pc?.red += 1 }
            case .flag:
                if let k = e.flagKey { s.flagCounts[k, default: 0] += 1 }
            default:
                break
            }
            if let p = e.playerId, let counts = pc { s.playerCounts[p] = counts }
        }
        return s
    }

    /// Anteile der Angriffe je Seite in Prozent (0–100).
    public func attackShares(_ side: Side) -> [ZoneLane: Int] {
        let lanes = attackLanes[side] ?? [:]
        let total = lanes.values.reduce(0, +)
        guard total > 0 else { return [:] }
        var out: [ZoneLane: Int] = [:]
        for l in ZoneLane.allCases { out[l] = Int((Double(lanes[l] ?? 0) / Double(total) * 100).rounded()) }
        return out
    }

    public func heatmap(_ side: Side, _ type: EventType) -> [Zone: Int] {
        zoneCounts[side]?[type] ?? [:]
    }
}
