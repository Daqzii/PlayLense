import SwiftUI
import PlayLenseCore

/// Formular zum Anlegen und Bearbeiten einer Übung. Validiert live über `ExerciseValidator`
/// und speichert nur, wenn keine Befunde offen sind.
public struct ExerciseEditorView: View {
    @Bindable var library: ExerciseLibrary
    @State private var draft: Exercise
    @State private var animationJSON: String
    @State private var animationError: String?
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    private let onSaved: (Exercise) -> Void

    public init(library: ExerciseLibrary, exercise: Exercise, onSaved: @escaping (Exercise) -> Void = { _ in }) {
        self.library = library
        self._draft = State(initialValue: exercise)
        self._oldName = State(initialValue: exercise.name)
        self.onSaved = onSaved
        if let anim = exercise.animation, let data = try? ExerciseJSON.encoder().encode(anim) {
            self._animationJSON = State(initialValue: String(decoding: data, as: UTF8.self))
        } else {
            self._animationJSON = State(initialValue: "")
        }
    }

    private var issues: [ValidationIssue] { library.validate(draft) }
    private func issues(for field: String) -> [ValidationIssue] { issues.filter { $0.field == field } }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Grunddaten") {
                    TextField("Name", text: $draft.name)
                    TextField("Slug (z. B. rondo-5v2)", text: $draft.slug)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: draft.name) { _, new in
                            if library.isSeed(draft.id) == false, draft.slug.isEmpty || draft.slug == Self.slugify(oldName) {
                                draft.slug = Self.slugify(new)
                            }
                            oldName = new
                        }
                    issueRows(["name", "slug"])
                }

                Section("Ziele") {
                    Picker("Hauptziel", selection: $draft.goalPrimary) {
                        ForEach(library.vocabulary.goals) { g in Text(g.label).tag(g.key) }
                    }
                    NavigationLink {
                        MultiPickerView(title: "Nebenziele",
                                        options: library.vocabulary.goals.filter { $0.key != draft.goalPrimary }.map { ($0.key, $0.label) },
                                        selection: $draft.goalsSecondary)
                    } label: {
                        LabeledContent("Nebenziele", value: draft.goalsSecondary.isEmpty ? "keine" : "\(draft.goalsSecondary.count)")
                    }
                    issueRows(["goal_primary", "goals_secondary"])
                }

                Section("Organisation") {
                    Stepper("Spieler min: \(draft.playersMin)", value: $draft.playersMin, in: 1...30)
                    Stepper("Spieler max: \(draft.playersMax)", value: $draft.playersMax, in: 1...30)
                    Stepper("Dauer min: \(draft.durationMin) min", value: $draft.durationMin, in: 3...60)
                    Stepper("Dauer max: \(draft.durationMax) min", value: $draft.durationMax, in: 3...60)
                    Picker("Intensität", selection: $draft.intensity) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("Feld Breite: \(draft.fieldWidthM) m", value: $draft.fieldWidthM, in: 5...75, step: 5)
                    Stepper("Feld Länge: \(draft.fieldLengthM) m", value: $draft.fieldLengthM, in: 5...110, step: 5)
                    issueRows(["players", "duration", "intensity", "field"])
                }

                Section("Material") {
                    ForEach(draft.material.indices, id: \.self) { i in
                        HStack {
                            Picker("", selection: $draft.material[i].item) {
                                ForEach(library.vocabulary.material, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            Spacer()
                            Stepper("\(draft.material[i].count)×", value: $draft.material[i].count, in: 1...50)
                        }
                    }
                    .onDelete { draft.material.remove(atOffsets: $0) }
                    Button("Material hinzufügen") {
                        let unused = library.vocabulary.material.first { m in !draft.material.contains { $0.item == m } } ?? "baelle"
                        draft.material.append(MaterialItem(item: unused, count: 1))
                    }
                    issueRows(["material"])
                }

                Section("Beschreibung (was und warum)") {
                    TextEditor(text: $draft.description).frame(minHeight: 70)
                    issueRows(["description"])
                }

                Section("Ablauf (Aufbau, Regeln, Wertung)") {
                    TextEditor(text: $draft.procedure).frame(minHeight: 120)
                    issueRows(["procedure"])
                }

                Section("Coaching Points") {
                    StringListEditor(items: $draft.coachingPoints, placeholder: "Coaching Point")
                    issueRows(["coaching_points"])
                }

                Section("Variationen") {
                    Text("Einfacher").font(.caption).foregroundStyle(.secondary)
                    StringListEditor(items: $draft.variations.easier, placeholder: "Wie wird es leichter?")
                    Text("Schwerer").font(.caption).foregroundStyle(.secondary)
                    StringListEditor(items: $draft.variations.harder, placeholder: "Wie wird es schwerer?")
                    issueRows(["variations"])
                }

                Section("Tags") {
                    ForEach(["form", "ziel", "organisation"], id: \.self) { category in
                        NavigationLink {
                            MultiPickerView(title: "Tags: \(category)",
                                            options: library.vocabulary.tags(in: category).map { ($0.key, $0.label) },
                                            selection: $draft.tags)
                        } label: {
                            LabeledContent(category.capitalized,
                                           value: draft.tags.filter { library.vocabulary.tag($0)?.category == category }
                                               .map { library.vocabulary.tag($0)?.label ?? $0 }.joined(separator: ", "))
                        }
                    }
                    issueRows(["tags"])
                }

                Section {
                    TextEditor(text: $animationJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .onChange(of: animationJSON) { _, new in applyAnimationJSON(new) }
                    if let e = animationError {
                        Label(e, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption)
                    }
                    issueRows(issues.filter { $0.field.hasPrefix("animation") }.map(\.field))
                } header: {
                    Text("Animation (JSON, optional)")
                } footer: {
                    Text("Format siehe docs/05-animationsformat.md. Leer lassen, wenn keine Animation vorhanden ist. Ein grafischer Editor folgt in Ausbaustufe 3.")
                }

                if !issues.isEmpty {
                    Section("Noch zu erledigen (\(issues.count))") {
                        ForEach(issues) { issue in
                            Label("\(issue.field): \(issue.message)", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "Neue Übung" : draft.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(!issues.isEmpty || animationError != nil)
                }
            }
            .alert("Speichern fehlgeschlagen", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    @State private var oldName: String = ""

    private func applyAnimationJSON(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            draft.animation = nil
            animationError = nil
            return
        }
        do {
            draft.animation = try ExerciseJSON.decoder().decode(ExerciseAnimation.self, from: Data(trimmed.utf8))
            animationError = nil
        } catch {
            animationError = "JSON ungültig: \(error.localizedDescription)"
        }
    }

    private func save() {
        var ex = draft
        ex.coachingPoints = ex.coachingPoints.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        ex.variations.easier = ex.variations.easier.filter { !$0.isEmpty }
        ex.variations.harder = ex.variations.harder.filter { !$0.isEmpty }
        if library.isSeed(ex.id) == false, ex.source == "seed" { ex.source = "eigene" }
        do {
            try library.save(ex)
            onSaved(ex)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func issueRows(_ fields: [String]) -> some View {
        ForEach(fields.flatMap { issues(for: $0) }) { issue in
            Label(issue.message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    static func slugify(_ s: String) -> String {
        let map: [Character: String] = ["ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"]
        var out = ""
        var lastDash = true
        for ch in s.lowercased() {
            if let m = map[ch] { out += m; lastDash = false; continue }
            if ch.isLetter || ch.isNumber, ch.isASCII { out.append(ch); lastDash = false }
            else if !lastDash { out.append("-"); lastDash = true }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }
}

/// Liste editierbarer Textzeilen mit Hinzufügen und Löschen.
struct StringListEditor: View {
    @Binding var items: [String]
    let placeholder: String

    var body: some View {
        ForEach(items.indices, id: \.self) { i in
            TextField(placeholder, text: $items[i], axis: .vertical)
        }
        .onDelete { items.remove(atOffsets: $0) }
        Button("Zeile hinzufügen") { items.append("") }
    }
}

/// Mehrfachauswahl aus Schlüssel/Label-Paaren.
struct MultiPickerView: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: [String]

    var body: some View {
        List {
            ForEach(options, id: \.0) { key, label in
                Button {
                    if let i = selection.firstIndex(of: key) { selection.remove(at: i) } else { selection.append(key) }
                } label: {
                    HStack {
                        Text(label).foregroundStyle(.primary)
                        Spacer()
                        if selection.contains(key) { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}
