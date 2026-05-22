//
//  Neutral_Zone_TrapApp.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

@main
struct Neutral_Zone_TrapApp: App {
    // Receiver zije s aplikaci, ne s oknem - pro moznost vice oken a treba sledovani z ruznych uhlu
    @State private var receiver = UDPReceiver(port: AppConfig.udpPort)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.receiver, receiver)
        }
        .modelContainer(for: [Player.self, PlayerGroup.self, Sensor.self])
        .commands {
            TabCommands()
            SessionCommands()
            InspectorCommands()
        }
    }
}
