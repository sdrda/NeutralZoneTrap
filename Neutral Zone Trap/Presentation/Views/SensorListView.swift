//
//  SensorListView.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

/// View se seznamem senzorů
struct SensorListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorRouter.self) private var errorRouter
    @Query(sort: \Sensor.hardwareId) private var sensors: [Sensor]

    @State private var showAddSheet = false
    @State private var sensorToEdit: Sensor? = nil
    @State private var searchText: String = ""

    var filteredSensors: [Sensor] {
        if searchText.isEmpty {
            return sensors
        } else {
            return sensors.filter {
                String($0.hardwareId).contains(searchText)
                || ($0.player?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sensors.isEmpty {
                    ContentUnavailableView(
                        "No Sensors",
                        systemImage: "sensor.fill",
                        description: Text("Add the first sensor using the + button")
                    )
                } else {
                    List {
                        ForEach(filteredSensors) { sensor in
                            Button {
                                sensorToEdit = sensor
                            } label: {
                                SensorRowView(sensor: sensor)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(sensor)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteSensors)
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle("Sensors")

            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Sensor", systemImage: "plus") {
                        showAddSheet = true
                    }
                    .labelStyle(.iconOnly)
                }

                #if os(iOS)
                if !sensors.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSensorForm()
        }
        .sheet(item: $sensorToEdit) { sensor in
            AddSensorForm(sensor: sensor)
        }
    }

    private func deleteSensors(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredSensors[index])
            }
            persistDeletion()
        }
    }

    private func delete(_ sensor: Sensor) {
        withAnimation {
            modelContext.delete(sensor)
            persistDeletion()
        }
    }

    private func persistDeletion() {
        do {
            try modelContext.save()
        } catch {
            errorRouter.report(RepositoryError.deleteFailed(underlying: error))
        }
    }
}

// MARK: - Řádek senzoru

private struct SensorRowView: View {
    let sensor: Sensor

    var isAssigned: Bool {
        sensor.player != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isAssigned ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isAssigned ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text("ID: \(sensor.hardwareId)")
                    .font(.body)
                    .fontWeight(.medium)
                    .monospacedDigit()

                if let player = sensor.player {
                    Text("\(player.name) #\(player.jerseyNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SensorListView()
        .modelContainer(for: [Sensor.self, Player.self], inMemory: true)
        .environment(ErrorRouter())
        .tint(.orange)
}
