//
//  AddGroupForm.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

struct AddGroupForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorRouter.self) private var errorRouter
    @Query(sort: \Player.name) private var allPlayers: [Player]

    var group: PlayerGroup?

    @State private var name: String = ""
    @State private var selectedColor: Color = .orange
    @State private var selectedPlayerIDs: Set<PersistentIdentifier> = []

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Group name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Color.groupPalette, id: \.self) { color in
                            colorOption(color)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Players") {
                    if allPlayers.isEmpty {
                        Text("Add players first")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allPlayers) { player in
                            playerRow(player)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    Text(group == nil ? "New Group" : "Edit Group")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            if let group {
                name = group.name
                selectedPlayerIDs = Set((group.players ?? []).map(\.persistentModelID))
                if let hex = group.colorHex {
                    selectedColor = Color(hex: hex)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func colorOption(_ color: Color) -> some View {
        let isSelected = selectedColor == color
        Button {
            selectedColor = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
                // Stroke pro grayscale
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.primary : Color.secondary.opacity(0.4),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.paletteName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func playerRow(_ player: Player) -> some View {
        let isSelected = selectedPlayerIDs.contains(player.persistentModelID)
        Button {
            togglePlayer(player)
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name.isEmpty ? "No name" : player.name)
                        .font(.body)
                    Text("#\(player.jerseyNumber) · Sensors: \((player.sensors ?? []).map { String($0.hardwareId) }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Akce

    private func togglePlayer(_ player: Player) {
        let id = player.persistentModelID
        if selectedPlayerIDs.contains(id) {
            selectedPlayerIDs.remove(id)
        } else {
            selectedPlayerIDs.insert(id)
        }
    }

    private func save() {
        let hex = selectedColor.toHexString()
        let selected = allPlayers.filter { selectedPlayerIDs.contains($0.persistentModelID) }

        if let group {
            group.name = name
            group.colorHex = hex
            group.players = selected
        } else {
            let newGroup = PlayerGroup(name: name, colorHex: hex)
            newGroup.players = selected
            modelContext.insert(newGroup)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorRouter.report(RepositoryError.saveFailed(underlying: error))
        }
    }
}

#Preview {
    AddGroupForm()
        .modelContainer(for: [Player.self, PlayerGroup.self, Sensor.self], inMemory: true)
        .environment(ErrorRouter())
        .tint(.orange)
}
