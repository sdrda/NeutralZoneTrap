//
//  SensorTrack.swift
//  Neutral Zone Trap
//

/// Pohybová stopa jednoho senzoru — chronologicky seřazené pozice a jejich průběžná souhrnná metrika.
nonisolated struct SensorTrack: Codable, Sendable {

    /// Všechny nahrané pozice senzoru udržované vzestupně podle `timestamp`.
    var positions: [SensorPosition] = [SensorPosition]()

    /// Identifikátor senzoru, z něhož stopa pochází.
    var sensorHardwareID: SensorHardwareID

    /// Celková ujetá vzdálenost senzoru v metrech, udržovaná inkrementálně při vkládání pozic.
    private(set) var totalDistance: Double = 0

    /// Vytvoří prázdnou stopu pro senzor s daným hardwarovým identifikátorem.
    init(sensorHardwareID: SensorHardwareID) {
        self.sensorHardwareID = sensorHardwareID
    }

    // Pridani pozice
    /// Vloží pozici do stopy na chronologicky správné místo a aktualizuje `totalDistance`.
    ///
    /// Pozice příchozí v pořadí se přidají v konstantním čase; pozice mimo pořadí
    /// vyžadují vyhledání správného místa vložení.
    /// - Parameter position: Pozice, která se má do stopy zařadit.
    /// - Complexity: O(1) pro pozice příchozí chronologicky, jinak O(n).
    mutating func addPosition(_ position: SensorPosition) {
        
        // Fast path: pozice je chronologicky za posledni (nebo je pole empty)
        if let last = positions.last, position.timestamp >= last.timestamp {
            totalDistance += SensorMetrics.distance(from: last, to: position)
            positions.append(position)
        } else if positions.isEmpty {
            positions.append(position)
        } else {
            // Out-of-order: vlozi na spravnou pozici
            let insertionIndex = positions.firstIndex { $0.timestamp > position.timestamp } ?? positions.endIndex
            updateDistanceForInsertion(of: position, at: insertionIndex)
            positions.insert(position, at: insertionIndex)
        }
    }

    private mutating func updateDistanceForInsertion(of position: SensorPosition, at insertionIndex: Int) {
        let previous = insertionIndex > 0 ? positions[insertionIndex - 1] : nil
        let next = insertionIndex < positions.count ? positions[insertionIndex] : nil

        if let previous, let next {
            totalDistance -= SensorMetrics.distance(from: previous, to: next)
        }
        if let previous {
            totalDistance += SensorMetrics.distance(from: previous, to: position)
        }
        if let next {
            totalDistance += SensorMetrics.distance(from: position, to: next)
        }
    }
}
