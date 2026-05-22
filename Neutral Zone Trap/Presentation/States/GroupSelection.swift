//
//  GroupSelection.swift
//  Neutral Zone Trap
//

import Foundation
import Observation

@Observable
final class GroupSelection {

    /// ID aktuálně aktivních (zvýrazněných) skupin.
    var activeGroups: Set<UUID> = []

    func isActive(_ group: PlayerGroup) -> Bool {
        activeGroups.contains(group.id)
    }

    func toggle(_ group: PlayerGroup) {
        if activeGroups.contains(group.id) {
            activeGroups.remove(group.id)
        } else {
            activeGroups.insert(group.id)
        }
    }

    // Jmena hracu, ktera uz patri do nejake skupiny
    func conflictingPlayerNames(activating group: PlayerGroup, in allGroups: [PlayerGroup]) -> [String] {
        // Vyfiltrovani pomoci funkcionalniho programovani
        let activePlayerIDs = allGroups
            .filter { activeGroups.contains($0.id) }
            .flatMap { $0.players ?? [] }
            .map(\.id)
        
        
        let activeIDSet = Set(activePlayerIDs)

        return (group.players ?? [])
            .filter { activeIDSet.contains($0.id) }
            .map(\.name)
    }
}
