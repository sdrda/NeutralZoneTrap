//
//  BenchmarkLogger.swift
//  Neutral Zone Trap
//

import Foundation
import os

private nonisolated let log = Logger.app(category: "BenchmarkLogger")

/// Actor pro měření latence od odeslání paketu senzorem přes přijetí na zařízení až po vykreslení v UI;
/// výsledky zapisuje do CSV souboru v Documents adresáři.
/// - Note: Logger se aktivuje pouze při přítomnosti argumentu `--benchmark` v příkazové řádce procesu.
actor BenchmarkLogger {
    /// Argument příkazové řádky, jehož přítomností se benchmark logger zapíná.
    static let launchFlag = "--benchmark"

    /// Vytvoří instanci loggeru, pokud je v argumentech procesu přítomen `launchFlag`; jinak vrátí `nil`.
    /// Při selhání inicializace (např. nelze otevřít soubor) zapíše chybu do systémového logu a vrátí `nil`.
    /// - Returns: Nová instance `BenchmarkLogger`, nebo `nil` když není aktivní.
    static func makeIfEnabled() -> BenchmarkLogger? {
        guard ProcessInfo.processInfo.arguments.contains(launchFlag) else { return nil }
        do {
            return try BenchmarkLogger()
        } catch {
            log.error("Failed to initialise: \(error.localizedDescription)")
            return nil
        }
    }

    private struct Pending {
        let sentAt: Date
        let receivedAt: Date
    }

    private var pending: [SensorHardwareID: Pending] = [:]
    private let url: URL
    private let handle: FileHandle

    private static let header = "sent_at_ms,received_at_ms,rendered_at_ms,latency_ms,sent_to_render_ms,sensor_id,active_count_at_render\n"

    /// Vytvoří nový benchmark logger a otevře CSV soubor v Documents adresáři se záhlavím sloupců.
    /// Název souboru obsahuje časové razítko spuštění ve formátu `nzt-benchmark-YYYYMMDD-HHmmss.csv`.
    /// - Throws: Chyba `FileHandle` pokud nelze soubor otevřít pro zápis.
    init() throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = .current
        let stamp = formatter.string(from: .now)
        let url = docs.appendingPathComponent("nzt-benchmark-\(stamp).csv")
        FileManager.default.createFile(atPath: url.path, contents: Self.header.data(using: .utf8))
        self.url = url
        self.handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        log.info("Writing benchmark CSV to \(url.path)")
    }

    /// Zaznamená přijetí paketu pro daný senzor; data čekají na spárování s událostí vykreslení.
    /// - Parameters:
    ///   - id: Identifikátor senzoru, jehož paket byl přijat.
    ///   - sentAt: Čas odeslání paketu ze senzoru (z časového razítka v datagramu).
    ///   - receivedAt: Čas přijetí datagramu aplikací.
    func recordReceived(id: SensorHardwareID, sentAt: Date, receivedAt: Date) {
        pending[id] = Pending(sentAt: sentAt, receivedAt: receivedAt)
    }

    /// Spáruje čekající záznamy přijetí se zadaným časem vykreslení a zapíše řádky do CSV.
    /// Sloupce: `sent_at_ms`, `received_at_ms`, `rendered_at_ms`, `latency_ms` (render − receive),
    /// `sent_to_render_ms` (render − sent), `sensor_id`, `active_count_at_render`.
    /// Senzory bez čekajícího záznamu přijetí jsou přeskočeny.
    /// - Parameters:
    ///   - ids: Seznam senzorů vykreslených v daném snímku.
    ///   - renderedAt: Čas, kdy byl snímek vykreslen.
    func recordRendered(ids: [SensorHardwareID], at renderedAt: Date) {
        let count = ids.count
        var buf = ""
        for id in ids {
            guard let p = pending.removeValue(forKey: id) else { continue }
            let sentMs = p.sentAt.timeIntervalSince1970 * 1000
            let recvMs = p.receivedAt.timeIntervalSince1970 * 1000
            let rendMs = renderedAt.timeIntervalSince1970 * 1000
            let latency = rendMs - recvMs
            let sentToRender = rendMs - sentMs
            buf += "\(sentMs),\(recvMs),\(rendMs),\(latency),\(sentToRender),\(id),\(count)\n"
        }
        guard !buf.isEmpty, let data = buf.data(using: .utf8) else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            log.error("Write failed: \(error.localizedDescription)")
        }
    }
}
