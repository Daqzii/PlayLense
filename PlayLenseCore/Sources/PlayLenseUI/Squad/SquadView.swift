import SwiftUI
import PlayLenseCore

public struct SquadView: View {
    @Bindable var model: AppModel
    @State private var editing: Player?
    @State private var showInactive = false

    public init(model: AppModel) {
        self.model = model
    }

    private var players: [Player] {
        showInactive ? model.players : model.activePlayers
    }

    public var body: some View {
        List {
            ForEach(PositionGroup.allCases, id: \.self) { group in
                let inGroup = players.filter { ($0.primaryPosition?.group ?? .mittelfeld) == group }
                if !inGroup.isEmpty {
                    Section(group.label) {
                        ForEach(inGroup) { p in
                            Button { editing = p } label: { PlayerRow(player: p) }
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            if players.isEmpty {
                ContentUnavailableView("Noch keine Spieler", systemImage: "person.3",
                                       description: Text("Lege mit + den ersten Spieler an."))
            }
        }
        .navigationTitle("Kader (\(model.activePlayers.count))")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle("Inaktive zeigen", isOn: $showInactive)
                Button { editing = Player(teamId: model.team.id, firstName: "", lastName: "") } label: {
                    Label("Neuer Spieler", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { p in
            PlayerEditorView(player: p, isNew: model.player(p.id) == nil) { saved in
                model.savePlayer(saved)
            } onDelete: { del in
                model.deletePlayer(del)
            }
        }
        .errorAlert($model.lastError)
    }
}

struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            Text(player.numberLabel)
                .font(.title3.monospacedDigit().bold())
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.ownTeam.opacity(0.15)))
            VStack(alignment: .leading) {
                Text(player.displayName).font(.headline)
                HStack(spacing: 8) {
                    if let pos = player.primaryPosition { Text(pos.label) }
                    Text(player.foot.label + "fuß")
                    if player.status != .aktiv {
                        Text(player.status.label).foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct PlayerEditorView: View {
    @State var player: Player
    let isNew: Bool
    let onSave: (Player) -> Void
    let onDelete: (Player) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Vorname", text: $player.firstName)
                    TextField("Nachname", text: $player.lastName)
                    TextField("Spitzname (optional)", text: Binding(get: { player.nickname ?? "" }, set: { player.nickname = $0.isEmpty ? nil : $0 }))
                }
                Section("Spiel") {
                    TextField("Rückennummer", value: $player.number, format: .number).numberInput()
                    Picker("Hauptposition", selection: $player.primaryPosition) {
                        Text("Keine").tag(Position?.none)
                        ForEach(Position.allCases) { p in Text("\(p.short) – \(p.label)").tag(Position?.some(p)) }
                    }
                    Picker("Fuß", selection: $player.foot) {
                        ForEach(Foot.allCases) { f in Text(f.label).tag(f) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Status", selection: $player.status) {
                        ForEach(PlayerStatus.allCases) { s in Text(s.label).tag(s) }
                    }
                    TextField("Geburtsjahr (optional)", value: $player.birthYear, format: .number.grouping(.never)).numberInput()
                }
                Section("Nebenpositionen") {
                    ForEach(Position.allCases) { p in
                        Toggle(p.label, isOn: Binding(
                            get: { player.secondaryPositions.contains(p) },
                            set: { on in
                                if on { if !player.secondaryPositions.contains(p) { player.secondaryPositions.append(p) } }
                                else { player.secondaryPositions.removeAll { $0 == p } }
                            }))
                    }
                }
                Section("Notizen") {
                    TextEditor(text: $player.notes).frame(minHeight: 80)
                }
                if !isNew {
                    Section {
                        Button("Spieler löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "Neuer Spieler" : player.displayName)
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave(player); dismiss() }
                        .disabled(player.firstName.trimmingCharacters(in: .whitespaces).isEmpty && player.lastName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Spieler wirklich löschen? Alle Spielereignisse verlieren die Zuordnung.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { onDelete(player); dismiss() }
            }
        }
    }
}
