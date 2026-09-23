import Foundation

/// Übersetzt zwischen dem, was der Beobachter auf dem Platz sieht, und den normalisierten Zonen
/// aus eigener Angriffsperspektive. Das Spielfeld wird im Querformat gezeichnet.
public struct PitchGeometry: Hashable, Sendable {
    /// Greifen wir in dieser Periode nach rechts (aus Sicht des Beobachters) an?
    public var attackingRight: Bool
    /// Beobachter sitzt auf der gegenüberliegenden Seitenlinie.
    public var observerFlipped: Bool

    public init(attackDirectionFirstHalf: AttackDirection, period: Int, observerFlipped: Bool) {
        let firstHalfRight = attackDirectionFirstHalf == .rechts
        // Seitenwechsel in jeder geraden Periode (2. Halbzeit, 2. Verlängerung).
        self.attackingRight = period % 2 == 1 ? firstHalfRight : !firstHalfRight
        self.observerFlipped = observerFlipped
    }

    public init(attackingRight: Bool, observerFlipped: Bool = false) {
        self.attackingRight = attackingRight
        self.observerFlipped = observerFlipped
    }

    /// Zone für eine Bildschirmzelle: `column` 0 = links, `row` 0 = oben.
    public func zone(column: Int, row: Int) -> Zone {
        let rows: [ZoneRow] = [.eigenesDrittel, .mittelfeld, .angriffsdrittel]
        let lanes: [ZoneLane] = [.links, .zentrum, .rechts]
        let c = max(0, min(2, column))
        let r = max(0, min(2, row))
        let zoneRow = attackingRight ? rows[c] : rows[2 - c]
        // Bei Angriff nach rechts liegt unsere linke Seite oben (auf der fernen Seite des Beobachters).
        var laneIndex = attackingRight ? r : 2 - r
        if observerFlipped { laneIndex = 2 - laneIndex }
        return Zone(row: zoneRow, lane: lanes[laneIndex])
    }

    /// Bildschirmzelle für eine Zone (Umkehrung von `zone(column:row:)`).
    public func cell(for zone: Zone) -> (column: Int, row: Int) {
        let rows: [ZoneRow] = [.eigenesDrittel, .mittelfeld, .angriffsdrittel]
        let lanes: [ZoneLane] = [.links, .zentrum, .rechts]
        let ri = rows.firstIndex(of: zone.row) ?? 1
        let li = lanes.firstIndex(of: zone.lane) ?? 1
        let column = attackingRight ? ri : 2 - ri
        var r = attackingRight ? li : 2 - li
        if observerFlipped { r = 2 - r }
        return (column, r)
    }

    /// Normalisierte Position aus eigener Angriffsperspektive: x 0 = eigenes Tor, 1 = gegnerisches Tor;
    /// y 0 = links, 1 = rechts. Eingabe: relative Bildschirmkoordinaten 0..1 (x nach rechts, y nach unten).
    public func normalized(screenX: Double, screenY: Double) -> (x: Double, y: Double) {
        let x = attackingRight ? screenX : 1 - screenX
        var y = attackingRight ? screenY : 1 - screenY
        if observerFlipped { y = 1 - y }
        return (min(1, max(0, x)), min(1, max(0, y)))
    }

    public var ownGoalOnLeft: Bool { attackingRight }
}
