import Foundation

/// Wer steht gerade auf dem Platz? Berechnet aus Aufstellung, Wechseln und Platzverweisen.
/// Rückwechsel sind erlaubt: ein ausgewechselter Spieler kann später wieder eingewechselt werden.
public struct PitchState: Hashable, Sendable {
    public var onPitch: [UUID: Position?] = [:]
    public var bench: Set<UUID> = []
    public var sentOff: Set<UUID> = []
    public var injured: Set<UUID> = []

    public var onPitchIDs: [UUID] { Array(onPitch.keys) }

    public func position(of playerId: UUID) -> Position? {
        onPitch[playerId] ?? nil
    }
}

public enum LineupEngine {
    public static func state(lineup: [MatchLineup], events: [MatchEvent], upTo: MatchTime? = nil) -> PitchState {
        var s = PitchState()
        for l in lineup {
            if l.role == .start {
                s.onPitch[l.playerId] = l.positionKey
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
                if let out = e.playerId {
                    let pos = s.onPitch[out] ?? nil
                    s.onPitch.removeValue(forKey: out)
                    s.bench.insert(out)
                    if let inn = e.playerId2 {
                        s.bench.remove(inn)
                        s.onPitch[inn] = e.positionKey ?? pos
                    }
                } else if let inn = e.playerId2 {
                    s.bench.remove(inn)
                    s.onPitch[inn] = e.positionKey
                }
            case .karte:
                if let p = e.playerId, e.cardType?.removesPlayer == true {
                    s.onPitch.removeValue(forKey: p)
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
