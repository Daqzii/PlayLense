import Foundation

/// Ein Befund der Validierung. `field` ist der JSON-Schlüssel, auf den sich der Befund bezieht.
public struct ValidationIssue: Hashable, Sendable, Identifiable {
    public var field: String
    public var message: String
    public var id: String { field + "|" + message }

    public init(_ field: String, _ message: String) {
        self.field = field
        self.message = message
    }
}

/// Spiegelt die Regeln aus tools/exercises.py, damit Übungen in der App und in der Datei dieselben
/// Anforderungen erfüllen.
public struct ExerciseValidator: Sendable {
    public let vocabulary: ExerciseVocabulary

    public init(vocabulary: ExerciseVocabulary) {
        self.vocabulary = vocabulary
    }

    public func validate(_ ex: Exercise, existingSlugs: Set<String> = []) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let slugPattern = try! NSRegularExpression(pattern: "^[a-z0-9]+(?:-[a-z0-9]+)*$")

        if slugPattern.firstMatch(in: ex.slug, range: NSRange(ex.slug.startIndex..., in: ex.slug)) == nil {
            issues.append(.init("slug", "Nur Kleinbuchstaben, Ziffern und Bindestriche, z. B. rondo-5v2"))
        }
        if existingSlugs.contains(ex.slug) {
            issues.append(.init("slug", "Dieser Slug existiert bereits"))
        }
        if ex.name.trimmingCharacters(in: .whitespaces).count < 3 {
            issues.append(.init("name", "Name fehlt"))
        }
        if vocabulary.goal(ex.goalPrimary) == nil {
            issues.append(.init("goal_primary", "Unbekanntes Hauptziel '\(ex.goalPrimary)'"))
        }
        for g in ex.goalsSecondary {
            if vocabulary.goal(g) == nil { issues.append(.init("goals_secondary", "Unbekanntes Nebenziel '\(g)'")) }
            if g == ex.goalPrimary { issues.append(.init("goals_secondary", "Hauptziel darf nicht auch Nebenziel sein")) }
        }
        if !(1...30).contains(ex.playersMin) || ex.playersMin > ex.playersMax || ex.playersMax > 30 {
            issues.append(.init("players", "Spielerzahl min/max ungültig (1–30, min ≤ max)"))
        }
        if !(3...60).contains(ex.durationMin) || ex.durationMin > ex.durationMax || ex.durationMax > 60 {
            issues.append(.init("duration", "Dauer min/max ungültig (3–60 Minuten, min ≤ max)"))
        }
        if !(1...5).contains(ex.intensity) {
            issues.append(.init("intensity", "Intensität muss 1 bis 5 sein"))
        }
        if !(5...75).contains(ex.fieldWidthM) || !(5...110).contains(ex.fieldLengthM) {
            issues.append(.init("field", "Feldmaße unplausibel (Breite 5–75 m, Länge 5–110 m)"))
        }
        for m in ex.material {
            if !vocabulary.material.contains(m.item) { issues.append(.init("material", "Unbekanntes Material '\(m.item)'")) }
            if m.count < 1 { issues.append(.init("material", "Stückzahl für '\(m.item)' muss mindestens 1 sein")) }
        }
        if ex.description.count < 30 {
            issues.append(.init("description", "Beschreibung zu kurz (mindestens 30 Zeichen)"))
        }
        if ex.procedure.count < 60 {
            issues.append(.init("procedure", "Ablauf zu kurz (mindestens 60 Zeichen)"))
        }
        let points = ex.coachingPoints.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if points.count < 3 {
            issues.append(.init("coaching_points", "Mindestens drei Coaching Points"))
        }
        if ex.variations.easier.filter({ !$0.isEmpty }).isEmpty || ex.variations.harder.filter({ !$0.isEmpty }).isEmpty {
            issues.append(.init("variations", "Je mindestens eine Variation 'einfacher' und 'schwerer'"))
        }
        var formTags = 0
        for t in ex.tags {
            guard let tag = vocabulary.tag(t) else {
                issues.append(.init("tags", "Unbekannter Tag '\(t)'"))
                continue
            }
            if tag.category == "form" { formTags += 1 }
        }
        if formTags == 0 {
            issues.append(.init("tags", "Mindestens ein Tag der Kategorie 'Form' (Rondo, Spielform, isoliert, …)"))
        }
        if Set(ex.tags).count != ex.tags.count {
            issues.append(.init("tags", "Doppelte Tags"))
        }
        if let anim = ex.animation {
            issues.append(contentsOf: validate(animation: anim))
        }
        return issues
    }

    public func validate(animation anim: ExerciseAnimation) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let tokenKinds: Set<String> = ["player", "neutral", "cone", "minigoal", "goal", "pole", "hurdle"]
        let staticKinds: Set<String> = ["zone", "line", "text"]

        if anim.version != 1 { issues.append(.init("animation.version", "Version muss 1 sein")) }
        if anim.pitch.widthM <= 0 || anim.pitch.lengthM <= 0 {
            issues.append(.init("animation.pitch", "Pitch-Maße müssen größer als 0 sein"))
        }
        let ids = anim.tokens.map(\.id)
        let known = Set(ids)
        if known.count != ids.count { issues.append(.init("animation.tokens", "Doppelte Token-IDs")) }
        for t in anim.tokens {
            if !tokenKinds.contains(t.kind) { issues.append(.init("animation.tokens", "Unbekannte Token-Art '\(t.kind)' bei '\(t.id)'")) }
            if t.kind == "player", !(t.team == "own" || t.team == "opp") {
                issues.append(.init("animation.tokens", "Spieler-Token '\(t.id)' braucht team own/opp"))
            }
        }
        for s in anim.staticElements where !staticKinds.contains(s.kind) {
            issues.append(.init("animation.static", "Unbekanntes statisches Element '\(s.kind)'"))
        }
        if anim.keyframes.count < 2 { issues.append(.init("animation.keyframes", "Mindestens zwei Keyframes")) }
        var lastT = -Double.infinity
        for (n, f) in anim.keyframes.enumerated() {
            if f.t <= lastT { issues.append(.init("animation.keyframes", "Keyframe \(n): t muss aufsteigend sein")) }
            lastT = f.t
            for (tid, pos) in f.positions {
                if !known.contains(tid) { issues.append(.init("animation.keyframes", "Keyframe \(n): unbekanntes Token '\(tid)'")) }
                if pos.count != 2 { issues.append(.init("animation.keyframes", "Keyframe \(n): Position von '\(tid)' muss [x, y] sein")) }
            }
            if let holder = f.ball?.holder, !known.contains(holder) {
                issues.append(.init("animation.keyframes", "Keyframe \(n): ball.holder '\(holder)' unbekannt"))
            }
            if f.ball?.holder == nil && f.ball?.atM == nil {
                issues.append(.init("animation.keyframes", "Keyframe \(n): ball.holder oder ball.at_m fehlt"))
            }
            if let pass = f.transition?.pass, pass.count != 2 || !pass.allSatisfy({ known.contains($0) }) {
                issues.append(.init("animation.keyframes", "Keyframe \(n): transition.pass muss [von, zu] mit bekannten IDs sein"))
            }
        }
        if let first = anim.keyframes.first {
            let missing = known.subtracting(first.positions.keys)
            if !missing.isEmpty {
                issues.append(.init("animation.keyframes", "Keyframe 0 muss alle Tokens positionieren, fehlt: \(missing.sorted().joined(separator: ", "))"))
            }
        }
        return issues
    }
}
