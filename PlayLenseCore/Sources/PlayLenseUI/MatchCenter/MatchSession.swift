import Foundation
import Observation
import PlayLenseCore
import PlayLenseData

/// Zustand eines laufenden Spiels im Match Center. Jede abgeschlossene Aktion wird sofort in die
/// Datenbank geschrieben; der Zustand hier ist nur ein Spiegel.
@MainActor
@Observable
public final class MatchSession: Identifiable {
    public let db: AppDatabase
    public let teamName: String
    public private(set) var match: Match
    public private(set) var periods: [MatchPeriod]
    public private(set) var lineup: [MatchLineup]
    public private(set) var events: [MatchEvent]
    public private(set) var insights: [MatchInsight]
    public private(set) var players: [UUID: Player]
    public var now: Date = Date()
    public var pending: PendingEvent?
    public var selectedPlayerId: UUID?
    public var banner: MatchInsight?
    public var lastError: String?
    public var flipDisplay = false
    private var bannerShownAt: Date?

    public static let pendingTimeout: TimeInterval = 4
    public static let bannerDuration: TimeInterval = 8

    public var id: UUID { match.id }

    public struct PendingEvent: Hashable, Sendable {
        public var type: EventType
        public var side: Side
        public var startedAt: Date
        public var zone: Zone?
        public var zoneX: Double?
        public var zoneY: Double?
        public var lane: ZoneLane?
        public var subtype: String?
        public var outcome: String?
        public var playerId: UUID?
        public var step: SecondStep

        public var needsZoneTap: Bool { step == .zone || step == .lane }
    }

    public init(db: AppDatabase, matchId: UUID, teamName: String) throws {
        self.db = db
        self.teamName = teamName
        let b = try db.fetchMatchBundle(id: matchId)
        self.match = b.match
        self.periods = b.periods
        self.lineup = b.lineup
        self.events = b.events
        self.insights = b.insights
        let ids = b.lineup.map(\.playerId)
        let ps = try db.fetchPlayers(ids: ids)
        self.players = Dictionary(uniqueKeysWithValues: ps.map { ($0.id, $0) })
    }

    // MARK: Abgeleiteter Zustand

    public var clockState: ClockState { MatchClock.state(periods: periods, status: match.status, now: now) }
    public var currentTime: MatchTime { MatchClock.currentTime(periods: periods, status: match.status, now: now) }
    public var currentPeriodNumber: Int { currentTime.period }
    public var nominalSeconds: Int { periods.first?.nominalSeconds ?? 2700 }
    public var clockText: String { currentTime.display(nominalSeconds: nominalSeconds) }
    public var score: SideCounts { MatchStats.compute(events: events).goals }
    public var pitchState: PitchState { LineupEngine.state(lineup: lineup, events: events) }
    public var liveEvents: [MatchEvent] { events.filter { !$0.isDeleted } }
    public var logEvents: [MatchEvent] { events.filter { !$0.isDeleted }.sorted { $0.seq > $1.seq } }
    public var timeline: PeriodTimeline { PeriodTimeline(periods: periods, now: now) }

    public var geometry: PitchGeometry {
        var g = PitchGeometry(attackDirectionFirstHalf: match.attackDirectionFirstHalf, period: currentPeriodNumber, observerFlipped: match.observerSideFlipped)
        if flipDisplay { g.observerFlipped.toggle() }
        return g
    }

    public var periodLabel: String {
        switch clockState {
        case .notStarted: return "Vor Anpfiff"
        case .running(let p, _): return periods.first { $0.number == p }?.label ?? "Periode \(p)"
        case .paused(let p): return p == 1 ? "Halbzeit" : "Pause nach \(periods.first { $0.number == p }?.label ?? "Periode \(p)")"
        case .finished: return "Abpfiff"
        }
    }

    /// Spieler auf dem Platz, sortiert nach Rückennummer, für die Spielerleiste.
    public var onPitchPlayers: [Player] {
        pitchState.onPitchIDs.compactMap { players[$0] }.sorted { ($0.number ?? 99) < ($1.number ?? 99) }
    }

    public var benchPlayers: [Player] {
        pitchState.bench.compactMap { players[$0] }.sorted { ($0.number ?? 99) < ($1.number ?? 99) }
    }

    public var availableEventTypes: [EventType] { match.trackingProfile.eventTypes }

    public func player(_ id: UUID?) -> Player? { id.flatMap { players[$0] } }

    // MARK: Uhr

    public func tick(now: Date = Date()) {
        self.now = now
        if let p = pending, p.needsZoneTap, now.timeIntervalSince(p.startedAt) > Self.pendingTimeout {
            // Timeout: ohne Zone speichern, nicht verwerfen.
            finalizePending(zone: nil)
        }
        if let shown = bannerShownAt, now.timeIntervalSince(shown) > Self.bannerDuration {
            banner = nil
            bannerShownAt = nil
        }
    }

    public var nextPeriodNumber: Int? { MatchClock.nextPeriodNumber(periods: periods) }

    public func startNextPeriod() {
        guard let n = nextPeriodNumber, var p = periods.first(where: { $0.number == n }) else { return }
        p.startedAt = Date()
        run {
            try db.savePeriod(p)
            if match.status == .geplant {
                try db.setMatchStatus(id: match.id, status: .laeuft)
                match.status = .laeuft
            }
            reloadPeriods()
        }
        Haptics.success()
    }

    /// Halbzeitpfiff bzw. Ende der laufenden Periode.
    public func endCurrentPeriod() {
        guard case .running(let n, _) = clockState, var p = periods.first(where: { $0.number == n }) else { return }
        p.endedAt = Date()
        run {
            try db.savePeriod(p)
            reloadPeriods()
        }
        Haptics.success()
    }

    public func finishMatch() {
        if case .running = clockState { endCurrentPeriod() }
        run {
            try db.setMatchStatus(id: match.id, status: .beendet)
            match.status = .beendet
        }
    }

    public func addExtraTimePeriod() {
        run {
            _ = try db.addPeriod(matchId: match.id, nominalSeconds: 900)
            reloadPeriods()
        }
    }

    /// Anpfiffzeit korrigieren (z. B. 30 Sekunden zu spät gedrückt).
    public func adjustCurrentPeriodStart(by seconds: Int) {
        guard case .running(let n, _) = clockState, var p = periods.first(where: { $0.number == n }), let s = p.startedAt else { return }
        p.startedAt = s.addingTimeInterval(TimeInterval(-seconds))
        run { try db.savePeriod(p); reloadPeriods() }
    }

    private func reloadPeriods() {
        periods = (try? db.fetchMatchBundle(id: match.id).periods) ?? periods
    }

    // MARK: Erfassung

    public func tapEvent(_ type: EventType, side: Side) {
        if let p = pending, p.type == type, p.side == side {
            pending = nil // zweiter Tap auf denselben Button bricht ab
            return
        }
        let step = type.secondStep
        var pe = PendingEvent(type: type, side: side, startedAt: Date(), step: step)
        if let sel = selectedPlayerId, side == .wir { pe.playerId = sel }
        pending = pe
        Haptics.tap()
        switch step {
        case .none:
            finalizePending(zone: nil)
        case .player:
            if pe.playerId != nil, !type.needsOutcome { finalizePending(zone: nil) }
        default:
            break
        }
    }

    public func tapZone(column: Int, row: Int, screenX: Double, screenY: Double) {
        guard var p = pending, p.needsZoneTap else { return }
        let g = geometry
        let z = g.zone(column: column, row: row)
        let n = g.normalized(screenX: screenX, screenY: screenY)
        p.zone = z
        p.zoneX = n.x
        p.zoneY = n.y
        p.lane = z.lane
        if p.type.needsOutcome {
            p.step = .none
            pending = p
        } else {
            pending = p
            finalizePending(zone: z)
        }
    }

    public func choose(outcome: String) {
        guard var p = pending else { return }
        p.outcome = outcome
        pending = p
        finalizePending(zone: p.zone)
    }

    public func choose(subtype: String) {
        guard var p = pending else { return }
        p.subtype = subtype
        pending = p
        if p.type == .karte, p.playerId == nil {
            p.step = .player
            pending = p
        } else {
            finalizePending(zone: nil)
        }
    }

    public func choose(player id: UUID) {
        guard var p = pending else { return }
        p.playerId = id
        pending = p
        if p.type.needsOutcome, p.outcome == nil { return }
        if p.type == .karte, p.subtype == nil { p.step = .cardType; pending = p; return }
        finalizePending(zone: p.zone)
    }

    public func cancelPending() {
        pending = nil
    }

    private func finalizePending(zone: Zone?) {
        guard let p = pending else { return }
        let t = currentTime
        var e = MatchEvent(matchId: match.id, seq: 0, period: t.period, matchSecond: t.second, occurredAt: Date(),
                           side: p.side, type: p.type, subtype: p.subtype, outcome: p.outcome,
                           zoneRow: zone?.row, zoneLane: p.type == .angriff ? p.lane : zone?.lane,
                           zoneX: p.zoneX, zoneY: p.zoneY, playerId: p.playerId)
        if let pid = p.playerId { e.positionKey = pitchState.position(of: pid) }
        pending = nil
        selectedPlayerId = nil
        commit(e)
    }

    public func addFlag(key: String, zone: Zone? = nil) {
        let t = currentTime
        let e = MatchEvent(matchId: match.id, seq: 0, period: t.period, matchSecond: t.second, side: .wir, type: .flag,
                           zoneRow: zone?.row, zoneLane: zone?.lane, flagKey: key)
        pending = nil
        commit(e)
    }

    public func addNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { pending = nil; return }
        let t = currentTime
        let e = MatchEvent(matchId: match.id, seq: 0, period: t.period, matchSecond: t.second, side: .neutral, type: .notiz, note: trimmed)
        pending = nil
        commit(e)
    }

    public func substitute(out: UUID?, in inn: UUID, position: Position?) {
        let t = currentTime
        let pos = position ?? out.flatMap { pitchState.position(of: $0) }
        let e = MatchEvent(matchId: match.id, seq: 0, period: t.period, matchSecond: t.second, side: .wir, type: .wechsel,
                           playerId: out, playerId2: inn, positionKey: pos)
        pending = nil
        commit(e)
    }

    public func opponentSubstitution() {
        let t = currentTime
        commit(MatchEvent(matchId: match.id, seq: 0, period: t.period, matchSecond: t.second, side: .gegner, type: .wechselGegner))
    }

    public func togglePlayerPrefix(_ id: UUID) {
        if let p = pending, p.step == .player || p.type == .karte {
            choose(player: id)
            return
        }
        selectedPlayerId = selectedPlayerId == id ? nil : id
        Haptics.tap()
    }

    // MARK: Log

    public func undo() {
        guard let last = logEvents.first else { return }
        run {
            try db.setEventDeleted(id: last.id, deleted: true)
            if let i = events.firstIndex(where: { $0.id == last.id }) { events[i].isDeleted = true }
        }
        Haptics.warning()
    }

    public func restore(_ e: MatchEvent) {
        run {
            try db.setEventDeleted(id: e.id, deleted: false)
            if let i = events.firstIndex(where: { $0.id == e.id }) { events[i].isDeleted = false }
        }
    }

    public func delete(_ e: MatchEvent) {
        run {
            try db.setEventDeleted(id: e.id, deleted: true)
            if let i = events.firstIndex(where: { $0.id == e.id }) { events[i].isDeleted = true }
        }
    }

    public func update(_ e: MatchEvent) {
        run {
            try db.updateEvent(e)
            if let i = events.firstIndex(where: { $0.id == e.id }) { events[i] = e }
        }
    }

    public var deletedEvents: [MatchEvent] { events.filter { $0.isDeleted }.sorted { $0.seq > $1.seq } }

    // MARK: Bericht

    public func generateReport(_ kind: ReportKind) -> MatchReportPayload {
        let payload = ReportBuilder.build(kind: kind, teamName: teamName, match: match, events: events, insights: insights, now: Date())
        run { try db.saveReport(MatchReport.make(matchId: match.id, payload: payload)) }
        return payload
    }

    public func stats(window: TimeWindow = .all) -> MatchStats {
        MatchStats.compute(events: events, window: window)
    }

    // MARK: Intern

    private func commit(_ event: MatchEvent) {
        run {
            let saved = try db.appendEvent(event)
            events.append(saved)
            Haptics.success()
            let fresh = LiveInsightEngine.evaluate(matchId: match.id, events: events, now: currentTime, timeline: timeline, existing: insights)
            if !fresh.isEmpty {
                try db.insertInsights(fresh)
                insights.append(contentsOf: fresh)
                banner = fresh.first
                bannerShownAt = Date()
            }
        }
    }

    private func run(_ body: () throws -> Void) {
        do { try body() } catch { lastError = error.localizedDescription }
    }
}
