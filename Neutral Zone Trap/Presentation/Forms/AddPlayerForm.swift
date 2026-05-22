//
//  AddPlayerForm.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

struct AddPlayerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorRouter.self) private var errorRouter
    @Query(sort: \Sensor.hardwareId) private var allSensors: [Sensor]

    var player: Player?

    @State private var name: String = ""
    @State private var selectedNumber: Int = 1
    @State private var selectedSensorIDs: Set<PersistentIdentifier> = []

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Computed dostupnych senzoru
    var availableSensors: [Sensor] {
        allSensors.filter { sensor in
            sensor.player == nil
            || sensor.player == player
            || selectedSensorIDs.contains(sensor.persistentModelID)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Name", text: $name)
                    if !name.isEmpty, name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Name must not be empty")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker("Number", selection: $selectedNumber) {
                        ForEach(1...99, id: \.self) { number in
                            Text("\(number)").tag(number)
                        }
                    }
                }

                Section("Sensors") {
                    if allSensors.isEmpty {
                        Text("Add sensors first")
                            .foregroundStyle(.secondary)
                    } else if availableSensors.isEmpty {
                        Text("All sensors are assigned")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableSensors) { sensor in
                            sensorRow(sensor)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismissForm)
                }
                ToolbarItem(placement: .principal) {
                    Text(player == nil ? "Add Player" : "Edit Player")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            if let player {
                name = player.name
                selectedNumber = player.jerseyNumber
                selectedSensorIDs = Set((player.sensors ?? []).map(\.persistentModelID))
            }
        }
    }

    @ViewBuilder
    private func sensorRow(_ sensor: Sensor) -> some View {
        let isSelected = selectedSensorIDs.contains(sensor.persistentModelID)
        Button {
            toggleSensor(sensor)
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ID: \(sensor.hardwareId)")
                        .font(.body)
                        .monospacedDigit()
                    if let owner = sensor.player {
                        Text("Current: \(owner.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func toggleSensor(_ sensor: Sensor) {
        let id = sensor.persistentModelID
        if selectedSensorIDs.contains(id) {
            selectedSensorIDs.remove(id)
        } else {
            selectedSensorIDs.insert(id)
        }
    }

    private func dismissForm() {
        dismiss()
    }

    private func save() {
        let selectedSensors = allSensors.filter { selectedSensorIDs.contains($0.persistentModelID) }

        if let player {
            player.name = name
            player.jerseyNumber = selectedNumber

            for sensor in (player.sensors ?? []) {
                if !selectedSensorIDs.contains(sensor.persistentModelID) {
                    sensor.player = nil
                }
            }
            
            // Prirazeni nove vybranych senzoru
            for sensor in selectedSensors {
                sensor.player = player
            }
            player.sensors = selectedSensors
        } else {
            let newPlayer = Player(
                name: name,
                jerseyNumber: selectedNumber
            )
            modelContext.insert(newPlayer)
            for sensor in selectedSensors {
                sensor.player = newPlayer
            }
            newPlayer.sensors = selectedSensors
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
    AddPlayerForm()
        .modelContainer(for: [
            Player.self,
            PlayerGroup.self,
            Sensor.self
        ], inMemory: true)
        .environment(ErrorRouter())
        .tint(Color(.orange))
}
