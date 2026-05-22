//
//  ContentView.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.receiver) private var receiver
    @State private var selectedTab: AppTab = .rink
    @State private var errorRouter = ErrorRouter()

    var body: some View {
        @Bindable var errorRouter = errorRouter

        TabView(selection: $selectedTab) {
            Tab("Rink", systemImage: "sportscourt", value: .rink) {
                // Inicializace RinkView s receiverem, aby byl dostupnej uz v initu
                RinkView(receiver: receiver)
            }
            .accessibilityIdentifier("tab.rink")

            Tab("Players", systemImage: "person", value: .players) {
                PlayerListView()
            }
            .accessibilityIdentifier("tab.players")

            Tab("Groups", systemImage: "person.3", value: .groups) {
                GroupListView()
            }
            .accessibilityIdentifier("tab.groups")

            Tab("Sensors", systemImage: "sensor.fill", value: .sensors) {
                SensorListView()
            }
            .accessibilityIdentifier("tab.sensors")
        }
        
        // Klicove nastaveni tabview
        .tabViewStyle(.sidebarAdaptable)
        
        // Focused pro prepinani
        .focusedSceneValue(\.selectedTab, $selectedTab)
        
        // Error router
        .environment(errorRouter)
        
        // Alert overlay pro vsechny obrazovky
        .alert(
            "Error",
            isPresented: .presence(of: $errorRouter.error),
            presenting: errorRouter.error
        ) { _ in
            Button("OK") { errorRouter.dismiss() }
        } message: { error in
            Text(error.localizedDescription)
        }
        .tint(.indigo)
    }
}
