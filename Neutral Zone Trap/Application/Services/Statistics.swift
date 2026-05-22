//
//  Statistics.swift
//  Neutral Zone Trap
//

import Foundation
import Observation

/// Observable aplikační služba udržující realtime rychlosti a kumulativní vzdálenosti senzorů; čtena view, proto je zápis izolovaný na `MainActor`.
@Observable
final class Statistics: StatisticsIngest {

    // MARK: - Real-time vrstva

    /// Hardwarová ID senzorů momentálně viditelných na hřišti.
    private(set) var activeIDs: Set<SensorHardwareID> = []

    /// Vyhlazená okamžitá rychlost v m/s pro každý senzor (klouzavý průměr).
    private(set) var speeds: [SensorHardwareID: Double] = [:]

    /// Poslední zpracovaná pozice každého senzoru, sloužící k výpočtu okamžité rychlosti.
    private var previousPositions: [SensorHardwareID: SensorPosition] = [:]
    /// Posuvné okno posledních okamžitých rychlostí na senzor pro vyhlazování.
    private var speedWindows: [SensorHardwareID: [Double]] = [:]
    /// Počet vzorků v posuvném okně klouzavého průměru rychlosti.
    private let windowSize: Int

    // MARK: - Aggregate vrstva

    /// Kumulativní ujetá vzdálenost senzoru v metrech.
    private(set) var totalDistances: [SensorHardwareID: Double] = [:]

    /// Vytvoří službu s danou velikostí vyhlazovacího okna.
    /// - Parameter windowSize: Počet vzorků klouzavého průměru rychlosti; musí být kladný (jinak `precondition` selže).
    init(windowSize: Int = 5) {
        // Pouziti precondition
        precondition(windowSize > 0, "windowSize must be positive")
        self.windowSize = windowSize
    }

    // MARK: - Real-time ingest

    /// Zpracuje pozici z živé cesty i přehrávání: dopočítá okamžitou rychlost vůči předchozí pozici, aktualizuje klouzavý průměr v okně a eviduje senzor jako aktivní.
    /// - Parameter position: Nově přijatá pozice senzoru.
    func insertPosition(_ position: SensorPosition) {
        if let previous = previousPositions[position.id],
           let instantaneous = SensorMetrics.speed(from: previous, to: position) {
            var window = speedWindows[position.id] ?? []
            window.append(instantaneous)
            if window.count > windowSize {
                window.removeFirst(window.count - windowSize)
            }
            speedWindows[position.id] = window
            speeds[position.id] = window.reduce(0, +) / Double(window.count)
        }
        previousPositions[position.id] = position

        if !activeIDs.contains(position.id) {
            activeIDs.insert(position.id)
        }
    }

    // MARK: - Aggregate refresh

    /// Přepočítá agregované statistiky z celé session; zatím naplní kumulativní vzdálenosti všech trajektorií. Lineární vůči počtu senzorových stop.
    /// - Parameter session: Session, ze které se agregáty počítají.
    func recomputeAggregates(from session: Session) {
        let tracks = session.sensorTracks
        
        // Temp pole
        var dist: [SensorHardwareID: Double] = [:]
        
        // Reserve kapacity
        dist.reserveCapacity(tracks.count)
        
        // Naplneni vzdalenost
        for track in tracks {
            dist[track.sensorHardwareID] = track.totalDistance
        }
        
        // Zapsani ujetych vzdalenosti
        totalDistances = dist
    }

    // MARK: - Reset

    /// Vymaže veškerý realtime i agregovaný stav (aktivní ID, rychlosti, okna i vzdálenosti).
    func reset() {
        activeIDs.removeAll()
        speeds.removeAll()
        previousPositions.removeAll()
        speedWindows.removeAll()
        totalDistances.removeAll()
    }
}
