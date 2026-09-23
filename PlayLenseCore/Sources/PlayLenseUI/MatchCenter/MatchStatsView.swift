import SwiftUI
import PlayLenseCore
import PlayLenseData

/// Kennzahlen je Zeitfenster: Gesamt, Halbzeiten, letzte 15 Minuten, seit letztem Wechsel.
public struct MatchStatsView: View {
    let bundle: MatchBundle
    let players: [Player]
    @State private var selected: Int = 0
    @Environment(\.dismiss) private var dismiss

    public init(bundle: MatchBundle, players: [Player]) {
        self.bundle = bundle
        self.players = players
    }

    private var windows: [TimeWindow] {
        var w: [TimeWindow] = [.all, .period(1), .period(2)]
        let timeline = PeriodTimeline(periods: bundle.periods)
        let now = MatchClock.currentTime(periods: bundle.periods, status: bundle.match.status)
        let nowAbs = timeline.absolute(now)
        if nowAbs > 900 {
            w.append(TimeWindow(start: timeline.time(absolute: nowAbs - 900), end: nil, label: "Letzte 15 Min"))
        }
        if let sub = bundle.events.filter({ !$0.isDeleted && ($0.type == .wechsel || $0.type == .wechselGegner) }).max(by: { $0.seq < $1.seq }) {
            w.append(TimeWindow(start: sub.time, end: nil, label: "Seit Wechsel \(sub.time.minuteLabel())"))
            w.append(TimeWindow(start: nil, end: sub.time, label: "Vor Wechsel \(sub.time.minuteLabel())"))
        }
        return w
    }

    public var body: some View {
        let ws = windows
        let idx = min(selected, ws.count - 1)
        let stats = MatchStats.compute(events: bundle.events, window: ws[idx])
        List {
            Section {
                Picker("Zeitfenster", selection: $selected) {
                    ForEach(Array(ws.enumerated()), id: \.offset) { i, w in Text(w.label).tag(i) }
                }
                .pickerStyle(.menu)
            }
            Section("Wir : Gegner") {
                statLine("Abschlüsse", stats.shots)
                statLine("davon aufs Tor", stats.shotsOnTarget)
                statLine("Tore", stats.goals)
                statLine("Großchancen", stats.bigChances)
                statLine("Ballgewinne", stats.ballWins)
                statLine("Ballverluste", stats.ballLosses)
                statLine("Angriffe", stats.attacks)
                statLine("Konter", stats.counters)
                statLine("Standards", stats.standards)
            }
            Section("Wir im Detail") {
                LabeledContent("Ballverluste im Aufbau", value: "\(stats.ballLossesBuildUp)")
                LabeledContent("Ballverluste Zentrum", value: "\(stats.ballLossesCentre)")
                LabeledContent("Hohe Ballgewinne", value: "\(stats.highBallWins)")
                LabeledContent("Pressing überspielt", value: "\(stats.pressingBypassed)")
            }
            Section("Angriffsrichtung") {
                sharesRow("Wir", stats.attackShares(.wir))
                sharesRow("Gegner (über unsere Seite)", stats.attackShares(.gegner))
            }
            Section("Zonen (Wir)") {
                HStack(spacing: 24) {
                    heat("Ballverluste", stats.heatmap(.wir, .ballverlust), .red)
                    heat("Ballgewinne", stats.heatmap(.wir, .ballgewinn), .green)
                    heat("Abschlüsse", stats.heatmap(.wir, .abschluss), .blue)
                    heat("Gegner-Ballgewinne", stats.heatmap(.gegner, .ballgewinn), .orange)
                }
            }
            if !stats.flagCounts.isEmpty {
                Section("Flags") {
                    ForEach(stats.flagCounts.sorted { $0.value > $1.value }, id: \.key) { k, v in
                        LabeledContent(FlagDefinition.label(for: k), value: "\(v)×")
                    }
                }
            }
            Section("Spieler") {
                let minutes = LineupEngine.secondsPlayed(lineup: bundle.lineup, events: bundle.events, periods: bundle.periods, status: bundle.match.status)
                ForEach(players.sorted { ($0.number ?? 99) < ($1.number ?? 99) }) { p in
                    let c = stats.playerCounts[p.id] ?? PlayerMatchCounts()
                    let m = (minutes[p.id] ?? 0) / 60
                    if m > 0 || c.shots + c.ballLosses + c.ballWins + c.duelsWon + c.duelsLost > 0 {
                        HStack {
                            Text(p.shortLabel).frame(width: 140, alignment: .leading)
                            Text("\(m)'").frame(width: 44)
                            Text("⚽ \(c.goals)/\(c.shots)").frame(width: 70)
                            Text("BG \(c.ballWins)").frame(width: 50)
                            Text("BV \(c.ballLosses)").frame(width: 50)
                            Text("ZK \(c.duelsWon):\(c.duelsLost)").frame(width: 60)
                        }
                        .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .navigationTitle("Statistik")
        .inlineTitle()
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
    }

    private func statLine(_ label: String, _ c: SideCounts) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(c.wir)").bold().foregroundStyle(Color.ownTeam)
            Text(":")
            Text("\(c.gegner)").bold().foregroundStyle(Color.opponent)
        }
        .font(.body.monospacedDigit())
    }

    private func sharesRow(_ label: String, _ s: [ZoneLane: Int]) -> some View {
        HStack {
            Text(label)
            Spacer()
            ForEach(ZoneLane.allCases) { l in Text("\(l.short) \(s[l] ?? 0)%").monospacedDigit() }
        }
    }

    private func heat(_ title: String, _ data: [Zone: Int], _ color: Color) -> some View {
        var d: [String: Int] = [:]
        for (z, v) in data { d["\(z.row.rawValue)/\(z.lane.rawValue)"] = v }
        return HeatmapMini(title: title, data: d, color: color)
    }
}
