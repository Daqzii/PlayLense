import Foundation

/// Erkennt Muster während des Spiels. Wird nach jedem Event aufgerufen und liefert nur neue Hinweise.
public enum LiveInsightEngine {
    public static let cooldownSeconds = 300

    public static func evaluate(matchId: UUID, events: [MatchEvent], now: MatchTime, timeline: PeriodTimeline,
                                existing: [MatchInsight]) -> [MatchInsight] {
        let live = events.filter { !$0.isDeleted }.sorted { $0.seq < $1.seq }
        let nowAbs = timeline.absolute(now)
        var out: [MatchInsight] = []

        func recentlyFired(_ ruleId: String) -> Bool {
            existing.contains { $0.ruleId == ruleId && nowAbs - timeline.absolute($0.time) < cooldownSeconds }
        }
        func emit(_ ruleId: String, _ text: String, severity: String = "warn") {
            guard !recentlyFired(ruleId), !out.contains(where: { $0.ruleId == ruleId }) else { return }
            out.append(MatchInsight(matchId: matchId, period: now.period, matchSecond: now.second, ruleId: ruleId, text: text, severity: severity))
        }
        func within(_ seconds: Int, _ e: MatchEvent) -> Bool { nowAbs - timeline.absolute(e.time) <= seconds }

        // 1. Ballverlust-Cluster: 4 der letzten 5 Ballverluste in derselben Zone.
        let losses = live.filter { $0.type == .ballverlust && $0.side == .wir && $0.zone != nil }.suffix(5)
        if losses.count == 5 {
            let grouped = Dictionary(grouping: losses, by: { $0.zone! })
            if let best = grouped.max(by: { $0.value.count < $1.value.count }), best.value.count >= 4 {
                let zone = best.key
                emit("bv_cluster_\(zone.row.rawValue)_\(zone.lane.rawValue)", "\(best.value.count) der letzten 5 Ballverluste in Zone \(zone.row.label) \(zone.lane.label.lowercased()).")
            }
        }

        // 2. Gegner-Seite: >= 6 Gegner-Angriffe in 15 Minuten, >= 75 % über eine Seite.
        let oppAttacks = live.filter { $0.type == .angriff && $0.side == .gegner && $0.zoneLane != nil && within(900, $0) }
        if oppAttacks.count >= 6 {
            let grouped = Dictionary(grouping: oppAttacks, by: { $0.zoneLane! })
            if let best = grouped.max(by: { $0.value.count < $1.value.count }), Double(best.value.count) / Double(oppAttacks.count) >= 0.75 {
                let lane = best.key
                let side = lane == .zentrum ? "durch die Mitte" : "über unsere \(lane == .links ? "linke" : "rechte") Seite"
                emit("gegner_seite_\(lane.rawValue)", "\(best.value.count) von \(oppAttacks.count) Gegner-Angriffen der letzten 15 Minuten \(side).")
            }
        }

        // 3. Pressing-Serie.
        let bypassed = live.filter { $0.type == .pressingUeberspielt && within(600, $0) }
        if bypassed.count >= 3 {
            emit("pressing_serie", "\(bypassed.count)× Pressing überspielt in den letzten 10 Minuten.")
        }

        // 4. Flag-Wiederholung: dritte Nennung desselben Flags.
        let flags = live.filter { $0.type == .flag && $0.flagKey != nil }
        for (key, items) in Dictionary(grouping: flags, by: { $0.flagKey! }) where items.count >= 3 {
            if items.last?.seq == live.last?.seq {
                emit("flag_\(key)", "Flag „\(FlagDefinition.label(for: key))“ zum \(items.count). Mal.")
            }
        }

        // 5. Positiv-Serie: hohe Ballgewinne.
        let highWins = live.filter { $0.type == .ballgewinn && $0.side == .wir && $0.zoneRow == .angriffsdrittel && within(600, $0) }
        if highWins.count >= 3 {
            emit("hohe_ballgewinne", "\(highWins.count) Ballgewinne im gegnerischen Drittel in den letzten 10 Minuten.", severity: "info")
        }

        // 6. Abschluss-Kippen nach Wechsel: Verhältnis dreht sich gegenüber dem gleich langen Fenster davor.
        if let sub = live.last(where: { $0.type == .wechsel || $0.type == .wechselGegner }) {
            let subAbs = timeline.absolute(sub.time)
            let span = nowAbs - subAbs
            if span >= 480 {
                let after = live.filter { $0.type == .abschluss && timeline.absolute($0.time) > subAbs }
                let before = live.filter { $0.type == .abschluss && timeline.absolute($0.time) <= subAbs && timeline.absolute($0.time) > subAbs - span }
                let a = SideCounts(wir: after.filter { $0.side == .wir }.count, gegner: after.filter { $0.side == .gegner }.count)
                let b = SideCounts(wir: before.filter { $0.side == .wir }.count, gegner: before.filter { $0.side == .gegner }.count)
                if b.wir > b.gegner, a.gegner > a.wir, a.gegner >= 3 {
                    emit("kippen_\(sub.seq)", "Seit dem Wechsel in Minute \(sub.time.minuteLabel()): Abschlüsse \(a.wir) : \(a.gegner) (davor \(b.wir) : \(b.gegner)).")
                } else if b.gegner > b.wir, a.wir > a.gegner, a.wir >= 3 {
                    emit("kippen_\(sub.seq)", "Seit dem Wechsel in Minute \(sub.time.minuteLabel()): Abschlüsse \(a.wir) : \(a.gegner) (davor \(b.wir) : \(b.gegner)).", severity: "info")
                }
            }
        }
        return out
    }
}
