//
//  PlayersListView.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

/// View seznamu hráčů
struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorRouter.self) private var errorRouter
    @Query(sort: \Player.name) private var players: [Player]

    @State private var showAddSheet = false
    @State private var playerToEdit: Player? = nil
    
    @State private var searchText: String = ""
    
    var filteredPlayers: [Player] {
        if searchText.isEmpty {
            return players
        } else {
            return players.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if players.isEmpty {
                    ContentUnavailableView(
                        "No Players",
                        systemImage: "person.3.fill",
                        description: Text("Add the first player using the + button")
                    )
                } else {
                    List {
                        ForEach(filteredPlayers) { player in
                            Button {
                                playerToEdit = player
                            } label: {
                                PlayerRowView(player: player)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deletePlayers)
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle("Players")

            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Player", systemImage: "plus") {
                        showAddSheet = true
                    }
                    .labelStyle(.iconOnly)
                }
                
                #if os(iOS)
                if !players.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                #endif
            }
        }
        // Přidat nového hráče
        .sheet(isPresented: $showAddSheet) {
            AddPlayerForm()
        }
        // Upravit existujícího hráče
        .sheet(item: $playerToEdit) { player in
            AddPlayerForm(player: player)
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredPlayers[index])
            }
            do {
                try modelContext.save()
            } catch {
                errorRouter.report(RepositoryError.deleteFailed(underlying: error))
            }
        }
    }
}

// MARK: - Řádek hráče

private struct PlayerRowView: View {
    let player: Player

    var sensorLabel: String {
        let sensors = player.sensors ?? []
        if sensors.isEmpty {
            return "No sensor"
        }
        return "Sensors: " + sensors.map { String($0.hardwareId) }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name.isEmpty ? "No name" : player.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(sensorLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Číslo dresu
            Text("#\(player.jerseyNumber)")
                .font(.headline)
                .foregroundStyle(.orange)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlayerListView()
        .modelContainer(for: [Player.self, Sensor.self], inMemory: true)
        .environment(ErrorRouter())
        .tint(.orange)
}
