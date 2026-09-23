import Foundation

public enum ClockState: Hashable, Sendable {
    case notStarted
    case running(period: Int, elapsed: Int)
    case paused(afterPeriod: Int)
    case finished

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

/// Uhr auf Basis der Zeitstempel in `MatchPeriod`. Läuft weiter, auch wenn die App beendet wurde.
public enum MatchClock {
    public static func state(periods: [MatchPeriod], status: MatchStatus, now: Date = Date()) -> ClockState {
        if status == .beendet { return .finished }
        let started = periods.filter { $0.startedAt != nil }.sorted { $0.number < $1.number }
        guard let last = started.last, let startedAt = last.startedAt else { return .notStarted }
        if last.endedAt != nil {
            return .paused(afterPeriod: last.number)
        }
        return .running(period: last.number, elapsed: Int(now.timeIntervalSince(startedAt)))
    }

    /// Zeitpunkt für ein neues Event. In der Pause wird die Endzeit der letzten Periode verwendet.
    public static func currentTime(periods: [MatchPeriod], status: MatchStatus, now: Date = Date()) -> MatchTime {
        let sorted = periods.sorted { $0.number < $1.number }
        switch state(periods: periods, status: status, now: now) {
        case .notStarted:
            return MatchTime(period: 1, second: 0)
        case .running(let period, let elapsed):
            return MatchTime(period: period, second: elapsed)
        case .paused(let after):
            return endTime(of: sorted.first { $0.number == after }, now: now)
        case .finished:
            return endTime(of: sorted.last { $0.startedAt != nil }, now: now)
        }
    }

    private static func endTime(of period: MatchPeriod?, now: Date) -> MatchTime {
        guard let p = period, let s = p.startedAt else { return MatchTime(period: 1, second: 0) }
        return MatchTime(period: p.number, second: Int((p.endedAt ?? now).timeIntervalSince(s)))
    }

    /// Nächste Periode, die gestartet werden kann (nil wenn keine mehr vorgesehen ist).
    public static func nextPeriodNumber(periods: [MatchPeriod]) -> Int? {
        let sorted = periods.sorted { $0.number < $1.number }
        return sorted.first { $0.startedAt == nil }?.number
    }
}

/// Rechnet Spielzeitpunkte in fortlaufende Sekunden um, damit Fenster über Periodengrenzen hinweg
/// verglichen werden können ("letzte 15 Minuten" kurz nach der Halbzeit).
public struct PeriodTimeline: Sendable {
    public var durations: [Int: Int] // Periodennummer -> Dauer in Sekunden

    public init(periods: [MatchPeriod], now: Date = Date()) {
        var d: [Int: Int] = [:]
        for p in periods {
            if let s = p.startedAt {
                d[p.number] = Int((p.endedAt ?? now).timeIntervalSince(s))
            } else {
                d[p.number] = 0
            }
        }
        durations = d
    }

    public init(durations: [Int: Int]) {
        self.durations = durations
    }

    public func absolute(_ t: MatchTime) -> Int {
        var sum = 0
        for (n, dur) in durations where n < t.period { sum += dur }
        return sum + t.second
    }

    public func time(absolute seconds: Int) -> MatchTime {
        var remaining = seconds
        for n in durations.keys.sorted() {
            let dur = durations[n] ?? 0
            if remaining < dur || n == durations.keys.max() { return MatchTime(period: n, second: remaining) }
            remaining -= dur
        }
        return MatchTime(period: 1, second: seconds)
    }
}
