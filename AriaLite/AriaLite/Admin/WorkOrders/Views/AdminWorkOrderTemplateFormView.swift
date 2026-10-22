//
//  AdminWorkOrderTemplateFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form di un modello di ordine in uno sheet. I passi si aggiungono in fondo, si riordinano con
//  "Reorder" e si eliminano con lo swipe; i ricambi si scelgono dal magazzino con la quantità.
//  Controlli e salvataggio in AdminWorkOrderTemplateFormViewModel.
//

import SwiftUI

struct AdminWorkOrderTemplateFormView: View {
    @Bindable var viewModel: AdminWorkOrderTemplateFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?
    @State private var editMode: EditMode = .inactive

    private enum Field: Hashable { case title, description, category, zone, minutes, newStep, quantity }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
                generalSection
                classificationSection
                stepsSection
                partsSection
            }
            .environment(\.editMode, $editMode)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.loadChoices() }
        }
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
    }

    // MARK: Sezioni

    private var generalSection: some View {
        Section {
            TextField("Title", text: $viewModel.title, axis: .vertical)
                .focused($focused, equals: .title)
            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(2...6)
                .focused($focused, equals: .description)
        } footer: {
            if let message = viewModel.validationMessage, viewModel.hasChanges {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private var classificationSection: some View {
        Section {
            Picker("Type", selection: $viewModel.type) {
                ForEach(AdminWorkOrderType.known, id: \.self) { Text($0.localized).tag($0) }
            }
            Picker("Priority", selection: $viewModel.priority) {
                ForEach(AdminWorkOrderPriority.known, id: \.self) { Text($0.localized).tag($0) }
            }
            TextField("Category", text: $viewModel.category)
                .focused($focused, equals: .category)
            if viewModel.assetsUnavailable {
                LabeledContent("Asset", value: viewModel.assetLabel)
            } else {
                NavigationLink {
                    AdminWorkOrderChoiceList(title: String(localized: "Asset"), choices: viewModel.assetChoices,
                                             selection: viewModel.assetTag, onSelect: viewModel.selectAsset)
                } label: {
                    LabeledContent("Asset", value: viewModel.assetLabel)
                }
            }
            TextField("Zone", text: $viewModel.zone)
                .focused($focused, equals: .zone)
            LabeledContent("Estimated duration") {
                HStack(spacing: 4) {
                    TextField("Minutes", text: $viewModel.estimatedMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .minutes)
                    Text("min").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach($viewModel.steps) { $step in
                TextField("Step", text: $step.text, axis: .vertical)
            }
            .onMove(perform: viewModel.moveSteps)
            .onDelete(perform: viewModel.deleteSteps)
            HStack {
                TextField("Add a step", text: $viewModel.newStep, axis: .vertical)
                    .focused($focused, equals: .newStep)
                    .onSubmit(viewModel.addStep)
                Button("Add Step", systemImage: "plus.circle.fill", action: viewModel.addStep)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.liteAccent)
                    .disabled(!viewModel.canAddStep)
                    .buttonStyle(.borderless)
            }
        } header: {
            HStack {
                Text("Steps (\(viewModel.steps.count))")
                Spacer()
                if viewModel.steps.count > 1 {
                    Button(editMode.isEditing ? "Done" : "Reorder") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
    }

    private var partsSection: some View {
        Section("Parts") {
            ForEach(viewModel.parts) { part in
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.name)
                    let subtitle = viewModel.partSubtitle(part)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: viewModel.deleteParts)
            if !viewModel.partsUnavailable {
                LabeledContent("Quantity to add") {
                    TextField("1" as String, text: $viewModel.newPartQuantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .quantity)
                }
                NavigationLink {
                    AdminWorkOrderChoiceList(title: String(localized: "Part"), choices: viewModel.partChoices,
                                             selection: nil, onSelect: viewModel.addPart)
                } label: {
                    Label("Add Part", systemImage: "plus")
                }
            } else if viewModel.parts.isEmpty {
                Text("Spare parts aren't available for your role.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
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
}
