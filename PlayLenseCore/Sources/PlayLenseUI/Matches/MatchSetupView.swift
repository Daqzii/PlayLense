import SwiftUI
import PlayLenseCore

/// Spiel anlegen oder bearbeiten: Gegner, Datum, Spielrichtung, Profil, Formation, Aufstellung, Bank.
struct MatchSetupView: View {
    @Bindable var model: AppModel
    @State var match: Match
    @State private var assignments: [Int: UUID] = [:]   // Slot-Index in der Formation -> Spieler
    @State private var bench: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, match: Match, existingLineup: [MatchLineup]) {
        self.model = model
        self._match = State(initialValue: match)
        let formation = Formation.named(match.formation)
        var a: [Int: UUID] = [:]
        var used = Set<Position>()
        for l in existingLineup where l.role == .start {
            guard let pos = l.positionKey else { continue }
            // Ersten freien Slot mit dieser Position belegen.
            for (i, p) in formation.positions.enumerated() where p == pos && a[i] == nil {
                a[i] = l.playerId
                used.insert(pos)
                break
            }
        }
        self._assignments = State(initialValue: a)
        self._bench = State(initialValue: Set(existingLineup.filter { $0.role == .bank }.map(\.playerId)))
    }

    private var formation: Formation { Formation.named(match.formation) }
    private var assignedIDs: Set<UUID> { Set(assignments.values) }
    private var candidates: [Player] { model.activePlayers.filter { $0.status != .verletzt || assignedIDs.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Spiel") {
                    TextField("Gegner", text: $match.opponentName)
                    DatePicker("Anpfiff", selection: $match.kickoffPlanned)
                    Picker("Ort", selection: $match.venue) { ForEach(Venue.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    Picker("Wettbewerb", selection: $match.competition) { ForEach(Competition.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                }
                Section {
                    Picker("Wir spielen in der 1. Halbzeit", selection: $match.attackDirectionFirstHalf) {
                        ForEach(AttackDirection.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Ich sitze auf der Gegenseite (Darstellung spiegeln)", isOn: $match.observerSideFlipped)
                    Picker("Erfassungsprofil", selection: $match.trackingProfile) {
                        ForEach(TrackingProfile.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Beobachtung")
                } footer: {
                    Text("Spielrichtung aus deiner Sitzposition. Nach der Halbzeit spiegelt die App das Spielfeld automatisch. Profil Kompakt oder Minimal, wenn du gleichzeitig coachst.")
                }
                Section("Formation") {
                    Picker("Formation", selection: $match.formation) {
                        ForEach(Formation.all) { f in Text(f.name).tag(f.name) }
                    }
                    .onChange(of: match.formation) { _, _ in assignments = [:] }
                }
                Section("Startelf") {
                    ForEach(Array(formation.positions.enumerated()), id: \.offset) { index, pos in
                        Picker(pos.label, selection: Binding(
                            get: { assignments[index] },
                            set: { newValue in
                                if let v = newValue {
                                    for (k, id) in assignments where id == v && k != index { assignments.removeValue(forKey: k) }
                                    bench.remove(v)
                                }
                                assignments[index] = newValue
                            })) {
                            Text("–").tag(UUID?.none)
                            ForEach(candidates) { p in
                                Text(p.shortLabel + (p.primaryPosition == pos ? " ✓" : "")).tag(UUID?.some(p.id))
                            }
                        }
                    }
                    Button("Automatisch nach Hauptposition besetzen") { autoAssign() }
                }
                Section("Bank") {
                    ForEach(model.activePlayers.filter { !assignedIDs.contains($0.id) }) { p in
                        Toggle(p.shortLabel + (p.status == .verletzt ? " (verletzt)" : ""), isOn: Binding(
                            get: { bench.contains(p.id) },
                            set: { on in if on { bench.insert(p.id) } else { bench.remove(p.id) } }))
                    }
                    Button("Alle übrigen auf die Bank") {
                        bench = Set(model.activePlayers.filter { !assignedIDs.contains($0.id) && $0.status != .verletzt }.map(\.id))
                    }
                }
                Section("Notizen") {
                    TextEditor(text: $match.notes).frame(minHeight: 60)
                }
            }
            .navigationTitle(match.opponentName.isEmpty ? "Neues Spiel" : "Spiel gegen \(match.opponentName)")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }.disabled(match.opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func autoAssign() {
        var pool = candidates.filter { $0.status == .aktiv }
        var result: [Int: UUID] = [:]
        for (i, pos) in formation.positions.enumerated() {
            if let idx = pool.firstIndex(where: { $0.primaryPosition == pos }) {
                result[i] = pool.remove(at: idx).id
            }
        }
        for (i, pos) in formation.positions.enumerated() where result[i] == nil {
            if let idx = pool.firstIndex(where: { $0.secondaryPositions.contains(pos) || $0.primaryPosition?.group == pos.group }) {
                result[i] = pool.remove(at: idx).id
            }
        }
        assignments = result
        bench = Set(pool.map(\.id))
    }

    private func save() {
        var lineup: [MatchLineup] = []
        for (i, pos) in formation.positions.enumerated() {
            if let pid = assignments[i] {
                lineup.append(MatchLineup(matchId: match.id, playerId: pid, role: .start, positionKey: pos, numberInMatch: model.player(pid)?.number))
            }
        }
        for pid in bench where !assignedIDs.contains(pid) {
            lineup.append(MatchLineup(matchId: match.id, playerId: pid, role: .bank, numberInMatch: model.player(pid)?.number))
        }
        model.saveMatch(match, lineup: lineup)
        dismiss()
    }
}
