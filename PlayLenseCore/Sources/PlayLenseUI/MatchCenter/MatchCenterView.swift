import SwiftUI
import PlayLenseCore

enum MatchSheet: Identifiable {
    case flags, note, substitution, stats, trash
    case editEvent(MatchEvent)
    case report(ReportKind)

    var id: String {
        switch self {
        case .flags: return "flags"
        case .note: return "note"
        case .substitution: return "substitution"
        case .stats: return "stats"
        case .trash: return "trash"
        case .editEvent(let e): return "edit-\(e.id)"
        case .report(let k): return "report-\(k.rawValue)"
        }
    }
}

/// Der Bildschirm während des Spiels. Querformat, große Tasten, alles in maximal drei Taps.
public struct MatchCenterView: View {
    @Bindable var session: MatchSession
    let teamColor: Color
    let onClose: () -> Void
    @State private var sheet: MatchSheet?
    @State private var confirmFinish = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init(session: MatchSession, teamColor: Color = .ownTeam, onClose: @escaping () -> Void) {
        self.session = session
        self.teamColor = teamColor
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 8) {
            ClockBar(session: session, teamColor: teamColor, sheet: $sheet, confirmFinish: $confirmFinish, onClose: onClose)
            if let b = session.banner {
                InsightBanner(insight: b) { session.banner = nil }
            }
            HStack(spacing: 8) {
                EventColumn(session: session, side: .wir, color: teamColor)
                    .frame(width: 170)
                VStack(spacing: 8) {
                    ZStack {
                        PitchGridView(session: session)
                        PendingOverlay(session: session)
                    }
                    UtilityBar(session: session, sheet: $sheet)
                }
                EventColumn(session: session, side: .gegner, color: .opponent)
                    .frame(width: 170)
            }
            HStack(spacing: 8) {
                PlayerStrip(session: session, color: teamColor)
                EventLogView(session: session, sheet: $sheet)
                    .frame(width: 320)
            }
            .frame(height: 140)
        }
        .padding(8)
        .background(Color(white: 0.09).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onReceive(timer) { session.tick(now: $0) }
        .onAppear { IdleTimer.setDisabled(true) }
        .onDisappear { IdleTimer.setDisabled(false) }
        .sheet(item: $sheet) { item in sheetContent(item) }
        .confirmationDialog("Spiel beenden? Danach wird der Spielbericht erzeugt.", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Abpfiff", role: .destructive) {
                session.finishMatch()
                sheet = .report(.ende)
            }
        }
        .errorAlert($session.lastError)
    }

    @ViewBuilder
    private func sheetContent(_ item: MatchSheet) -> some View {
        switch item {
        case .flags:
            FlagSheet { key in session.addFlag(key: key) }
        case .note:
            NoteSheet { text in session.addNote(text) }
        case .substitution:
            SubstitutionSheet(session: session)
        case .stats:
            NavigationStack {
                MatchStatsView(bundle: MatchBundle(match: session.match, periods: session.periods, lineup: session.lineup, events: session.events, insights: session.insights, reports: []), players: Array(session.players.values))
            }
        case .trash:
            TrashSheet(session: session)
        case .editEvent(let e):
            EventEditSheet(session: session, event: e)
        case .report(let kind):
            ReportSheet(session: session, kind: kind, teamColor: teamColor)
        }
    }
}

// MARK: - Uhr und Spielstand

struct ClockBar: View {
    @Bindable var session: MatchSession
    let teamColor: Color
    @Binding var sheet: MatchSheet?
    @Binding var confirmFinish: Bool
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { onClose() } label: { Image(systemName: "chevron.left").font(.title2.bold()).frame(width: 44, height: 44) }
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 0) {
                Text(session.periodLabel).font(.caption).foregroundStyle(.secondary)
                Text(session.clockText).font(.system(size: 34, weight: .bold).monospacedDigit()).foregroundStyle(.white)
            }
            .frame(width: 150, alignment: .leading)
            HStack(spacing: 10) {
                Text(session.teamName).font(.headline).foregroundStyle(teamColor)
                Text("\(session.score.wir) : \(session.score.gegner)").font(.system(size: 30, weight: .black).monospacedDigit()).foregroundStyle(.white)
                Text(session.match.opponentName).font(.headline).foregroundStyle(Color.opponent)
            }
            Spacer()
            clockButtons
            Button { session.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .buttonStyle(.bordered).disabled(session.logEvents.isEmpty)
            Menu {
                Button { sheet = .report(.halbzeit) } label: { Label("Halbzeitbericht", systemImage: "doc.text") }
                Button { sheet = .report(.ende) } label: { Label("Spielbericht", systemImage: "doc.text.fill") }
                Button { sheet = .stats } label: { Label("Statistik und Zeitfenster", systemImage: "chart.bar") }
                Button { sheet = .trash } label: { Label("Gelöschte Events", systemImage: "trash") }
                Divider()
                Button { session.adjustCurrentPeriodStart(by: 30) } label: { Label("Uhr +30 s", systemImage: "plus.circle") }
                Button { session.adjustCurrentPeriodStart(by: -30) } label: { Label("Uhr −30 s", systemImage: "minus.circle") }
                Button { session.flipDisplay.toggle() } label: { Label("Spielfeld spiegeln", systemImage: "arrow.left.arrow.right") }
                Button { session.addExtraTimePeriod() } label: { Label("Verlängerung hinzufügen", systemImage: "clock.badge.plus") }
                Button { session.opponentSubstitution() } label: { Label("Gegner-Wechsel markieren", systemImage: "arrow.triangle.2.circlepath") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title2).frame(width: 44, height: 44)
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
    }

    @ViewBuilder
    private var clockButtons: some View {
        switch session.clockState {
        case .notStarted:
            Button { session.startNextPeriod() } label: { Label("Anpfiff", systemImage: "play.fill") }
                .buttonStyle(.borderedProminent).tint(.green)
        case .running(let p, _):
            let isLast = session.nextPeriodNumber == nil
            if isLast {
                Button { confirmFinish = true } label: { Label("Abpfiff", systemImage: "stop.fill") }
                    .buttonStyle(.borderedProminent).tint(.red)
            } else {
                Button {
                    session.endCurrentPeriod()
                    if p == 1 { sheet = .report(.halbzeit) }
                } label: { Label(p == 1 ? "Halbzeit" : "Periode beenden", systemImage: "pause.fill") }
                    .buttonStyle(.borderedProminent).tint(.orange)
            }
        case .paused:
            if let n = session.nextPeriodNumber {
                Button { session.startNextPeriod() } label: { Label(n == 2 ? "2. Halbzeit" : "Weiter", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent).tint(.green)
            } else {
                Button { confirmFinish = true } label: { Label("Abpfiff", systemImage: "stop.fill") }
                    .buttonStyle(.borderedProminent).tint(.red)
            }
        case .finished:
            Button { sheet = .report(.ende) } label: { Label("Spielbericht", systemImage: "doc.text") }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct InsightBanner: View {
    let insight: MatchInsight
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: insight.severity == "info" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(insight.text).font(.headline)
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
        }
        .padding(10)
        .foregroundStyle(.black)
        .background(RoundedRectangle(cornerRadius: 10).fill(insight.severity == "info" ? Color.green.opacity(0.9) : Color.yellow.opacity(0.95)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Event-Spalten

struct EventColumn: View {
    @Bindable var session: MatchSession
    let side: Side
    let color: Color

    private var types: [EventType] {
        EventType.teamEvents.filter { session.availableEventTypes.contains($0) && (side == .wir || $0.availableForOpponent) }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(side == .wir ? "WIR" : "GEGNER").font(.caption.bold()).foregroundStyle(color)
            ForEach(types) { t in
                let active = session.pending?.type == t && session.pending?.side == side
                Button { session.tapEvent(t, side: side) } label: {
                    Text(t.label).minimumScaleFactor(0.7).lineLimit(1)
                }
                .buttonStyle(BigButtonStyle(color: active ? .white : color, minHeight: 44, foreground: active ? color : .white))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Color.white : .clear, lineWidth: 3))
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Spielfeld

struct PitchGridView: View {
    @Bindable var session: MatchSession
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let g = session.geometry
            let w = geo.size.width
            let h = geo.size.height
            let cellW = w / 3
            let cellH = h / 3
            let waiting = session.pending?.needsZoneTap == true
            let laneOnly = session.pending?.step == .lane
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color.pitchGreen)
                // Mittellinie und Tore
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: 0)); p.addLine(to: CGPoint(x: w / 2, y: h))
                }
                .stroke(.white.opacity(0.5), lineWidth: 2)
                goalMarker(x: g.ownGoalOnLeft ? 0 : w, h: h, own: true)
                goalMarker(x: g.ownGoalOnLeft ? w : 0, h: h, own: false)
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { col in
                        let zone = g.zone(column: col, row: row)
                        let highlight = waiting
                        RoundedRectangle(cornerRadius: 6)
                            .fill(highlight ? Color.white.opacity(pulse ? 0.22 : 0.08) : Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.35), lineWidth: 1))
                            .overlay(alignment: .topLeading) {
                                Text(laneOnly ? zone.lane.label : zone.label)
                                    .font(.caption2.bold()).foregroundStyle(.white.opacity(0.8)).padding(4)
                            }
                            .frame(width: cellW - 4, height: cellH - 4)
                            .position(x: cellW * CGFloat(col) + cellW / 2, y: cellH * CGFloat(row) + cellH / 2)
                    }
                }
                Text(g.ownGoalOnLeft ? "EIGENES TOR ◀" : "▶ EIGENES TOR")
                    .font(.caption2.bold()).foregroundStyle(.white.opacity(0.9)).padding(6)
                    .frame(maxWidth: .infinity, alignment: g.ownGoalOnLeft ? .leading : .trailing)
                    .frame(width: w, height: h, alignment: .bottom)
                if !waiting {
                    Text(session.pending == nil ? "Event links oder rechts wählen, dann Zone tippen" : "")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                        .frame(width: w, height: h, alignment: .center)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                let col = Int(point.x / cellW)
                let row = Int(point.y / cellH)
                session.tapZone(column: col, row: row, screenX: point.x / w, screenY: point.y / h)
            }
            .onChange(of: waiting) { _, on in
                if on {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
                } else {
                    withAnimation(.default) { pulse = false }
                }
            }
        }
    }

    private func goalMarker(x: CGFloat, h: CGFloat, own: Bool) -> some View {
        Rectangle()
            .fill(own ? Color.ownTeam : Color.opponent)
            .frame(width: 6, height: h * 0.3)
            .position(x: x, y: h / 2)
    }
}

/// Dritte Stufe: Ergebnis, Standard-Typ, Karten-Typ oder Spielerwahl.
struct PendingOverlay: View {
    @Bindable var session: MatchSession

    var body: some View {
        if let p = session.pending {
            VStack(spacing: 10) {
                switch overlayKind(p) {
                case .shotOutcome:
                    Text("Abschluss \(p.side == .wir ? session.teamName : session.match.opponentName): Ergebnis?").font(.headline)
                    HStack(spacing: 10) {
                        ForEach(ShotOutcome.allCases) { o in
                            Button(o.label) { session.choose(outcome: o.rawValue) }
                                .buttonStyle(BigButtonStyle(color: o == .tor ? .green : .gray, minHeight: 64))
                        }
                    }
                    Button("Ohne Ergebnis speichern") { session.choose(outcome: "") }.foregroundStyle(.white)
                case .duelOutcome:
                    Text("Zweikampf \(session.player(p.playerId)?.shortLabel ?? ""): Ergebnis?").font(.headline)
                    HStack(spacing: 10) {
                        ForEach(DuelOutcome.allCases) { o in
                            Button(o.label) { session.choose(outcome: o.rawValue) }
                                .buttonStyle(BigButtonStyle(color: o == .gewonnen ? .green : .red, minHeight: 64))
                        }
                    }
                case .standardType:
                    Text("Standard \(p.side == .wir ? session.teamName : session.match.opponentName)").font(.headline)
                    HStack(spacing: 10) {
                        ForEach(StandardType.allCases) { s in
                            Button(s.label) { session.choose(subtype: s.rawValue) }
                                .buttonStyle(BigButtonStyle(color: .gray, minHeight: 64))
                        }
                    }
                case .cardType:
                    Text("Karte").font(.headline)
                    HStack(spacing: 10) {
                        Button("Gelb") { session.choose(subtype: CardType.gelb.rawValue) }.buttonStyle(BigButtonStyle(color: .yellow, minHeight: 64))
                        Button("Gelb-Rot") { session.choose(subtype: CardType.gelbrot.rawValue) }.buttonStyle(BigButtonStyle(color: .orange, minHeight: 64))
                        Button("Rot") { session.choose(subtype: CardType.rot.rawValue) }.buttonStyle(BigButtonStyle(color: .red, minHeight: 64))
                    }
                case .player:
                    Text("\(p.type.label): Spieler unten antippen").font(.headline)
                case .nothing:
                    EmptyView()
                }
                if overlayKind(p) != .nothing {
                    Button("Abbrechen") { session.cancelPending() }.foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(16)
            .frame(maxWidth: 520)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(overlayKind(p) == .nothing ? 0 : 0.85)))
            .foregroundStyle(.white)
            .allowsHitTesting(overlayKind(p) != .nothing)
        }
    }

    enum Kind { case shotOutcome, duelOutcome, standardType, cardType, player, nothing }

    func overlayKind(_ p: MatchSession.PendingEvent) -> Kind {
        switch p.type {
        case .abschluss:
            return p.zone != nil && p.outcome == nil ? .shotOutcome : .nothing
        case .zweikampf:
            if p.playerId == nil { return .player }
            return p.outcome == nil ? .duelOutcome : .nothing
        case .standard:
            return p.subtype == nil ? .standardType : .nothing
        case .karte:
            if p.subtype == nil { return .cardType }
            return p.playerId == nil ? .player : .nothing
        case .verletzung:
            return p.playerId == nil ? .player : .nothing
        default:
            return .nothing
        }
    }
}

// MARK: - Mittelleiste

struct UtilityBar: View {
    @Bindable var session: MatchSession
    @Binding var sheet: MatchSheet?

    var body: some View {
        HStack(spacing: 6) {
            if session.availableEventTypes.contains(.flag) {
                Button { sheet = .flags } label: { Label("Flag", systemImage: "flag.fill") }.buttonStyle(BigButtonStyle(color: .orange, minHeight: 48))
            }
            if session.availableEventTypes.contains(.notiz) {
                Button { sheet = .note } label: { Label("Notiz", systemImage: "square.and.pencil") }.buttonStyle(BigButtonStyle(color: .gray, minHeight: 48))
            }
            Button { sheet = .substitution } label: { Label("Wechsel", systemImage: "arrow.triangle.2.circlepath") }.buttonStyle(BigButtonStyle(color: .teal, minHeight: 48))
            Button { session.tapEvent(.karte, side: .wir) } label: { Label("Karte", systemImage: "rectangle.portrait.fill") }.buttonStyle(BigButtonStyle(color: .yellow, minHeight: 48))
            Button { session.tapEvent(.verletzung, side: .wir) } label: { Label("Verletzt", systemImage: "cross.fill") }.buttonStyle(BigButtonStyle(color: .pink, minHeight: 48))
            if session.availableEventTypes.contains(.zweikampf) {
                Button { session.tapEvent(.zweikampf, side: .wir) } label: { Label("Zweikampf", systemImage: "figure.soccer") }.buttonStyle(BigButtonStyle(color: .indigo, minHeight: 48))
            }
        }
    }
}

// MARK: - Spielerleiste

struct PlayerStrip: View {
    @Bindable var session: MatchSession
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.selectedPlayerId == nil ? "Spieler antippen = nächstes Event gehört ihm" : "Nächstes Event: \(session.player(session.selectedPlayerId)?.shortLabel ?? "")")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.onPitchPlayers) { p in
                        let selected = session.selectedPlayerId == p.id
                        Button { session.togglePlayerPrefix(p.id) } label: {
                            VStack(spacing: 2) {
                                Text(p.numberLabel).font(.system(size: 24, weight: .bold).monospacedDigit())
                                Text(session.pitchState.position(of: p.id)?.short ?? p.lastName.prefix(6).uppercased()).font(.caption2)
                            }
                            .frame(width: 66, height: 66)
                            .background(Circle().fill(selected ? Color.white : color))
                            .foregroundStyle(selected ? color : .white)
                            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: selected ? 4 : 1))
                        }
                    }
                    if session.onPitchPlayers.isEmpty {
                        Text("Keine Aufstellung hinterlegt. Events lassen sich trotzdem erfassen.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Log

struct EventLogView: View {
    @Bindable var session: MatchSession
    @Binding var sheet: MatchSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Letzte Events").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(session.logEvents.prefix(60)) { e in
                        Button { sheet = .editEvent(e) } label: {
                            HStack(spacing: 6) {
                                Text(e.time.display(nominalSeconds: session.nominalSeconds)).font(.caption.monospacedDigit()).frame(width: 52, alignment: .leading)
                                Circle().fill(e.side == .wir ? Color.ownTeam : (e.side == .gegner ? Color.opponent : Color.gray)).frame(width: 8, height: 8)
                                Text(e.logSummary(flagLabel: FlagDefinition.label(for:))).font(.caption).lineLimit(1)
                                if let p = session.player(e.playerId) { Text(p.numberLabel).font(.caption.bold()).foregroundStyle(.yellow) }
                                if let p2 = session.player(e.playerId2) { Text("→ \(p2.numberLabel)").font(.caption.bold()).foregroundStyle(.yellow) }
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.16)))
    }
}

// MARK: - Sheets

struct FlagSheet: View {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 12) {
                ForEach(FlagDefinition.groups, id: \.self) { group in
                    VStack(spacing: 8) {
                        Text(group).font(.headline)
                        ForEach(FlagDefinition.defaults.filter { $0.group == group }) { f in
                            Button(f.label) { onPick(f.key); dismiss() }
                                .buttonStyle(BigButtonStyle(color: group == "Positiv" ? .green : (group == "Defensive" ? .red : .orange), minHeight: 52))
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .navigationTitle("Flag setzen")
            .inlineTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}

struct NoteSheet: View {
    let onSave: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text).focused($focused).frame(minHeight: 160).padding()
                Text("Tipp: Mikrofon-Taste auf der Tastatur für Diktat (funktioniert offline).").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Notiz")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { onSave(text); dismiss() }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear { focused = true }
        }
    }
}

struct SubstitutionSheet: View {
    @Bindable var session: MatchSession
    @State private var out: UUID?
    @State private var inn: UUID?
    @State private var position: Position?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Raus") {
                    Picker("Spieler", selection: $out) {
                        Text("– (nur Einwechslung)").tag(UUID?.none)
                        ForEach(session.onPitchPlayers) { p in Text(p.shortLabel).tag(UUID?.some(p.id)) }
                    }
                    .onChange(of: out) { _, new in position = new.flatMap { session.pitchState.position(of: $0) } }
                }
                Section("Rein") {
                    Picker("Spieler", selection: $inn) {
                        Text("–").tag(UUID?.none)
                        ForEach(session.benchPlayers) { p in Text(p.shortLabel).tag(UUID?.some(p.id)) }
                    }
                }
                Section("Position des Eingewechselten") {
                    Picker("Position", selection: $position) {
                        Text("Wie Ausgewechselter").tag(Position?.none)
                        ForEach(Position.allCases) { p in Text(p.label).tag(Position?.some(p)) }
                    }
                }
                Section {
                    Text("Rückwechsel sind erlaubt: Ausgewechselte bleiben auf der Bank und können wieder eingewechselt werden.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Wechsel \(session.clockText)")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Wechseln") {
                        if let i = inn { session.substitute(out: out, in: i, position: position) }
                        dismiss()
                    }
                    .disabled(inn == nil)
                }
            }
        }
    }
}

struct TrashSheet: View {
    @Bindable var session: MatchSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.deletedEvents) { e in
                    HStack {
                        Text(e.time.display(nominalSeconds: session.nominalSeconds)).monospacedDigit()
                        Text(e.logSummary(flagLabel: FlagDefinition.label(for:)))
                        Spacer()
                        Button("Wiederherstellen") { session.restore(e) }
                    }
                }
                if session.deletedEvents.isEmpty { Text("Keine gelöschten Events.") }
            }
            .navigationTitle("Gelöschte Events")
            .inlineTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

struct EventEditSheet: View {
    @Bindable var session: MatchSession
    @State var event: MatchEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    LabeledContent("Typ", value: event.type.label)
                    Picker("Seite", selection: $event.side) { ForEach(Side.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    Stepper("Periode \(event.period)", value: $event.period, in: 1...4)
                    Stepper("Minute \(event.matchSecond / 60)", value: Binding(get: { event.matchSecond / 60 }, set: { event.matchSecond = $0 * 60 + event.matchSecond % 60 }), in: 0...70)
                }
                Section("Zone") {
                    Picker("Drittel", selection: $event.zoneRow) {
                        Text("–").tag(ZoneRow?.none)
                        ForEach(ZoneRow.allCases) { Text($0.label).tag(ZoneRow?.some($0)) }
                    }
                    Picker("Seite", selection: $event.zoneLane) {
                        Text("–").tag(ZoneLane?.none)
                        ForEach(ZoneLane.allCases) { Text($0.label).tag(ZoneLane?.some($0)) }
                    }
                }
                if event.type == .abschluss {
                    Section("Ergebnis") {
                        Picker("Ergebnis", selection: $event.outcome) {
                            Text("–").tag(String?.none)
                            ForEach(ShotOutcome.allCases) { Text($0.label).tag(String?.some($0.rawValue)) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Tor-Art", selection: $event.subtype) {
                            Text("–").tag(String?.none)
                            ForEach(GoalKind.allCases) { Text($0.label).tag(String?.some($0.rawValue)) }
                        }
                    }
                }
                if event.type == .standard {
                    Section("Standard") {
                        Picker("Art", selection: $event.subtype) {
                            ForEach(StandardType.allCases) { Text($0.label).tag(String?.some($0.rawValue)) }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Gefährlich", isOn: Binding(get: { event.outcome == "gefaehrlich" }, set: { event.outcome = $0 ? "gefaehrlich" : nil }))
                    }
                }
                if event.side == .wir {
                    Section("Spieler") {
                        Picker("Spieler", selection: $event.playerId) {
                            Text("–").tag(UUID?.none)
                            ForEach(Array(session.players.values).sorted { ($0.number ?? 99) < ($1.number ?? 99) }) { p in Text(p.shortLabel).tag(UUID?.some(p.id)) }
                        }
                    }
                }
                if event.type == .flag {
                    Section("Flag") {
                        Picker("Flag", selection: $event.flagKey) {
                            ForEach(FlagDefinition.defaults) { Text($0.label).tag(String?.some($0.key)) }
                        }
                    }
                }
                Section("Notiz") {
                    TextField("Notiz", text: Binding(get: { event.note ?? "" }, set: { event.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                }
                Section {
                    Button("Event löschen", role: .destructive) { session.delete(event); dismiss() }
                }
            }
            .navigationTitle("Event bearbeiten")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { session.update(event); dismiss() } }
            }
        }
    }
}

/// Erzeugt den Bericht genau einmal beim Öffnen und speichert ihn.
struct ReportSheet: View {
    @Bindable var session: MatchSession
    let kind: ReportKind
    let teamColor: Color
    @State private var payload: MatchReportPayload?

    var body: some View {
        NavigationStack {
            if let p = payload {
                MatchReportView(payload: p, teamColor: teamColor)
            } else {
                ProgressView().task { payload = session.generateReport(kind) }
            }
        }
    }
}
