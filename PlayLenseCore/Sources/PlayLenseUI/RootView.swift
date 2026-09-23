import SwiftUI
import UniformTypeIdentifiers
import PlayLenseCore
import PlayLenseData

enum RootSection: String, CaseIterable, Identifiable {
    case spiele, kader, uebungen, einstellungen
    var id: String { rawValue }
    var label: String {
        switch self {
        case .spiele: return "Spiele"
        case .kader: return "Kader"
        case .uebungen: return "Übungen"
        case .einstellungen: return "Einstellungen"
        }
    }
    var icon: String {
        switch self {
        case .spiele: return "sportscourt"
        case .kader: return "person.3"
        case .uebungen: return "figure.soccer"
        case .einstellungen: return "gearshape"
        }
    }
}

public struct RootView: View {
    @Bindable var model: AppModel
    @State private var section: RootSection? = .spiele

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(RootSection.allCases, selection: $section) { s in
                Label(s.label, systemImage: s.icon).tag(s)
            }
            .navigationTitle(model.team.name)
        } detail: {
            NavigationStack {
                switch section ?? .spiele {
                case .spiele: MatchesView(model: model)
                case .kader: SquadView(model: model)
                case .uebungen: ExerciseLibraryView(library: model.exercises)
                case .einstellungen: SettingsView(model: model)
                }
            }
        }
        .fullScreen(item: $model.activeSession) { session in
            MatchCenterView(session: session, teamColor: Color(hex: model.team.colorHex)) {
                model.closeMatchCenter()
            }
        }
        .errorAlert($model.lastError)
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var name = ""
    @State private var shortName = ""
    @State private var colorHex = ""
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var importMessage: String?

    var body: some View {
        Form {
            Section("Verein") {
                TextField("Vereinsname", text: $name)
                TextField("Kürzel", text: $shortName)
                TextField("Farbe (Hex, z. B. #1E5AA8)", text: $colorHex).plainTextInput()
                Button("Speichern") { model.updateTeam(name: name, shortName: shortName, colorHex: colorHex) }
                    .disabled(name.isEmpty || shortName.isEmpty)
            }
            Section {
                if let url = exportURL {
                    ShareLink(item: url, preview: SharePreview(url.lastPathComponent)) {
                        Label("Export teilen: \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
                    }
                }
                Button { exportURL = model.exportBundle() } label: { Label("Backup-Bundle erzeugen (.playlense)", systemImage: "archivebox") }
                Button { showImporter = true } label: { Label("Bundle importieren", systemImage: "square.and.arrow.down") }
                if let m = importMessage { Text(m).font(.caption).foregroundStyle(.secondary) }
            } header: {
                Text("Backup")
            } footer: {
                Text("Das Bundle enthält die komplette Datenbank und lesbares JSON. Ablage in „Dateien“, AirDrop an den Mac oder per Mail. Import führt nach ID zusammen, der neuere Stand gewinnt.")
            }
            Section("Saison") {
                LabeledContent("Aktuelle Saison", value: model.season.label)
                LabeledContent("Spieler", value: "\(model.players.count)")
                LabeledContent("Spiele", value: "\(model.matches.count)")
                LabeledContent("Übungen", value: "\(model.exercises.exercises.count)")
            }
            Section("Vor dem Spiel") {
                Text("Flugmodus oder Nicht stören · Helligkeit hoch · Akku voll · Geführter Zugriff (Einstellungen → Bedienungshilfen) gegen versehentliches Wischen · Sperrbildschirm bleibt im Match Center aus.")
                    .font(.caption)
            }
        }
        .navigationTitle("Einstellungen")
        .onAppear {
            name = model.team.name
            shortName = model.team.shortName
            colorHex = model.team.colorHex
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .json]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let s = model.importBundle(from: url) {
                    importMessage = "Import: \(s.inserted) neu, \(s.updated) aktualisiert, \(s.skipped) unverändert."
                }
            } catch {
                model.lastError = error.localizedDescription
            }
        }
    }
}
