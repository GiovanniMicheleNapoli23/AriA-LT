//
//  AdminWorkOrderCreateStepPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una pagina della creazione a passi: pochi campi per volta, in un Form che scorre da solo. L'avviso
//  "Filled by AI" con Undo sta in cima a ogni pagina: l'AI riempie anche campi delle pagine dopo la prima.
//

import SwiftUI

/// I campi di testo della creazione, per il fuoco condiviso tra le pagine.
enum AdminWorkOrderCreateField: Hashable {
    case title, description, category, zone, alarm, requester, minutes, notes
    case step(UUID)
}

struct AdminWorkOrderCreateStepPage: View {
    let step: AdminWorkOrderFormStep
    @Bindable var viewModel: AdminWorkOrderFormViewModel
    let focused: FocusState<AdminWorkOrderCreateField?>.Binding

    var body: some View {
        Form {
            if step != .details, let notice = viewModel.aiNotice {
                Section { AdminWorkOrderFormAINotice(notice: notice, onUndo: viewModel.undoAIDraft) }
            }
            switch step {
            case .details: details
            case .procedure: procedure
            case .classification: classification
            case .location: location
            case .assignment: assignment
            case .review: review
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Pagine

    @ViewBuilder
    private var details: some View {
        Section("Title") {
            TextField("Title", text: $viewModel.draft.title, prompt: Text("e.g. Pump P-101 is leaking"), axis: .vertical)
                .font(.title3.weight(.semibold))
                .lineLimit(1...4)
                .focused(focused, equals: .title)
        }
        Section("Description") {
            TextField("Description", text: $viewModel.draft.description,
                      prompt: Text("What happened, what to check, anything useful"), axis: .vertical)
                .lineLimit(4...12)
                .focused(focused, equals: .description)
        }
        Section {
            AdminWorkOrderFormAIButton(title: "Draft with Aria", hint: "Fills in the other fields from the title",
                                       action: .completeDraft, viewModel: viewModel) { focused.wrappedValue = nil }
            AdminWorkOrderFormAIFeedback(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var procedure: some View {
        Section {
            ForEach($viewModel.draft.steps) { $step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: "\(viewModel.procedureStepNumber(step.id)).")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                    TextField("Describe the step", text: $step.text, axis: .vertical)
                        .focused(focused, equals: .step(step.id))
                }
            }
            .onDelete(perform: viewModel.deleteProcedureSteps)
            .onMove(perform: viewModel.moveProcedureSteps)
            Button {
                focused.wrappedValue = .step(viewModel.addProcedureStep())
            } label: {
                Label("Add step", systemImage: "plus.circle.fill")
            }
        } footer: {
            if viewModel.draft.steps.isEmpty {
                Text("Optional. The operator follows them one at a time.")
            } else {
                Text("Hold and drag to reorder, swipe to delete.")
            }
        }
        Section {
            AdminWorkOrderFormAIButton(title: "Suggest steps with Aria",
                                       hint: "Writes the procedure from the title and description",
                                       action: .generateSteps, viewModel: viewModel) { focused.wrappedValue = nil }
            AdminWorkOrderFormAIFeedback(viewModel: viewModel, showsNotice: false)
        }
        extras("Safety", items: viewModel.draft.safetyWarnings, onDelete: viewModel.deleteSafetyWarnings)
        extras("Tools", items: viewModel.draft.toolsNeeded, onDelete: viewModel.deleteToolsNeeded)
        extras("Parts", items: viewModel.draft.partsNeeded, onDelete: viewModel.deletePartsNeeded)
    }

    /// Sicurezza, attrezzi e ricambi proposti dall'AI: si leggono e si tolgono, vanno con i passi.
    @ViewBuilder
    private func extras(_ title: LocalizedStringKey, items: [String], onDelete: @escaping (IndexSet) -> Void) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item).font(.subheadline)
                }
                .onDelete(perform: onDelete)
            }
        }
    }

    @ViewBuilder
    private var classification: some View {
        Section("Priority") {
            AdminWorkOrderFormOptionTiles(options: AdminWorkOrderPriority.known, selection: $viewModel.draft.priority,
                                          title: \.localized, systemImage: \.systemImage, tint: \.tint)
                .tileRow()
        }
        Section("Type") {
            AdminWorkOrderFormOptionTiles(options: AdminWorkOrderType.known, selection: $viewModel.draft.type,
                                          title: \.localized, systemImage: \.systemImage, tint: { _ in Color.liteAccent })
                .tileRow()
        }
        Section {
            Picker("Status", selection: $viewModel.draft.status) {
                ForEach(AdminWorkOrderStatus.known, id: \.self) { Label($0.localized, systemImage: $0.systemImage).tag($0) }
            }
            AdminWorkOrderFormTextRow(title: "Category", text: $viewModel.draft.category, focus: focused, field: .category)
        }
    }

    @ViewBuilder
    private var location: some View {
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
        } footer: {
            Text("Choosing an asset fills in its zone.")
        }
        Section {
            AdminWorkOrderFormTextRow(title: "Zone", text: $viewModel.draft.zone, focus: focused, field: .zone)
            AdminWorkOrderFormTextRow(title: "Alarm code", text: $viewModel.draft.alarmCode, focus: focused, field: .alarm)
        }
    }

    @ViewBuilder
    private var assignment: some View {
        Section("Who") {
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
                                      focus: focused, field: .requester)
        }
        Section("When") {
            AdminWorkOrderFormDateRow(title: "Scheduled", isOn: $viewModel.draft.hasScheduledDate,
                                      date: $viewModel.draft.scheduledDate)
            AdminWorkOrderFormDateRow(title: "Due", isOn: $viewModel.draft.hasDueDate, date: $viewModel.draft.dueDate)
            AdminWorkOrderFormDurationRow(minutes: $viewModel.draft.estimatedMinutes, hint: viewModel.durationHint,
                                          focus: focused, field: .minutes)
        }
    }

    @ViewBuilder
    private var review: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        ForEach(viewModel.summary) { group in
            AdminWorkOrderFormSummarySection(group: group) { viewModel.go(to: group.step) }
        }
        Section("Notes") {
            TextField("Notes", text: $viewModel.draft.notes, prompt: Text("Anything else the technician should know"),
                      axis: .vertical)
                .lineLimit(3...8)
                .focused(focused, equals: .notes)
        }
    }
}

private extension View {
    /// Le tessere stanno sullo sfondo del Form, senza la cella bianca intorno.
    /// Un po' di margine dentro la riga: la cella del Form taglia ciò che esce dai suoi angoli arrotondati,
    /// e a margine zero si mangiava il bordo delle tessere agli estremi.
    func tileRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
    }
}
