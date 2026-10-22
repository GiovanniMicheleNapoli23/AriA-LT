//
//  AdminWorkflowDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un flusso: intestazione, passi del grafo (sola lettura) ed esito del controllo.
//  Le azioni stanno nel menu in alto: controlla, pubblica, modifica, duplica, versioni, archivia, elimina.
//

import SwiftUI

struct AdminWorkflowDetailView: View {
    @State private var viewModel: AdminWorkflowDetailViewModel

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminWorkflowDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let flow = viewModel.flow {
                content(flow)
            } else {
                ContentUnavailableView("Flow deleted", systemImage: "trash",
                                       description: Text("This flow is no longer in the company."))
            }
        }
        .liteBackground()
        .navigationTitle("Flow")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let flow = viewModel.flow {
                ToolbarItem(placement: .topBarTrailing) { actionsMenu(flow) }
            }
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .sheet(item: $viewModel.editForm) { form in
            AdminWorkflowFormView(viewModel: form) { viewModel.didUpdate($0) }
        }
        .sheet(isPresented: $viewModel.showsVersions, onDismiss: { viewModel.announceRestoredVersion() }) {
            AdminWorkflowVersionsView(viewModel: viewModel)
        }
        .confirmationDialog(viewModel.pendingConfirmation?.title ?? "", isPresented: $viewModel.showsConfirmation,
                            titleVisibility: .visible, presenting: viewModel.pendingConfirmation) { confirmation in
            Button(confirmation.actionTitle, role: confirmation.isDestructive ? .destructive : nil) {
                Task { await viewModel.confirm(confirmation) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .alert("Couldn't update the flow", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Done", isPresented: $viewModel.showsActionNotice) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionNotice ?? "")
        }
        // Eliminato: si torna alla lista.
        .onChange(of: viewModel.flow == nil) { _, deleted in
            if deleted { dismiss() }
        }
    }

    private func content(_ flow: AdminWorkflow) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminWorkflowHeaderCard(flow: flow, datesLine: viewModel.datesLine, stats: viewModel.stats)
                if viewModel.isBusy || viewModel.isValidating {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let validation = viewModel.validation {
                    AdminWorkflowValidationCard(validation: validation, nodeTitle: viewModel.nodeTitle)
                }
                AdminWorkflowStepsCard(steps: viewModel.steps)
            }
            .padding(20)
            .ariaReadableWidth()
        }
    }

    private func actionsMenu(_ flow: AdminWorkflow) -> some View {
        Menu("Actions", systemImage: "ellipsis") {
            Button("Check", systemImage: "checkmark.shield") { Task { await viewModel.validate() } }
            if viewModel.canPublish {
                Button("Publish", systemImage: "paperplane") { viewModel.askToPublish() }
            }
            Button("Versions", systemImage: "clock.arrow.circlepath") { viewModel.showVersions() }
            Divider()
            if viewModel.canEdit {
                Button("Edit", systemImage: "pencil") { viewModel.startEditing() }
            }
            Button("Duplicate", systemImage: "plus.square.on.square") { Task { await viewModel.duplicate() } }
            if flow.isArchived {
                Button("Unarchive", systemImage: "tray.and.arrow.up") { Task { await viewModel.unarchive() } }
            } else {
                Button("Archive", systemImage: "archivebox") { Task { await viewModel.archive() } }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askToDelete() }
        }
        .disabled(viewModel.isBusy)
    }
}
