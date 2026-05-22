//
//  InspectorCommands.swift
//  Neutral Zone Trap
//

#if !os(tvOS)
import SwiftUI

struct InspectorCommands: Commands {
    @FocusedBinding(\.inspectorPresentedBinding) private var inspectorPresented: Bool?

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Show Player Inspector") {
                inspectorPresented?.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(inspectorPresented == nil)
        }
    }
}
#endif
