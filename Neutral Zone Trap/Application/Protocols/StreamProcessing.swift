//
//  StreamProcessing.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce spuštění a zastavení zpracování příchozího UDP streamu senzorových dat.
///
/// Konformní typ (`SensorStreamProcessor`) je actor. Protokol je deklarován `nonisolated`,
/// aby ho bylo možné volat bez nutnosti znát konkrétní actor-izolaci konformního typu.
/// Každé volání `start()` zahájí interní consumer task; `stop()` ho bezpečně zruší
/// bez zastavení sdíleného `PacketReceiver`.
nonisolated protocol StreamProcessing: Sendable {
    /// Zahájí příjem a zpracování UDP paketů; no-op pokud consumer task již běží.
    func start() async
    /// Zruší consumer task a odhlásí odběr ze sdíleného receiveru; sdílený receiver zůstává aktivní.
    func stop() async
}
