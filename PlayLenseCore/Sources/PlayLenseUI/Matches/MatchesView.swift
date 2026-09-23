import SwiftUI
import PlayLenseCore
import PlayLenseData

public struct MatchesView: View {
    @Bindable var model: AppModel
    @State private var setup: Match?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        List {
            if model.matches.isEmpty {
                ContentUnavailableView("Noch kein Spiel", systemImage: "sportscourt",
                                       description: Text("Lege mit + ein Spiel an, stelle auf und öffne das Match Center."))
            }
            ForEach(model.matches) { m in
                NavigationLink(value: m) {
                    MatchRow(match: m, teamShort: model.team.shortName, db: model.db)
                }
            }
        }
        .navigationTitle("Spiele \(model.season.label)")
        .navigationDestination(for: Match.self) { m in
            MatchOverviewView(model: model, matchId: m.id)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    setup = Match(seasonId: model.season.id, kickoffPlanned: Self.nextSaturday(), opponentName: "")
                } label: {
                    Label("Neues Spiel", systemImage: "plus")
                }
            }
        }
        .sheet(item: $setup) { m in
            MatchSetupView(model: model, match: m, existingLineup: [])
        }
        .errorAlert($model.lastError)
    }

    static func nextSaturday() -> Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = 7
        comps.hour = 15
        comps.minute = 0
        return cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) ?? Date()
    }
}

struct MatchRow: View {
    let match: Match
    let teamShort: String
    let db: AppDatabase

    var body: some View {
        let score = (try? db.fetchEvents(matchId: match.id)).map { MatchStats.compute(events: $0).goals }
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.venue == .heim ? "\(teamShort) – \(match.opponentName)" : "\(match.opponentName) – \(teamShort)")
                    .font(.headline)
                Text(match.kickoffPlanned.formatted(date: .abbreviated, time: .shortened) + " · " + match.competition.label)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let s = score, match.status != .geplant {
                Text(match.venue == .heim ? "\(s.wir) : \(s.gegner)" : "\(s.gegner) : \(s.wir)")
                    .font(.title3.monospacedDigit().bold())
            }
            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch match.status {
        case .geplant: Text("geplant").font(.caption).padding(6).background(Capsule().fill(.gray.opacity(0.2)))
        case .laeuft: Text("läuft").font(.caption.bold()).padding(6).background(Capsule().fill(.green.opacity(0.3)))
        case .beendet: Text("beendet").font(.caption).padding(6).background(Capsule().fill(.blue.opacity(0.15)))
        }
    }
}

/// Spielseite: Aufstellung, Match Center öffnen, Berichte, Statistik.
struct MatchOverviewView: View {
    @Bindable var model: AppModel
    let matchId: UUID
    @State private var bundle: MatchBundle?
    @State private var editSetup = false
    @State private var confirmDelete = false
    @State private var report: MatchReport?
    @State private var showStats = false

    var body: some View {
        Group {
            if let b = bundle {
                content(b)
            } else {
                ProgressView()
            }
        }
        .task(id: matchId) { load() }
        .onChange(of: model.activeSession == nil) { _, _ in load() }
        .onChange(of: model.matches) { _, _ in load() }
    }

    private func load() {
        bundle = try? model.db.fetchMatchBundle(id: matchId)
    }

    @ViewBuilder
    private func content(_ b: MatchBundle) -> some View {
        let stats = MatchStats.compute(events: b.events)
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.team.name).font(.title2.bold())
                        Text(b.match.opponentName).font(.title2.bold())
                    }
                    Spacer()
                    VStack {
                        Text("\(stats.goals.wir)").font(.system(size: 40, weight: .bold).monospacedDigit())
                        Text("\(stats.goals.gegner)").font(.system(size: 40, weight: .bold).monospacedDigit())
                    }
                }
                Text(b.match.kickoffPlanned.formatted(date: .long, time: .shortened) + " · " + b.match.venue.label + " · " + b.match.competition.label + " · " + b.match.formation)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button {
                    model.openMatchCenter(b.match)
                } label: {
                    Label(b.match.status == .beendet ? "Match Center (Nachbearbeitung)" : "Match Center öffnen", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                if b.match.status == .geplant {
                    Button { editSetup = true } label: { Label("Aufstellung und Spieldaten bearbeiten", systemImage: "person.crop.rectangle.stack") }
                }
                Button { showStats = true } label: { Label("Statistik und Zeitfenster", systemImage: "chart.bar") }
            }
            if !b.reports.isEmpty {
                Section("Berichte") {
                    ForEach(b.reports) { r in
                        Button { report = r } label: {
                            Label(r.kind.label + " · " + r.generatedAt.formatted(date: .omitted, time: .shortened), systemImage: "doc.text")
                        }
                    }
                }
            }
            Section("Aufstellung") {
                let starters = b.lineup.filter { $0.role == .start }
                ForEach(starters.sorted { ($0.positionKey?.rawValue ?? "") < ($1.positionKey?.rawValue ?? "") }) { l in
                    HStack {
                        Text(l.positionKey?.short ?? "–").frame(width: 44).font(.caption.bold())
                        Text(model.player(l.playerId)?.shortLabel ?? "?")
                    }
                }
                let bench = b.lineup.filter { $0.role == .bank }
                if !bench.isEmpty {
                    Text("Bank: " + bench.compactMap { model.player($0.playerId)?.shortLabel }.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Spiel löschen", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("\(model.team.shortName) – \(b.match.opponentName)")
        .sheet(isPresented: $editSetup) {
            MatchSetupView(model: model, match: b.match, existingLineup: b.lineup)
        }
        .sheet(item: $report) { r in
            NavigationStack { MatchReportView(report: r, teamColor: Color(hex: model.team.colorHex)) }
        }
        .sheet(isPresented: $showStats) {
            NavigationStack { MatchStatsView(bundle: b, players: model.players) }
        }
        .confirmationDialog("Spiel und alle Events löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { model.deleteMatch(b.match) }
        }
    }
}
