//
//  PositionParser.swift
//  Neutral Zone Trap
//

import Foundation

/// Bezstavový parser binárních datagramů ze senzorů na hodnoty `SensorPosition`.
/// Typ je `nonisolated` a `Sendable`, takže jej lze volat z libovolného vlákna bez overhead přepnutí actoru.
enum PositionParser: Sendable {
    /// Naparsuje binární datagram na `SensorPosition`.
    ///
    /// Očekávané rozložení bajtů (little-endian IEEE 754 / little-endian UInt64, minimálně 32 B):
    /// ```
    /// Offset  Délka  Typ      Popis
    ///  0       8     Float64  Souřadnice X v metrech
    ///  8       8     Float64  Souřadnice Y v metrech
    /// 16       8     UInt64   Hardware ID senzoru (little-endian)
    /// 24       8     Float64  Časové razítko (Unix epoch, sekundy)
    /// ```
    /// - Parameter data: Surová data UDP datagramu.
    /// - Returns: Naparsovaná `SensorPosition`, nebo `nil` pokud je datagram kratší než 32 bajtů.
    nonisolated static func transformToPlayerPosition(from data: Data) -> SensorPosition? {
        guard data.count >= 32 else { return nil }

        return data.withUnsafeBytes { buffer in
            let x = buffer.loadUnaligned(fromByteOffset: 0, as: Double.self)
            let y = buffer.loadUnaligned(fromByteOffset: 8, as: Double.self)
            let id = UInt64(littleEndian: buffer.loadUnaligned(fromByteOffset: 16, as: UInt64.self))
            let timestamp = buffer.loadUnaligned(fromByteOffset: 24, as: Double.self)

            return SensorPosition(
                id: SensorHardwareID(id),
                x: CGFloat(x),
                y: CGFloat(y),
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
        }
    }
}

