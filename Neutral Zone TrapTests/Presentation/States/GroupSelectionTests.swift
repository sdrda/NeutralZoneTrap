//
//  GroupSelectionTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
import SwiftData
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.observation))
struct GroupSelectionTests {

    /// Sestaví čerstvý in-memory `ModelContext` s několika hráči a skupinami.
    /// Vrací context plus vytvořené hráče zaklíčované podle jména a skupiny
    /// zaklíčované podle jména.
    private func makeFixture() throws -> (
        context: ModelContext,
        players: [String: Player],
        groups: [String: PlayerGroup]
    ) {
        let schema = Schema([Player.self, PlayerGroup.self, Sensor.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let alice = Player(name: "Alice", jerseyNumber: 1)
        let bob = Player(name: "Bob", jerseyNumber: 2)
        let cara = Player(name: "Cara", jerseyNumber: 3)

        let line1 = PlayerGroup(name: "Line 1")
        line1.players = [alice, bob]
        let line2 = PlayerGroup(name: "Line 2")
        line2.players = [bob, cara]   // překrývá se s line1 přes Boba
        let line3 = PlayerGroup(name: "Line 3")
        line3.players = [cara]        // disjunktní s line1

        for entity in [alice, bob, cara] { context.insert(entity) }
        for group in [line1, line2, line3] { context.insert(group) }
        try context.save()

        return (
            context,
            ["Alice": alice, "Bob": bob, "Cara": cara],
            ["Line 1": line1, "Line 2": line2, "Line 3": line3]
        )
    }

    @Test("Initial state has no active groups")
    func initialState() {
        let store = GroupSelection()

        #expect(store.activeGroups.isEmpty)
    }

    @Test("toggle adds and removes group IDs symmetrically")
    func toggleSymmetry() throws {
        let fixture = try makeFixture()
        let store = GroupSelection()
        let line1 = try #require(fixture.groups["Line 1"])

        store.toggle(line1)
        #expect(store.isActive(line1))

        store.toggle(line1)
        #expect(store.isActive(line1) == false)
    }

    @Test("conflictingPlayerNames returns empty when no overlap exists")
    func noConflict() throws {
        let fixture = try makeFixture()
        let store = GroupSelection()
        let line1 = try #require(fixture.groups["Line 1"])
        let line3 = try #require(fixture.groups["Line 3"])
        let allGroups = Array(fixture.groups.values)

        store.toggle(line1)

        let conflicts = store.conflictingPlayerNames(activating: line3, in: allGroups)
        #expect(conflicts.isEmpty)
    }

    @Test("conflictingPlayerNames lists players shared with already-active groups")
    func detectsConflict() throws {
        let fixture = try makeFixture()
        let store = GroupSelection()
        let line1 = try #require(fixture.groups["Line 1"])
        let line2 = try #require(fixture.groups["Line 2"])
        let allGroups = Array(fixture.groups.values)

        store.toggle(line1)   // Alice + Bob jsou nyní aktivní

        let conflicts = store.conflictingPlayerNames(activating: line2, in: allGroups)
        #expect(conflicts == ["Bob"])
    }

    @Test("conflictingPlayerNames is empty when no group is active yet")
    func noConflictWithoutActiveGroups() throws {
        let fixture = try makeFixture()
        let store = GroupSelection()
        let line2 = try #require(fixture.groups["Line 2"])
        let allGroups = Array(fixture.groups.values)

        let conflicts = store.conflictingPlayerNames(activating: line2, in: allGroups)
        #expect(conflicts.isEmpty)
    }
}
