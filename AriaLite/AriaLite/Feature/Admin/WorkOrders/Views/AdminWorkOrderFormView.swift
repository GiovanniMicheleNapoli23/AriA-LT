//
//  AdminWorkOrderFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form di un ordine in uno sheet: creazione e modifica. Controlli, scelte e salvataggio stanno in
//  AdminWorkOrderFormViewModel; qui solo i campi, il fuoco e la chiusura.
//

import SwiftUI

struct AdminWorkOrderFormView: View {
    @Bindable var viewModel: AdminWorkOrderFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field: Hashable { case title, description, category, zone, minutes, notes, resolution }

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
                .focused($focused, equals: .title)
                .submitLabel(.next)
            TextField("Description", text: $viewModel.draft.description, axis: .vertical)
                .lineLimit(3...8)
                .focused($focused, equals: .description)
        } footer: {
            if let message = viewModel.validationMessage {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private var classificationSection: some View {
        Section {
            Picker("Status", selection: $viewModel.draft.status) {
                ForEach(AdminWorkOrderStatus.known, id: \.self) { Text($0.localized).tag($0) }
            }
            Picker("Priority", selection: $viewModel.draft.priority) {
                ForEach(AdminWorkOrderPriority.known, id: \.self) { Text($0.localized).tag($0) }
            }
            Picker("Type", selection: $viewModel.draft.type) {
                ForEach(AdminWorkOrderType.known, id: \.self) { Text($0.localized).tag($0) }
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
            choiceLink("Asset", value: viewModel.assetLabel, unavailable: viewModel.assetsUnavailable) {
                AdminWorkOrderChoiceList(title: String(localized: "Asset"), choices: viewModel.assetChoices,
                                         selection: viewModel.draft.assetTag, onSelect: viewModel.selectAsset)
            }
            if viewModel.isCreating {
                TextField("Zone", text: $viewModel.draft.zone)
                    .focused($focused, equals: .zone)
            }
        }
    }

    private var assignmentSection: some View {
        Section("Assignment") {
            choiceLink("Assignee", value: viewModel.userLabel, unavailable: viewModel.usersUnavailable) {
                AdminWorkOrderChoiceList(title: String(localized: "Assignee"), choices: viewModel.userChoices,
                                         selection: viewModel.draft.assignedUserId, onSelect: viewModel.selectUser)
            }
            choiceLink("Team", value: viewModel.teamLabel, unavailable: viewModel.teamsUnavailable) {
                AdminWorkOrderChoiceList(title: String(localized: "Team"), choices: viewModel.teamChoices,
                                         selection: viewModel.draft.teamId, onSelect: viewModel.selectTeam)
            }
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Scheduled date", isOn: $viewModel.draft.hasScheduledDate.animation())
            if viewModel.draft.hasScheduledDate {
                DatePicker("Scheduled", selection: $viewModel.draft.scheduledDate)
            }
            Toggle("Due date", isOn: $viewModel.draft.hasDueDate.animation())
            if viewModel.draft.hasDueDate {
                DatePicker("Due", selection: $viewModel.draft.dueDate)
            }
            LabeledContent("Estimated duration") {
                HStack(spacing: 4) {
                    TextField("Minutes", text: $viewModel.draft.estimatedMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .minutes)
                    Text("min").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $viewModel.draft.notes, axis: .vertical)
                .lineLimit(2...6)
                .focused($focused, equals: .notes)
            if !viewModel.isCreating {
                TextField("Resolution notes", text: $viewModel.draft.resolutionNotes, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($focused, equals: .resolution)
            }
        }
    }

    // MARK: Scelte da elenco

    /// Una riga che apre l'elenco; se il ruolo non può leggerlo, il valore resta in sola lettura.
    @ViewBuilder
    private func choiceLink<Destination: View>(_ title: LocalizedStringKey, value: String, unavailable: Bool,
                                               @ViewBuilder destination: @escaping () -> Destination) -> some View {
        if unavailable {
            LabeledContent(title) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                    Text("Not available for your role").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        } else {
            NavigationLink(destination: destination) {
                LabeledContent(title, value: value)
            }
        }
    }
}
