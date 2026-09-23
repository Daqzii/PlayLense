import Foundation

/// Wer steht gerade auf dem Platz? Berechnet aus Aufstellung, Wechseln und Platzverweisen.
/// Rückwechsel sind erlaubt: ein ausgewechselter Spieler kann später wieder eingewechselt werden.
public struct PitchState: Hashable, Sendable {
    public var onPitch: Set<UUID> = []
    public var positions: [UUID: Position] = [:]
    public var bench: Set<UUID> = []
    public var sentOff: Set<UUID> = []
    public var injured: Set<UUID> = []

    public var onPitchIDs: [UUID] { Array(onPitch) }

    public func position(of playerId: UUID) -> Position? {
        positions[playerId]
    }
}

public enum LineupEngine {
    public static func state(lineup: [MatchLineup], events: [MatchEvent], upTo: MatchTime? = nil) -> PitchState {
        var s = PitchState()
        for l in lineup {
            if l.role == .start {
                s.onPitch.insert(l.playerId)
                if let p = l.positionKey { s.positions[l.playerId] = p }
            } else {
                s.bench.insert(l.playerId)
            }
        }
        let relevant = events
            .filter { !$0.isDeleted }
            .filter { upTo == nil || $0.time <= upTo! }
            .sorted { $0.seq < $1.seq }
        for e in relevant {
            switch e.type {
            case .wechsel:
                var inherited: Position? = nil
                if let out = e.playerId {
                    inherited = s.positions[out]
                    s.onPitch.remove(out)
                    s.positions.removeValue(forKey: out)
                    s.bench.insert(out)
                }
                if let inn = e.playerId2 {
                    s.bench.remove(inn)
                    s.onPitch.insert(inn)
                    if let p = e.positionKey ?? inherited { s.positions[inn] = p }
                }
            case .karte:
                if let p = e.playerId, e.cardType?.removesPlayer == true {
                    s.onPitch.remove(p)
                    s.positions.removeValue(forKey: p)
                    s.bench.remove(p)
                    s.sentOff.insert(p)
                }
            case .verletzung:
                if let p = e.playerId { s.injured.insert(p) }
            default:
                break
            }
        }
        return s
    }

    /// Einsatzsekunden je Spieler.
    public static func secondsPlayed(lineup: [MatchLineup], events: [MatchEvent], periods: [MatchPeriod],
                                     status: MatchStatus, now: Date = Date()) -> [UUID: Int] {
        let timeline = PeriodTimeline(periods: periods, now: now)
        let end = timeline.absolute(MatchClock.currentTime(periods: periods, status: status, now: now))
        var enteredAt: [UUID: Int] = [:]
        var total: [UUID: Int] = [:]
        for l in lineup where l.role == .start { enteredAt[l.playerId] = 0 }
        let relevant = events.filter { !$0.isDeleted }.sorted { $0.seq < $1.seq }
        func leave(_ p: UUID, at t: Int) {
            if let start = enteredAt.removeValue(forKey: p) { total[p, default: 0] += max(0, t - start) }
        }
        for e in relevant {
            let t = timeline.absolute(e.time)
            switch e.type {
            case .wechsel:
                if let out = e.playerId { leave(out, at: t) }
                if let inn = e.playerId2 { enteredAt[inn] = t }
            case .karte:
                if let p = e.playerId, e.cardType?.removesPlayer == true { leave(p, at: t) }
            default:
                break
            }
        }
        for (p, start) in enteredAt { total[p, default: 0] += max(0, end - start) }
        return total
    }
}
