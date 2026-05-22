//
//  TabCommands.swift
//  Neutral Zone Trap
//

import SwiftUI

#if !os(tvOS)
struct TabCommands: Commands {
    @FocusedBinding(\.selectedTab) var selectedTab: AppTab?
    
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Rink") {
                selectedTab = .rink
            }
            .keyboardShortcut("1", modifiers: .command)
            
            Button("Players") {
                selectedTab = .players
            }
            .keyboardShortcut("2", modifiers: .command)
            
            Button("Groups") {
                selectedTab = .groups
            }
            .keyboardShortcut("3", modifiers: .command)
            
            Button("Sensors") {
                selectedTab = .sensors
            }
            .keyboardShortcut("4", modifiers: .command)
        }
    }
}
#endif
