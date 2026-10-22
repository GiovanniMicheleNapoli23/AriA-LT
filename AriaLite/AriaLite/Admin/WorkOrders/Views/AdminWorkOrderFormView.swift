//
//  AdminWorkOrderFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La modifica di un ordine in uno sheet, in sezioni strette: tutti i campi insieme. La creazione è a passi
//  (AdminWorkOrderCreateView). Controlli, scelte e salvataggio stanno in AdminWorkOrderFormViewModel; qui solo
//  i campi, il fuoco e la chiusura.
//

import SwiftUI

struct AdminWorkOrderFormView: View {
    @Bindable var viewModel: AdminWorkOrderFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field: Hashable { case title, description, category, minutes, requester, notes, resolution }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                generalSection
                classificationSection
                placeSection
                assignmentSection
                scheduleSection
                notesSection
            }
            .listSectionSpacing(.compact)
            .environment(\.defaultMinListRowHeight, 38)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            focused = nil
                            Task { if await viewModel.save() { dismiss() } }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .task { await viewModel.loadChoices() }
        }
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
    }

    // MARK: Sezioni

    private var generalSection: some View {
        Section {
            TextField("Title", text: $viewModel.draft.title, axis: .vertical)
                .font(.body.weight(.semibold))
                .focused($focused, equals: .title)
            TextField("Description", text: $viewModel.draft.description, axis: .vertical)
                .lineLimit(2...8)
                .focused($focused, equals: .description)
        } footer: {
            if let message = viewModel.validationMessage {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private var classificationSection: some View {
        Section {
            segmentedRow("Priority", selection: $viewModel.draft.priority, options: AdminWorkOrderPriority.known) { $0.localized }
            segmentedRow("Type", selection: $viewModel.draft.type, options: AdminWorkOrderType.known) { $0.localized }
            Picker("Status", selection: $viewModel.draft.status) {
                ForEach(AdminWorkOrderStatus.known, id: \.self) { Text($0.localized).tag($0) }
            }
            TextField("Category", text: $viewModel.draft.category)
                .focused($focused, equals: .category)
        }
    }

    private var placeSection: some View {
        Section {
            if viewModel.plants.isEmpty {
                LabeledContent("Plant", value: viewModel.plantLabel)
            } else {
                Picker("Plant", selection: $viewModel.draft.plantId) {
                    if viewModel.draft.plantId == nil { Text("None").tag(String?.none) }
                    ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            AdminWorkOrderFormChoiceLink(title: "Asset", value: viewModel.assetLabel,
                                         unavailable: viewModel.assetsUnavailable) {
                AdminWorkOrderChoiceList(title: String(localized: "Asset"), choices: viewModel.assetChoices,
                                         selection: viewModel.draft.assetTag, onSelect: viewModel.selectAsset)
            }
        }
    }

    private var assignmentSection: some View {
        Section {
            AdminWorkOrderFormChoiceLink(title: "Assignee", value: viewModel.userLabel,
                                         unavailable: viewModel.usersUnavailable,
                                         availability: viewModel.assigneeAvailability) {
                AdminWorkOrderFormAssigneeList(operators: viewModel.assigneeOperators, users: viewModel.assigneeUsers,
                                               selection: viewModel.draft.assignedUserId, onSelect: viewModel.selectUser)
            }
            AdminWorkOrderFormChoiceLink(title: "Team", value: viewModel.teamLabel,
                                         unavailable: viewModel.teamsUnavailable) {
                AdminWorkOrderChoiceList(title: String(localized: "Team"), choices: viewModel.teamChoices,
                                         selection: viewModel.draft.teamId, onSelect: viewModel.selectTeam)
            }
            AdminWorkOrderFormTextRow(title: "Requested by", text: $viewModel.draft.requestedBy,
                                      focus: $focused, field: .requester)
        }
    }

    private var scheduleSection: some View {
        Section {
            AdminWorkOrderFormDateRow(title: "Scheduled", isOn: $viewModel.draft.hasScheduledDate,
                                      date: $viewModel.draft.scheduledDate)
            AdminWorkOrderFormDateRow(title: "Due", isOn: $viewModel.draft.hasDueDate, date: $viewModel.draft.dueDate)
            AdminWorkOrderFormDurationRow(minutes: $viewModel.draft.estimatedMinutes, hint: viewModel.durationHint,
                                          focus: $focused, field: .minutes)
        }
    }

    private var notesSection: some View {
        Section {
            TextField("Notes", text: $viewModel.draft.notes, axis: .vertical)
                .lineLimit(1...6)
                .focused($focused, equals: .notes)
            TextField("Resolution notes", text: $viewModel.draft.resolutionNotes, axis: .vertical)
                .lineLimit(1...6)
                .focused($focused, equals: .resolution)
        }
    }

    // MARK: Righe

    /// Etichetta a sinistra e scelta segmentata: una riga per priorità e tipo.
    private func segmentedRow<Value: Hashable>(_ title: LocalizedStringKey, selection: Binding<Value>, options: [Value],
                                               label: @escaping (Value) -> String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
