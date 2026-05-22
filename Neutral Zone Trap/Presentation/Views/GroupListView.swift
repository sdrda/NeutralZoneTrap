//
//  GroupListView.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

/// View seznamu skupin
struct GroupListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorRouter.self) private var errorRouter
    @Query(sort: \PlayerGroup.name) private var groups: [PlayerGroup]

    @State private var showAddSheet = false
    @State private var groupToEdit: PlayerGroup? = nil
    @State private var searchText: String = ""

    var filteredGroups: [PlayerGroup] {
        if searchText.isEmpty {
            return groups
        } else {
            return groups.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.players ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "person.3.fill",
                        description: Text("Add the first group using the + button")
                    )
                } else {
                    List {
                        ForEach(filteredGroups) { group in
                            Button {
                                groupToEdit = group
                            } label: {
                                GroupRowView(group: group)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteGroups)
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle("Groups")

            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Group", systemImage: "plus") {
                        showAddSheet = true
                    }
                    .labelStyle(.iconOnly)
                }
                
                #if os(iOS)
                if !groups.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGroupForm()
        }
        .sheet(item: $groupToEdit) { group in
            AddGroupForm(group: group)
        }
    }

    private func deleteGroups(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredGroups[index])
            }
            do {
                try modelContext.save()
            } catch {
                errorRouter.report(RepositoryError.deleteFailed(underlying: error))
            }
        }
    }
}

private struct GroupRowView: View {
    let group: PlayerGroup

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color(from: group.colorHex))
                .frame(width: 44, height: 44)
                .overlay {
                    Text("\(group.players?.count ?? 0)")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name.isEmpty ? "Untitled" : group.name)
                    .font(.body)
                    .fontWeight(.medium)

                if (group.players ?? []).isEmpty {
                    Text("No players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text((group.players ?? []).map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func color(from hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return .orange }
        return Color(hex: hex)
    }
}

#Preview {
    GroupListView()
        .modelContainer(for: [Player.self, PlayerGroup.self, Sensor.self], inMemory: true)
        .environment(ErrorRouter())
        .tint(.orange)
}
