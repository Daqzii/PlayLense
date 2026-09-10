import SwiftUI
import UniformTypeIdentifiers
import PlayLenseCore

/// Übungsbibliothek: Liste mit Suche und Filtern links, Detail rechts, Editor als Sheet.
public struct ExerciseLibraryView: View {
    @Bindable var library: ExerciseLibrary
    @State private var query = ExerciseLibrary.Query()
    @State private var selection: UUID?
    @State private var editing: Exercise?
    @State private var showImporter = false
    @State private var errorMessage: String?

    public init(library: ExerciseLibrary) {
        self.library = library
    }

    private var results: [Exercise] { library.search(query) }

    public var body: some View {
        NavigationSplitView {
            List(results, selection: $selection) { ex in
                ExerciseRow(exercise: ex, vocabulary: library.vocabulary)
                    .tag(ex.id)
            }
            .searchable(text: $query.text, prompt: "Übung, Tag oder Stichwort")
            .navigationTitle("Übungen (\(results.count))")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Picker("Ziel", selection: $query.goal) {
                            Text("Alle Ziele").tag(String?.none)
                            ForEach(library.vocabulary.goals) { g in Text(g.label).tag(String?.some(g.key)) }
                        }
                        Picker("Form", selection: $query.tag) {
                            Text("Alle Formen").tag(String?.none)
                            ForEach(library.vocabulary.tags(in: "form")) { t in Text(t.label).tag(String?.some(t.key)) }
                        }
                        Toggle("Nur Favoriten", isOn: $query.onlyFavorites)
                        Button("Filter zurücksetzen") { query = ExerciseLibrary.Query() }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    Button { showImporter = true } label: { Label("Importieren", systemImage: "square.and.arrow.down") }
                    Button { editing = Exercise.blank() } label: { Label("Neue Übung", systemImage: "plus") }
                }
            }
        } detail: {
            if let id = selection, let ex = library.exercise(id: id) {
                ExerciseDetailView(exercise: ex, library: library, onEdit: { editing = ex })
            } else {
                ContentUnavailableView("Übung auswählen", systemImage: "figure.soccer",
                                       description: Text("Links eine Übung wählen oder mit + eine neue anlegen."))
            }
        }
        .sheet(item: $editing) { ex in
            ExerciseEditorView(library: library, exercise: ex) { saved in
                selection = saved.id
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: true) { result in
            do {
                for url in try result.get() {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    try library.importJSON(try Data(contentsOf: url))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Import fehlgeschlagen", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let vocabulary: ExerciseVocabulary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name).font(.headline)
                if exercise.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                if exercise.animation != nil { Image(systemName: "play.rectangle").foregroundStyle(.secondary).font(.caption) }
            }
            HStack(spacing: 12) {
                Label(vocabulary.goal(exercise.goalPrimary)?.label ?? exercise.goalPrimary, systemImage: "target")
                Label("\(exercise.playersMin)–\(exercise.playersMax)", systemImage: "person.2")
                Label("\(exercise.durationMin)–\(exercise.durationMax) min", systemImage: "clock")
                Label("\(exercise.intensity)/5", systemImage: "flame")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

public struct ExerciseDetailView: View {
    let exercise: Exercise
    @Bindable var library: ExerciseLibrary
    var onEdit: () -> Void
    @State private var confirmDelete = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let anim = exercise.animation {
                    AnimationPlayerView(animation: anim)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(anim.pitch.widthM / anim.pitch.lengthM, contentMode: .fit)
                        .frame(maxHeight: 420)
                }
                section("Beschreibung") { Text(exercise.description) }
                section("Ablauf") { Text(exercise.procedure) }
                section("Coaching Points") { bullets(exercise.coachingPoints) }
                section("Einfacher") { bullets(exercise.variations.easier) }
                section("Schwerer") { bullets(exercise.variations.harder) }
                section("Material") {
                    Text(exercise.material.map { "\($0.count)× \($0.item)" }.joined(separator: ", "))
                }
                section("Tags") {
                    FlowTags(tags: exercise.tags.map { library.vocabulary.tag($0)?.label ?? $0 })
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { try? library.toggleFavorite(id: exercise.id) } label: {
                    Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                }
                ShareLink(item: exportText, preview: SharePreview(exercise.name)) {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                Button("Bearbeiten", action: onEdit)
                if library.isSeed(exercise.id) {
                    Button("Original wiederherstellen") { try? library.resetToSeed(id: exercise.id) }
                }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Löschen", systemImage: "trash") }
            }
        }
        .confirmationDialog("Übung löschen?", isPresented: $confirmDelete) {
            Button("Löschen", role: .destructive) { try? library.delete(id: exercise.id) }
        } message: {
            Text(library.isSeed(exercise.id)
                 ? "Mitgelieferte Übungen werden ausgeblendet und können wiederhergestellt werden."
                 : "Eigene Übungen werden endgültig gelöscht.")
        }
    }

    private var exportText: String {
        guard let data = try? library.exportJSON(exercise) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(library.vocabulary.goal(exercise.goalPrimary)?.label ?? exercise.goalPrimary)
                .font(.title3).bold()
            if !exercise.goalsSecondary.isEmpty {
                Text("Auch: " + exercise.goalsSecondary.map { library.vocabulary.goal($0)?.label ?? $0 }.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label("\(exercise.playersMin)–\(exercise.playersMax) Spieler", systemImage: "person.2")
                Label("\(exercise.durationMin)–\(exercise.durationMax) Minuten", systemImage: "clock")
                Label("Intensität \(exercise.intensity)/5", systemImage: "flame")
                Label("\(exercise.fieldWidthM) × \(exercise.fieldLengthM) m", systemImage: "rectangle")
            }
            .font(.subheadline)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    private func bullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(item)
                }
            }
        }
    }
}

struct FlowTags: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
        }
    }
}

/// Einfacher Player für das Keyframe-Format. Zeichnet Tokens, Ball und Zonen auf ein Spielfeld.
public struct AnimationPlayerView: View {
    let animation: ExerciseAnimation
    @State private var playing = true
    @State private var startDate = Date()

    public init(animation: ExerciseAnimation) {
        self.animation = animation
    }

    public var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(paused: !playing)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                let duration = max(animation.duration, 0.01)
                let time = animation.loop ? elapsed.truncatingRemainder(dividingBy: duration) : min(elapsed, duration)
                Canvas { ctx, size in
                    draw(in: &ctx, size: size, time: time)
                }
                .background(Color(red: 0.24, green: 0.55, blue: 0.29))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Button {
                    playing.toggle()
                    if playing { startDate = Date() }
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                }
                Text(String(format: "%.1f s", animation.duration)).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let sx = size.width / animation.pitch.widthM
        let sy = size.height / animation.pitch.lengthM
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: x * sx, y: size.height - y * sy) // Ursprung links unten
        }
        for s in animation.staticElements {
            switch s.kind {
            case "zone":
                if let r = s.rectM, r.count == 4 {
                    let rect = CGRect(x: r[0] * sx, y: size.height - (r[1] + r[3]) * sy, width: r[2] * sx, height: r[3] * sy)
                    ctx.fill(Path(rect), with: .color(.blue.opacity(s.opacity ?? 0.15)))
                }
            case "line":
                if let a = s.fromM, let b = s.toM, a.count == 2, b.count == 2 {
                    var p = Path(); p.move(to: pt(a[0], a[1])); p.addLine(to: pt(b[0], b[1]))
                    ctx.stroke(p, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: s.style == "dashed" ? [6, 4] : []))
                }
            case "text":
                if let a = s.atM, a.count == 2, let text = s.text {
                    ctx.draw(Text(text).font(.caption).foregroundStyle(.white), at: pt(a[0], a[1]))
                }
            default: break
            }
        }
        let radius = max(6, min(size.width, size.height) / 40)
        var holderPos: CGPoint?
        for token in animation.tokens {
            guard let p = animation.position(of: token.id, at: time) else { continue }
            let c = pt(p.x, p.y)
            switch token.kind {
            case "player", "neutral":
                let color: Color = token.kind == "neutral" ? .yellow : (token.team == "opp" ? .red : .blue)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
                if let label = token.label, !label.isEmpty {
                    ctx.draw(Text(label).font(.system(size: radius, weight: .bold)).foregroundStyle(.white), at: c)
                }
            case "cone":
                var tri = Path()
                tri.move(to: CGPoint(x: c.x, y: c.y - radius * 0.7))
                tri.addLine(to: CGPoint(x: c.x + radius * 0.6, y: c.y + radius * 0.5))
                tri.addLine(to: CGPoint(x: c.x - radius * 0.6, y: c.y + radius * 0.5))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(.orange))
            case "minigoal", "goal":
                let w = token.kind == "goal" ? radius * 5 : radius * 2.5
                ctx.stroke(Path(CGRect(x: c.x - w / 2, y: c.y - radius * 0.4, width: w, height: radius * 0.8)), with: .color(.white), lineWidth: 2)
            default:
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(.white))
            }
            if currentHolder(at: time) == token.id { holderPos = CGPoint(x: c.x + radius * 0.9, y: c.y + radius * 0.9) }
        }
        let ballPos = holderPos ?? freeBallPosition(at: time, pt: pt)
        if let b = ballPos {
            let r = radius * 0.45
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - r, y: b.y - r, width: r * 2, height: r * 2)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: b.x - r, y: b.y - r, width: r * 2, height: r * 2)), with: .color(.black), lineWidth: 1)
        }
    }

    /// Ballhalter des zuletzt erreichten Keyframes (der Ball "springt" beim Erreichen des Keyframes zum neuen Halter).
    private func currentHolder(at time: Double) -> String? {
        var holder: String?
        for f in animation.keyframes where f.t <= time {
            if let h = f.ball?.holder { holder = h } else if f.ball?.atM != nil { holder = nil }
        }
        return holder
    }

    private func freeBallPosition(at time: Double, pt: (Double, Double) -> CGPoint) -> CGPoint? {
        var at: [Double]?
        for f in animation.keyframes where f.t <= time {
            if let a = f.ball?.atM { at = a } else if f.ball?.holder != nil { at = nil }
        }
        if let a = at, a.count == 2 { return pt(a[0], a[1]) }
        return nil
    }
}
