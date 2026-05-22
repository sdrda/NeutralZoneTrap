//
//  Session.swift
//  Neutral Zone Trap
//

import Foundation

/// Jedna nahraná relace měření — souhrn pohybových stop všech senzorů.
nonisolated struct Session: Sendable {

    /// Pohybové stopy seskupené po jednom senzoru; nejvýše jedna stopa na senzor.
    private(set) var sensorTracks: [SensorTrack] = []
    
    /// Pomocné mapování
    private var trackIndicesBySensorID: [SensorHardwareID: Int] = [:]

    /// Vytvoří session z předaných stop a sestaví vyhledávací index podle identifikátoru senzoru.
    /// - Parameter sensorTracks: Výchozí stopy (např. z naimportovaného souboru); při duplicitě senzoru se ponechá první výskyt.
    init(sensorTracks: [SensorTrack] = []) {
        self.sensorTracks = sensorTracks
        for (index, track) in sensorTracks.enumerated() {
            if trackIndicesBySensorID[track.sensorHardwareID] == nil {
                trackIndicesBySensorID[track.sensorHardwareID] = index
            }
        }
    }

    /// Zařadí pozici do stopy odpovídajícího senzoru, případně pro nový senzor stopu založí.
    /// - Parameter position: Příchozí pozice; její `id` určuje cílovou stopu.
    mutating func addPosition(_ position: SensorPosition) {
        if let index = trackIndicesBySensorID[position.id] {
            sensorTracks[index].addPosition(position)
        } else {
            var newTrack = SensorTrack(sensorHardwareID: position.id)
            newTrack.addPosition(position)
            trackIndicesBySensorID[position.id] = sensorTracks.count
            sensorTracks.append(newTrack)
        }
    }

    /// Resetuje session na prázdnou (např. když uživatel zahodí nahrávku).
    mutating func clear() {
        sensorTracks.removeAll()
        trackIndicesBySensorID.removeAll()
    }

    /// Časová značka nejstarší pozice napříč všemi stopami, nebo `nil` pro prázdnou session.
    /// - Complexity: O(n) přes počet stop.
    var firstTimestamp: Date? {
        sensorTracks.compactMap { $0.positions.first?.timestamp }.min()
    }

    /// Časová značka nejnovější pozice napříč všemi stopami, nebo `nil` pro prázdnou session.
    /// - Complexity: O(n) přes počet stop.
    var lastTimestamp: Date? {
        sensorTracks.compactMap { $0.positions.last?.timestamp }.max()
    }

    /// Časový rozsah od první po poslední pozici, nebo `nil`, chybí-li některý z krajů.
    var timeRange: ClosedRange<Date>? {
        guard let first = firstTimestamp, let last = lastTimestamp else { return nil }
        return first...last
    }

    /// Vrátí pozice ze všech stop sloučené do jediné posloupnosti seřazené vzestupně podle času.
    /// - Returns: Společnou časovou osu všech senzorů pro přehrávání.
    /// - Complexity: O(n log n) přes celkový počet pozic.
    func buildTimeline() -> [SensorPosition] {
        sensorTracks
            .flatMap(\.positions)
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Vrátí poslední známou pozici každého senzoru k danému okamžiku včetně.
    /// - Parameter time: Okamžik, ke kterému se stav senzorů zjišťuje.
    /// - Returns: Slovník naposledy známé pozice na senzor; senzory bez pozice do `time` se vynechají.
    func snapshot(at time: Date) -> [SensorHardwareID: SensorPosition] {
        var result: [SensorHardwareID: SensorPosition] = [:]
        result.reserveCapacity(sensorTracks.count)
        for track in sensorTracks {
            if let last = track.lastPosition(atOrBefore: time) {
                result[last.id] = last
            }
        }
        return result
    }
}

extension SensorTrack {
    /// Vrátí poslední pozici s časovou značkou menší nebo rovnou danému okamžiku.
    ///
    /// Využívá binární vyhledávání nad chronologicky seřazenými pozicemi.
    /// - Parameter time: Horní mez (včetně) pro hledanou časovou značku.
    /// - Returns: Nalezenou pozici, nebo `nil`, pokud žádná pozice není do `time`.
    /// - Complexity: O(log n) přes počet pozic.
    nonisolated func lastPosition(atOrBefore time: Date) -> SensorPosition? {
        var lowerBound = positions.startIndex
        var upperBound = positions.endIndex

        while lowerBound < upperBound {
            let distance = positions.distance(from: lowerBound, to: upperBound)
            let middle = positions.index(lowerBound, offsetBy: distance / 2)
            if positions[middle].timestamp <= time {
                lowerBound = positions.index(after: middle)
            } else {
                upperBound = middle
            }
        }

        guard lowerBound > positions.startIndex else { return nil }
        return positions[positions.index(before: lowerBound)]
    }
}
