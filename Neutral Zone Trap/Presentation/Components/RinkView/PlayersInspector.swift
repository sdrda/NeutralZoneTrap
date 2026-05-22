//
//  PlayersInspector.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

struct PlayersInspector: View {
    @Environment(AppModeState.self) private var modeStore
    @Environment(Statistics.self) private var statistics
    @Environment(GroupSelection.self) private var groupSelection
    @Environment(RinkOverlayState.self) private var overlay
    @Environment(\.recorder) private var recorder
    @Query(sort: \PlayerGroup.name) private var groups: [PlayerGroup]
    @Query(sort: \Sensor.hardwareId) private var sensors: [Sensor]

    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                // MARK: - Aktivní skupiny

                if !activeGroupModels.isEmpty {
                    sectionHeader("Active Groups")

                    ForEach(activeGroupModels, id: \.id) { group in
                        GroupCard(
                            group: group,
                            canShowOverlay: modeStore.mode == .playback,
                            onShowHeatmap: { showHeatmap(for: group) }
                        )
                    }
                }

                // MARK: - Aktivní hráči

                sectionHeader("Active Players (\(statistics.activeIDs.count))")

                ForEach(statistics.activeIDs.sorted(), id: \.self) { playerID in
                    PlayerCard(
                        playerID: playerID,
                        sensor: sensor(for: playerID),
                        speed: statistics.speeds[playerID] ?? 0,
                        distance: statistics.totalDistances[playerID] ?? 0,
                        badgeColor: badgeColor(forSensor: playerID),
                        canShowOverlay: modeStore.mode == .playback || modeStore.mode == .recording,
                        onShowHeatmap: { showHeatmap(forSensor: playerID) },
                        onShowMovement: { showMovement(forSensor: playerID) }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Odvozená data

    private var activeGroupModels: [PlayerGroup] {
        groups.filter { groupSelection.isActive($0) }
    }

    private func sensor(for playerID: SensorHardwareID) -> Sensor? {
        sensors.first { $0.hardwareID == playerID }
    }

    // Barva podle skupiny nebo cerna
    private func badgeColor(forSensor playerID: SensorHardwareID) -> Color {
        guard let player = sensor(for: playerID)?.player else { return .black }
        let activeGroup = activeGroupModels.first { group in
            (group.players ?? []).contains { $0.id == player.id }
        }
        if let hex = activeGroup?.colorHex {
            return Color(hex: hex)
        }
        return .black
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    // MARK: - Analytické intenty

    // Nastavujeme overlay, kterej si odchyti vizualizacni vrstva
    
    private func showHeatmap(forSensor sensorID: SensorHardwareID) {
        guard let recorder else { return }
        Task {
            let snapshot = await recorder.snapshot()
            overlay.setHeatmap(points: snapshot.points(forSensor: sensorID))
        }
    }

    private func showMovement(forSensor sensorID: SensorHardwareID) {
        guard let recorder else { return }
        Task {
            let snapshot = await recorder.snapshot()
            overlay.setMovement(points: snapshot.points(forSensor: sensorID))
        }
    }

    private func showHeatmap(for group: PlayerGroup) {
        guard let recorder else { return }
        let sensorIDs = (group.players ?? []).flatMap { player in
            (player.sensors ?? []).map(\.hardwareID)
        }
        Task {
            let snapshot = await recorder.snapshot()
            overlay.setHeatmap(points: snapshot.points(forSensors: sensorIDs))
        }
    }
}

// MARK: - Karta hráče

// Slo by extrahovat do vlastniho souboru, ale nechavame zde
private struct PlayerCard: View {
    let playerID: SensorHardwareID
    let sensor: Sensor?
    let speed: Double
    let distance: Double
    let badgeColor: Color
    let canShowOverlay: Bool
    let onShowHeatmap: () -> Void
    let onShowMovement: () -> Void

    // Computed property
    private var label: String {
        sensor?.player.map { String($0.jerseyNumber) } ?? "–"
    }

    private var name: String {
        sensor?.player?.name ?? "Player"
    }

    // Pokud mame nulovou vzdalenost (zive, nahravani), neukazujeme
    private var showsDistance: Bool {
        distance > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Badge s cislem dresu
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(badgeColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)

                    Text("Sensor \(Int(playerID.rawValue))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f m/s", speed))
                        .font(.subheadline.bold())
                        .monospacedDigit()

                    if showsDistance {
                        Text(String(format: "%.0f m", distance))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onShowHeatmap) {
                    Label("Heatmap", systemImage: "map.fill")
                }

                Button(action: onShowMovement) {
                    Label("Movement", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
            }
            .disabled(!canShowOverlay)
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let speedText = String(format: "%.1f", speed)

        guard showsDistance else {
            return String(
                localized: "\(name), jersey \(label), speed \(speedText) meters per second"
            )
        }

        return String(
            localized: "\(name), jersey \(label), speed \(speedText) meters per second, distance \(String(format: "%.0f", distance)) meters"
        )
    }
}

// MARK: - Karta skupiny

private struct GroupCard: View {
    let group: PlayerGroup
    let canShowOverlay: Bool
    let onShowHeatmap: () -> Void

    private var groupColor: Color {
        if let hex = group.colorHex {
            return Color(hex: hex)
        }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Barevný badge
                Image(systemName: "person.3.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(groupColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)

                    let count = group.players?.count ?? 0
                    Text("\(count) players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button(action: onShowHeatmap) {
                Label("Group Heatmap", systemImage: "map.fill")
            }
            .tint(groupColor)
            .disabled(!canShowOverlay)
            .accessibilityHint(Text("Generates a heatmap for the whole group"))
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Group \(group.name), \(group.players?.count ?? 0) players"))
    }
}
