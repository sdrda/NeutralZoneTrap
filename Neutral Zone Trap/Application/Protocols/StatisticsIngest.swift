//
//  StatisticsIngest.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce příjmu dat pro výpočet statistik — realtime ingest pozic i agregátní přepočet ze session.
///
/// Protokol je izolován na `@MainActor`, protože konformní typ (`Statistics`) je `@Observable`
/// třída a jeho vlastnosti sleduje SwiftUI. Volající z jiných kontextů (např. `SensorStreamProcessor`)
/// musí přecházet na `@MainActor` explicitně před voláním metod tohoto protokolu.
@MainActor
protocol StatisticsIngest: Sendable {
    /// Zpracuje jednu příchozí pozici senzoru a průběžně aktualizuje klouzavý průměr rychlosti.
    ///
    /// - Parameter position: Nová pozice senzoru s hardwarovým ID a wall-clock timestampem.
    func insertPosition(_ position: SensorPosition)
    /// Přepočítá agregátní statistiky (např. celkové vzdálenosti) ze záznamu celé session.
    ///
    /// - Parameter session: Session obsahující stopy senzorů, ze kterých se agregáty odvozují.
    /// - Note: Voláno při načtení session do `Playback`, aby byly statistiky k dispozici před spuštěním přehrávání.
    func recomputeAggregates(from session: Session)
    /// Vymaže veškerý realtime i agregátní stav statistik.
    func reset()
}
