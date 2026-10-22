//
//  AdminWorkOrderDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ordine per l'admin, compatto: intestazione con il pulsante di stato, l'assistente di
//  Aria come pulsante flottante in basso a destra, le schede come chip (panoramica, passi, attività, costi,
//  file). Dal menu in alto si modifica, si assegna in automatico, si traducono i testi o si elimina (con
//  conferma). I passi si spuntano e si refertano.
//

import SwiftUI

struct AdminWorkOrderDetailView: View {
    @State private var viewModel: AdminWorkOrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    /// Il view model nasce una volta: le init successive della vista non lo sostituiscono.
    init(viewModel: AdminWorkOrderDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var stepActions = viewModel.stepActions
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                AdminWorkOrderDetailHeader(viewModel: viewModel)
                if let message = viewModel.errorMessage { errorCard(message) }
                AdminWorkOrderTabBar(selection: $viewModel.tab)
                tabContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .ariaReadableWidth()
        }
        // Spazio sotto l'ultimo contenuto: il pulsante di Aria non copre niente.
        .contentMargins(.bottom, 96, for: .scrollContent)
        .overlay(alignment: .bottomTrailing) {
            AdminWorkOrderAssistantButton { viewModel.openAssistant() }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
        }
        .liteBackground()
        .navigationTitle("Work Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { actions }
        }
        .sheet(item: $viewModel.assistant) { assistant in
            AdminWorkOrderAssistantSheet(viewModel: assistant)
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editForm) { form in
            AdminWorkOrderFormView(viewModel: form)
        }
        .sheet(item: $stepActions.report) { report in
            AdminWorkOrderStepReportSheet(viewModel: report)
        }
        .adminWorkOrderQuickActions(viewModel.actions)
        .confirmationDialog("Delete this work order?", isPresented: $viewModel.isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
        } message: {
            Text("It will be removed for everyone. This can't be undone.")
        }
        .confirmationDialog("Clear this step's result?", isPresented: $stepActions.isConfirmingClear,
                            titleVisibility: .visible) {
            Button("Clear result", role: .destructive) { stepActions.clear() }
        } message: {
            Text("The note and photos of this step are removed too.")
        }
        .confirmationDialog("Reset all checks?", isPresented: $stepActions.isConfirmingReset,
                            titleVisibility: .visible) {
            Button("Reset all checks", role: .destructive) { Task { await stepActions.resetAll() } }
        } message: {
            Text("Every step goes back to unchecked.")
        }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { dismiss() }
        }
        .disabled(viewModel.isDeleting)
    }

    // MARK: Menu

    /// Le azioni con icona e testo, in fondo e da sola l'eliminazione. Lo stato si cambia dal pulsante
    /// nell'intestazione, l'assistente dal pulsante flottante.
    private var actions: some View {
        Menu {
            Button("Edit", systemImage: "pencil") { viewModel.startEditing() }
            Menu {
                ForEach(viewModel.translationLanguages, id: \.code) { language in
                    Button(language.name) { Task { await viewModel.translate(to: language.code) } }
                }
            } label: {
                Label("Translate", systemImage: "translate")
            }
            .disabled(viewModel.isTranslating)
            Button("Auto-assign", systemImage: "person.crop.circle.badge.checkmark") {
                Task { await viewModel.autoAssign() }
            }
            .disabled(viewModel.isChangingStatus || viewModel.order.isClosed)

            if viewModel.translation != nil {
                Button("Show original", systemImage: "arrow.uturn.backward") { viewModel.clearTranslation() }
            }

            Section {
                Button("Delete", systemImage: "trash", role: .destructive) { viewModel.confirmDelete() }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
    }

    // MARK: Schede

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.tab {
        case .overview: overview
        case .steps: procedure
        case .activity: AdminWorkOrderActivityTab(viewModel: viewModel.activity)
        case .costs: AdminWorkOrderCostsTab(viewModel: viewModel.costs)
        case .files: AdminWorkOrderFilesTab(viewModel: viewModel.files)
        }
    }

    @ViewBuilder
    private var overview: some View {
        if viewModel.isTranslating {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Translating…").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        if let message = viewModel.translationError {
            Label(message, systemImage: "translate")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
        if let translation = viewModel.translation, !translation.isEmpty, let name = viewModel.translationLanguageName {
            AdminWorkOrderTranslationCard(translation: translation, languageName: name,
                                          onClose: viewModel.clearTranslation)
        }
        ForEach(viewModel.textBlocks) { AdminWorkOrderTextCard(block: $0) }
        ForEach(viewModel.fieldGroups) { AdminWorkOrderFieldCard(group: $0) }
    }

    // MARK: Procedura

    @ViewBuilder
    private var procedure: some View {
        if !viewModel.safetyWarnings.isEmpty {
            AdminWorkOrderSafetyCard(warnings: viewModel.safetyWarnings)
        }
        if !viewModel.resources.isEmpty {
            AdminWorkOrderListCard(sections: viewModel.resources)
        }
        if let message = viewModel.stepActions.errorMessage { errorCard(message) }
        if !viewModel.steps.isEmpty {
            AdminWorkOrderStepsCard(steps: viewModel.steps, progress: viewModel.progress,
                                    actions: viewModel.canEditSteps ? viewModel.stepActions : nil,
                                    canReset: viewModel.hasReportedSteps)
        } else if viewModel.isLoadingSteps {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
        } else {
            Label("This work order has no procedure steps.", systemImage: "list.bullet.clipboard")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .adminWorkOrderCard()
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
