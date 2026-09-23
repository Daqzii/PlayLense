import Foundation

public enum ReportKind: String, Codable, Sendable {
    case halbzeit, ende
    public var label: String { self == .halbzeit ? "Halbzeitanalyse" : "Spielbericht" }
}

public enum FindingSeverity: String, Codable, Sendable {
    case rot, gruen, neutral
}

public struct ReportFinding: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var severity: FindingSeverity
    public var text: String
    public var weight: Double

    public init(id: String, severity: FindingSeverity, text: String, weight: Double) {
        self.id = id
        self.severity = severity
        self.text = text
        self.weight = weight
    }
}

public struct ReportLine: Codable, Hashable, Sendable {
    public var label: String
    public var wir: Int
    public var gegner: Int
}

public struct ReportNote: Codable, Hashable, Sendable {
    public var minute: String
    public var text: String
}

public struct MatchReportPayload: Codable, Sendable {
    public var kind: ReportKind
    public var generatedAt: Date
    public var teamName: String
    public var opponentName: String
    public var score: SideCounts
    public var findings: [ReportFinding]
    public var lines: [ReportLine]
    public var attackSharesWir: [String: Int]
    public var attackSharesGegner: [String: Int]
    public var ballLossHeatmap: [String: Int]
    public var ballWinHeatmap: [String: Int]
    public var flags: [ReportNote]
    public var notes: [ReportNote]
    public var insights: [ReportNote]

    /// Klartext zum Vorlesen, Kopieren oder Abtippen.
    public func plainText() -> String {
        var out: [String] = []
        out.append("\(teamName) – \(kind.label)")
        out.append("\(teamName) \(score.wir) : \(score.gegner) \(opponentName)")
        out.append("")
        if !findings.isEmpty {
            out.append("Auffällig")
            for f in findings {
                let mark = f.severity == .rot ? "🔴" : (f.severity == .gruen ? "🟢" : "⚪")
                out.append("\(mark) \(f.text)")
            }
            out.append("")
        }
        for l in lines { out.append("\(l.label.padding(toLength: 22, withPad: " ", startingAt: 0)) \(l.wir) : \(l.gegner)") }
        out.append("")
        func shares(_ title: String, _ d: [String: Int]) {
            guard !d.isEmpty else { return }
            out.append("\(title): links \(d["links"] ?? 0)% · zentrum \(d["zentrum"] ?? 0)% · rechts \(d["rechts"] ?? 0)%")
        }
        shares("Unsere Angriffe", attackSharesWir)
        shares("Gegner-Angriffe (über unsere Seite)", attackSharesGegner)
        if !flags.isEmpty {
            out.append("")
            out.append("Flags")
            for f in flags { out.append("\(f.minute) \(f.text)") }
        }
        if !insights.isEmpty {
            out.append("")
            out.append("Live-Hinweise")
            for i in insights { out.append("\(i.minute) \(i.text)") }
        }
        if !notes.isEmpty {
            out.append("")
            out.append("Coach Notes")
            for n in notes { out.append("\(n.minute) \(n.text)") }
        }
        return out.joined(separator: "\n")
    }
}

public struct MatchReport: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var matchId: UUID
    public var kind: ReportKind
    public var generatedAt: Date
    public var payloadJSON: String

    public init(id: UUID = UUID(), matchId: UUID, kind: ReportKind, generatedAt: Date = Date(), payloadJSON: String) {
        self.id = id
        self.matchId = matchId
        self.kind = kind
        self.generatedAt = generatedAt
        self.payloadJSON = payloadJSON
    }

    public func payload() -> MatchReportPayload? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(MatchReportPayload.self, from: Data(payloadJSON.utf8))
    }

    public static func make(matchId: UUID, payload: MatchReportPayload) -> MatchReport {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        let data = (try? e.encode(payload)) ?? Data()
        return MatchReport(matchId: matchId, kind: payload.kind, generatedAt: payload.generatedAt,
                           payloadJSON: String(decoding: data, as: UTF8.self))
    }
}

public struct MatchInsight: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var matchId: UUID
    public var period: Int
    public var matchSecond: Int
    public var ruleId: String
    public var text: String
    public var severity: String
    public var acknowledged: Bool

    public init(id: UUID = UUID(), matchId: UUID, period: Int, matchSecond: Int, ruleId: String, text: String,
                severity: String = "warn", acknowledged: Bool = false) {
        self.id = id
        self.matchId = matchId
        self.period = period
        self.matchSecond = matchSecond
        self.ruleId = ruleId
        self.text = text
        self.severity = severity
        self.acknowledged = acknowledged
    }

    public var time: MatchTime { MatchTime(period: period, second: matchSecond) }
}

/// Halbzeit- und Endbericht. Regeln sind in Stufe 1 fest verdrahtet, ab Stufe 4 kommen sie aus dem Regelwerk.
public enum ReportBuilder {
    public static func build(kind: ReportKind, teamName: String, match: Match, events: [MatchEvent],
                             insights: [MatchInsight], window: TimeWindow = .all, now: Date = Date()) -> MatchReportPayload {
        let stats = MatchStats.compute(events: events, window: window)
        var findings: [ReportFinding] = []

        if stats.ballLossesCentre >= 6 {
            findings.append(.init(id: "bv_zentrum", severity: .rot, text: "\(stats.ballLossesCentre) Ballverluste im Zentrum", weight: Double(stats.ballLossesCentre) * 1.2))
        }
        if stats.ballLossesBuildUp >= 5 {
            findings.append(.init(id: "bv_aufbau", severity: .rot, text: "\(stats.ballLossesBuildUp) Ballverluste im eigenen Drittel", weight: Double(stats.ballLossesBuildUp) * 1.5))
        }
        let oppLanes = stats.attackLanes[.gegner] ?? [:]
        let oppTotal = oppLanes.values.reduce(0, +)
        if oppTotal >= 5, let best = oppLanes.max(by: { $0.value < $1.value }), Double(best.value) / Double(oppTotal) >= 0.5 {
            let via = best.key == .zentrum ? "durch die Mitte" : "über unsere \(best.key == .links ? "linke" : "rechte") Seite"
            findings.append(.init(id: "gegner_seite", severity: .rot, text: "\(best.value) von \(oppTotal) gegnerischen Angriffen \(via)", weight: Double(best.value) * 1.3))
        }
        if stats.pressingBypassed >= 4 {
            findings.append(.init(id: "pressing", severity: .rot, text: "\(stats.pressingBypassed)× Pressing überspielt", weight: Double(stats.pressingBypassed)))
        }
        if stats.counters.gegner >= 3 {
            findings.append(.init(id: "konter_gegner", severity: .rot, text: "\(stats.counters.gegner) gegnerische Konter", weight: Double(stats.counters.gegner) * 1.4))
        }
        if stats.bigChances.wir >= 4, Double(stats.goals.wir) / Double(stats.bigChances.wir) < 0.25 {
            findings.append(.init(id: "chancen", severity: .rot, text: "\(stats.goals.wir) Tore aus \(stats.bigChances.wir) Großchancen", weight: 4))
        }
        if stats.highBallWins >= 5 {
            findings.append(.init(id: "hohe_ballgewinne", severity: .gruen, text: "\(stats.highBallWins) Ballgewinne im gegnerischen Drittel", weight: Double(stats.highBallWins)))
        }
        if stats.shots.wir >= stats.shots.gegner + 5 {
            findings.append(.init(id: "abschluss_plus", severity: .gruen, text: "Abschlüsse \(stats.shots.wir) : \(stats.shots.gegner)", weight: 3))
        }
        if stats.shots.gegner >= stats.shots.wir + 5 {
            findings.append(.init(id: "abschluss_minus", severity: .rot, text: "Abschlüsse \(stats.shots.wir) : \(stats.shots.gegner)", weight: 3))
        }
        for (key, n) in stats.flagCounts where n >= 3 {
            let def = FlagDefinition.defaults.first { $0.key == key }
            let sev: FindingSeverity = def?.group == "Positiv" ? .gruen : .rot
            findings.append(.init(id: "flag_\(key)", severity: sev, text: "\(n)× Flag „\(def?.label ?? key)“", weight: Double(n) * (def?.weight ?? 1)))
        }
        findings.sort { $0.weight > $1.weight }

        let lines: [ReportLine] = [
            .init(label: "Abschlüsse", wir: stats.shots.wir, gegner: stats.shots.gegner),
            .init(label: "davon aufs Tor", wir: stats.shotsOnTarget.wir, gegner: stats.shotsOnTarget.gegner),
            .init(label: "Großchancen", wir: stats.bigChances.wir, gegner: stats.bigChances.gegner),
            .init(label: "Ballgewinne", wir: stats.ballWins.wir, gegner: stats.ballWins.gegner),
            .init(label: "Ballverluste", wir: stats.ballLosses.wir, gegner: stats.ballLosses.gegner),
            .init(label: "Angriffe", wir: stats.attacks.wir, gegner: stats.attacks.gegner),
            .init(label: "Konter", wir: stats.counters.wir, gegner: stats.counters.gegner),
            .init(label: "Standards", wir: stats.standards.wir, gegner: stats.standards.gegner),
        ]

        func shares(_ side: Side) -> [String: Int] {
            var d: [String: Int] = [:]
            for (l, v) in stats.attackShares(side) { d[l.rawValue] = v }
            return d
        }
        func heat(_ type: EventType) -> [String: Int] {
            var d: [String: Int] = [:]
            for (z, v) in stats.heatmap(.wir, type) { d["\(z.row.rawValue)/\(z.lane.rawValue)"] = v }
            return d
        }
        let flagNotes = events.filter { !$0.isDeleted && $0.type == .flag && window.contains($0.time) }
            .sorted { $0.seq < $1.seq }
            .map { ReportNote(minute: $0.time.minuteLabel(), text: FlagDefinition.label(for: $0.flagKey ?? "")) }
        let notes = events.filter { !$0.isDeleted && $0.type == .notiz && window.contains($0.time) }
            .sorted { $0.seq < $1.seq }
            .map { ReportNote(minute: $0.time.minuteLabel(), text: $0.note ?? "") }
        let insightNotes = insights.filter { window.contains($0.time) }
            .map { ReportNote(minute: $0.time.minuteLabel(), text: $0.text) }

        return MatchReportPayload(
            kind: kind, generatedAt: now, teamName: teamName, opponentName: match.opponentName,
            score: MatchStats.compute(events: events).goals, findings: findings, lines: lines,
            attackSharesWir: shares(.wir), attackSharesGegner: shares(.gegner),
            ballLossHeatmap: heat(.ballverlust), ballWinHeatmap: heat(.ballgewinn),
            flags: flagNotes, notes: notes, insights: insightNotes
        )
    }
}
