//
//  AddSensorForm.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

struct AddSensorForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorRouter.self) private var errorRouter
    @Query private var allSensors: [Sensor]

    var sensor: Sensor?

    @State private var hardwareIdText: String = ""

    private var parsedHardwareId: UInt64? {
        UInt64(hardwareIdText)
    }

    // Duplikatni UI kontrolujeme zde, nejlepsi by byl @Unique ochrana
    // ale to CloudKit nepovoluje
    private var isDuplicateHardwareId: Bool {
        guard let parsedHardwareId else { return false }
        return allSensors.contains { other in
            other.hardwareId == parsedHardwareId && other.id != sensor?.id
        }
    }

    var isFormValid: Bool {
        parsedHardwareId != nil && !isDuplicateHardwareId
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hardware ID") {
                    TextField("Hardware ID", text: $hardwareIdText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif

                    if !hardwareIdText.isEmpty && parsedHardwareId == nil {
                        Text("Enter a non-negative integer")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if isDuplicateHardwareId {
                        Text("A sensor with this hardware ID already exists")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let sensor, let player = sensor.player {
                    Section("Assigned Player") {
                        HStack {
                            Text("\(player.name) #\(player.jerseyNumber)")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(sensor == nil ? "Add Sensor" : "Edit Sensor")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            if let sensor {
                hardwareIdText = String(sensor.hardwareId)
            }
        }
    }

    private func save() {
        guard let hardwareId = parsedHardwareId else { return }

        if let sensor {
            sensor.hardwareId = hardwareId
        } else {
            let newSensor = Sensor(id: UUID(), hardwareId: hardwareId)
            modelContext.insert(newSensor)
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
    AddSensorForm()
        .modelContainer(for: [Sensor.self, Player.self], inMemory: true)
        .environment(ErrorRouter())
        .tint(.orange)
}
