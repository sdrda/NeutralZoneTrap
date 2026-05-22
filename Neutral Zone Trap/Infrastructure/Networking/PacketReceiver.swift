//
//  PacketReceiver.swift
//  Neutral Zone Trap
//

import Foundation

/// Protokol pro actor přijímající binární datagramy a distribuující je jako asynchronní stream.
/// Konformující typy musí být actory, čímž je zajištěna bezpečnost přístupu k internímu stavu.
protocol PacketReceiver: Actor {
    /// Zaregistruje nového odběratele a vrátí stream příchozích paketů jako `Data`.
    /// Každé volání vrací nezávislý stream; při chybě transportní vrstvy stream skončí vyhozením chyby.
    /// - Returns: `AsyncThrowingStream<Data, Error>` doručující kopie každého přijatého paketu.
    func startReceiving() -> AsyncThrowingStream<Data, Error>

    /// Ukončí příjem paketů a dokončí všechny aktivní streamy.
    func stopReceiving()
}
