//
//  EnvironmentValues.swift
//  Neutral Zone Trap
//

import SwiftUI

// Vytvoreni enviroment objektu
extension EnvironmentValues {
    @Entry var sensorPositionStore: (any PositionStoreReading)? = nil
    @Entry var recorder: (any RecordingControl & SessionSnapshotting)? = nil
    @Entry var benchmarkLogger: BenchmarkLogger? = nil

    // Jediny dlouhozijici UDP receiver. Vznika na urovni WindowGroup a putuje
    // sem, takze ho RinkView dostane pri init streamProcessoru, aniz by ho
    // pri kazdem znovuotevreni okna vyrabel znovu.
    @Entry var receiver: (any PacketReceiver)? = nil
}
