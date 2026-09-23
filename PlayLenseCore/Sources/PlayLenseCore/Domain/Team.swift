import Foundation

public struct Team: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var shortName: String
    public var colorHex: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, shortName: String, colorHex: String = "#1E5AA8",
                isActive: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.colorHex = colorHex
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Season: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var teamId: UUID
    public var label: String
    public var startsOn: Date?
    public var endsOn: Date?
    public var isCurrent: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), teamId: UUID, label: String, startsOn: Date? = nil, endsOn: Date? = nil,
                isCurrent: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.teamId = teamId
        self.label = label
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.isCurrent = isCurrent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// "2026/27" für ein Datum im Jahr 2026 (Saisonstart im Sommer).
    public static func defaultLabel(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let start = month >= 7 ? year : year - 1
        return "\(start)/\(String(start + 1).suffix(2))"
    }
}
