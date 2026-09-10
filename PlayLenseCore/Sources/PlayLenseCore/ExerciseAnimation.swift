import Foundation

/// 2D-Animation von oben, Keyframe-basiert. Format siehe docs/05-animationsformat.md.
public struct ExerciseAnimation: Codable, Hashable, Sendable {
    public var version: Int
    public var pitch: Pitch
    public var tokens: [Token]
    public var staticElements: [StaticElement]
    public var keyframes: [Keyframe]
    public var loop: Bool

    private enum CodingKeys: String, CodingKey {
        case version, pitch, tokens, keyframes, loop
        case staticElements = "static"
    }

    public init(version: Int = 1, pitch: Pitch, tokens: [Token], staticElements: [StaticElement] = [],
                keyframes: [Keyframe], loop: Bool = true) {
        self.version = version
        self.pitch = pitch
        self.tokens = tokens
        self.staticElements = staticElements
        self.keyframes = keyframes
        self.loop = loop
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        pitch = try c.decode(Pitch.self, forKey: .pitch)
        tokens = try c.decodeIfPresent([Token].self, forKey: .tokens) ?? []
        staticElements = try c.decodeIfPresent([StaticElement].self, forKey: .staticElements) ?? []
        keyframes = try c.decodeIfPresent([Keyframe].self, forKey: .keyframes) ?? []
        loop = try c.decodeIfPresent(Bool.self, forKey: .loop) ?? true
    }

    public struct Pitch: Codable, Hashable, Sendable {
        public var widthM: Double
        public var lengthM: Double
        public var markings: String?
        public var orientation: String?

        public init(widthM: Double, lengthM: Double, markings: String? = "none", orientation: String? = nil) {
            self.widthM = widthM
            self.lengthM = lengthM
            self.markings = markings
            self.orientation = orientation
        }
    }

    public struct Token: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var kind: String
        public var team: String?
        public var label: String?
        public var color: String?
        public var rotationDeg: Double?

        public init(id: String, kind: String, team: String? = nil, label: String? = nil,
                    color: String? = nil, rotationDeg: Double? = nil) {
            self.id = id
            self.kind = kind
            self.team = team
            self.label = label
            self.color = color
            self.rotationDeg = rotationDeg
        }
    }

    public struct StaticElement: Codable, Hashable, Sendable {
        public var kind: String
        public var rectM: [Double]?
        public var fromM: [Double]?
        public var toM: [Double]?
        public var atM: [Double]?
        public var text: String?
        public var color: String?
        public var opacity: Double?
        public var style: String?
    }

    public struct Keyframe: Codable, Hashable, Sendable {
        public var t: Double
        public var positions: [String: [Double]]
        public var ball: Ball?
        public var transition: Transition?

        private enum CodingKeys: String, CodingKey { case t, positions, ball, transition }

        public init(t: Double, positions: [String: [Double]], ball: Ball? = nil, transition: Transition? = nil) {
            self.t = t
            self.positions = positions
            self.ball = ball
            self.transition = transition
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            t = try c.decode(Double.self, forKey: .t)
            positions = try c.decodeIfPresent([String: [Double]].self, forKey: .positions) ?? [:]
            ball = try c.decodeIfPresent(Ball.self, forKey: .ball)
            transition = try c.decodeIfPresent(Transition.self, forKey: .transition)
        }
    }

    public struct Ball: Codable, Hashable, Sendable {
        public var holder: String?
        public var atM: [Double]?

        public init(holder: String? = nil, atM: [Double]? = nil) {
            self.holder = holder
            self.atM = atM
        }
    }

    public struct Transition: Codable, Hashable, Sendable {
        public var pass: [String]?
        public var dribble: String?
        public var runs: [[String]]?

        public init(pass: [String]? = nil, dribble: String? = nil, runs: [[String]]? = nil) {
            self.pass = pass
            self.dribble = dribble
            self.runs = runs
        }
    }

    public var duration: Double { keyframes.last?.t ?? 0 }

    /// Position eines Tokens zum Zeitpunkt `time`, linear interpoliert. Tokens ohne Angabe in einem
    /// Keyframe behalten ihre letzte Position.
    public func position(of tokenID: String, at time: Double) -> (x: Double, y: Double)? {
        var last: (t: Double, p: [Double])? = nil
        for frame in keyframes {
            let p = frame.positions[tokenID] ?? last?.p
            guard let pos = p, pos.count == 2 else { continue }
            if frame.t >= time {
                guard let prev = last else { return (pos[0], pos[1]) }
                let span = frame.t - prev.t
                let f = span > 0 ? (time - prev.t) / span : 1
                let eased = f * f * (3 - 2 * f) // Ease-in/out
                return (prev.p[0] + (pos[0] - prev.p[0]) * eased, prev.p[1] + (pos[1] - prev.p[1]) * eased)
            }
            last = (frame.t, pos)
        }
        if let l = last { return (l.p[0], l.p[1]) }
        return nil
    }
}
