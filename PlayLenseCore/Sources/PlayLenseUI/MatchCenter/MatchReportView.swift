import SwiftUI
import PlayLenseCore

/// Halbzeit- oder Spielbericht: eine Seite, groß genug für die Kabine. Teilen als Text oder PDF.
public struct MatchReportView: View {
    let payload: MatchReportPayload
    let teamColor: Color
    @State private var pdfURL: URL?
    @Environment(\.dismiss) private var dismiss

    public init(payload: MatchReportPayload, teamColor: Color = .ownTeam) {
        self.payload = payload
        self.teamColor = teamColor
    }

    public init(report: MatchReport, teamColor: Color = .ownTeam) {
        self.payload = report.payload() ?? MatchReportPayload(kind: report.kind, generatedAt: report.generatedAt, teamName: "", opponentName: "", score: SideCounts(), findings: [], lines: [], attackSharesWir: [:], attackSharesGegner: [:], ballLossHeatmap: [:], ballWinHeatmap: [:], flags: [], notes: [], insights: [])
        self.teamColor = teamColor
    }

    public var body: some View {
        ScrollView {
            ReportContent(payload: payload, teamColor: teamColor)
                .padding()
        }
        .navigationTitle(payload.kind.label)
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: payload.plainText(), preview: SharePreview(payload.kind.label)) {
                    Label("Als Text teilen", systemImage: "text.alignleft")
                }
                if let url = pdfURL {
                    ShareLink(item: url, preview: SharePreview(payload.kind.label + ".pdf")) {
                        Label("PDF teilen", systemImage: "doc.richtext")
                    }
                } else {
                    Button { pdfURL = ReportPDF.render(payload: payload, teamColor: teamColor) } label: {
                        Label("PDF erzeugen", systemImage: "doc.richtext")
                    }
                }
            }
        }
    }
}

struct ReportContent: View {
    let payload: MatchReportPayload
    let teamColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(payload.teamName).font(.title.bold()).foregroundStyle(teamColor)
                Text("\(payload.score.wir) : \(payload.score.gegner)").font(.system(size: 40, weight: .black).monospacedDigit())
                Text(payload.opponentName).font(.title.bold()).foregroundStyle(Color.opponent)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(payload.kind.label).font(.headline)
                    Text(payload.generatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
            }
            if !payload.findings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Auffällig").font(.headline)
                    ForEach(payload.findings) { f in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(f.severity == .rot ? Color.red : (f.severity == .gruen ? Color.green : Color.gray)).frame(width: 12, height: 12).padding(.top, 4)
                            Text(f.text).font(.title3)
                        }
                    }
                }
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zahlen").font(.headline)
                    ForEach(payload.lines, id: \.label) { l in
                        HStack {
                            Text(l.label).frame(width: 150, alignment: .leading)
                            Text("\(l.wir)").bold().frame(width: 40, alignment: .trailing).foregroundStyle(teamColor)
                            Text(":")
                            Text("\(l.gegner)").bold().frame(width: 40, alignment: .leading).foregroundStyle(Color.opponent)
                        }
                        .font(.body.monospacedDigit())
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SharesBar(title: "Unsere Angriffe", shares: payload.attackSharesWir, color: teamColor)
                    SharesBar(title: "Gegner-Angriffe über unsere Seite", shares: payload.attackSharesGegner, color: .opponent)
                }
                HeatmapMini(title: "Ballverluste", data: payload.ballLossHeatmap, color: .red)
                HeatmapMini(title: "Ballgewinne", data: payload.ballWinHeatmap, color: .green)
            }
            if !payload.flags.isEmpty {
                NotesBlock(title: "Flags", notes: payload.flags)
            }
            if !payload.insights.isEmpty {
                NotesBlock(title: "Live-Hinweise", notes: payload.insights)
            }
            if !payload.notes.isEmpty {
                NotesBlock(title: "Coach Notes", notes: payload.notes)
            }
        }
    }
}

struct SharesBar: View {
    let title: String
    let shares: [String: Int]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            if shares.isEmpty {
                Text("keine Angriffe erfasst").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 2) {
                    ForEach(["links", "zentrum", "rechts"], id: \.self) { lane in
                        let v = shares[lane] ?? 0
                        VStack(spacing: 2) {
                            Text("\(v)%").font(.caption.bold())
                            Rectangle().fill(color.opacity(0.25 + Double(v) / 130)).frame(width: 60, height: 22)
                                .overlay(Text(lane.prefix(1).uppercased()).font(.caption2).foregroundStyle(.white))
                        }
                    }
                }
            }
        }
    }
}

struct HeatmapMini: View {
    let title: String
    let data: [String: Int]
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.subheadline.bold())
            let maxV = max(1, data.values.max() ?? 1)
            VStack(spacing: 2) {
                ForEach([ZoneRow.angriffsdrittel, .mittelfeld, .eigenesDrittel], id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(ZoneLane.allCases) { lane in
                            let v = data["\(row.rawValue)/\(lane.rawValue)"] ?? 0
                            Text(v == 0 ? "" : "\(v)")
                                .font(.caption.bold())
                                .frame(width: 34, height: 26)
                                .background(color.opacity(v == 0 ? 0.08 : 0.2 + 0.7 * Double(v) / Double(maxV)))
                        }
                    }
                }
            }
            Text("▲ Gegner-Tor").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct NotesBlock: View {
    let title: String
    let notes: [ReportNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                HStack(alignment: .top) {
                    Text(n.minute).monospacedDigit().frame(width: 44, alignment: .leading).foregroundStyle(.secondary)
                    Text(n.text)
                }
            }
        }
    }
}

/// PDF über `ImageRenderer`, läuft ohne UIKit-Abhängigkeit und offline.
enum ReportPDF {
    @MainActor
    static func render(payload: MatchReportPayload, teamColor: Color) -> URL? {
        let content = ReportContent(payload: payload, teamColor: teamColor)
            .padding(32)
            .frame(width: 842)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 842, height: nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(payload.kind.label)-\(Int(Date().timeIntervalSince1970)).pdf")
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL), let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}
