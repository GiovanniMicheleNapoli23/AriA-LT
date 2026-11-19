//
//  AdminMaintenanceDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un piano, come /maintenance/{id} della web: intestazione (descrizione, stato, dove e la
//  programmazione), passi, ricambi, ordini di lavoro generati, allegati, storico e scheda. Il riquadro di
//  revisione solo per un piano da rivedere; le decisioni nella barra in basso (AdminReviewDecisionBar; Reject e
//  Unapprove chiedono conferma). In alto "Edit"; "Improve with AI" è il blob di Aria in basso a destra, come nel
//  dettaglio di un ordine.
//

import SwiftUI

struct AdminMaintenanceDetailView: View {
    @State private var viewModel: AdminMaintenanceDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var improveModel: AdminMaintenanceImproveViewModel?

    init(viewModel: AdminMaintenanceDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminMaintenanceHeader(plan: viewModel.plan, summary: viewModel.summaryLine, schedule: viewModel.scheduleRows)
                if let message = viewModel.planError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if viewModel.showsReviewNotice {
                    AdminReviewBanner(stage: viewModel.reviewStage, message: viewModel.reviewMessage)
                }
                AdminMaintenanceListCard(title: "Steps", systemImage: "checklist", items: viewModel.plan.tasks,
                                         emptyText: String(localized: "No steps yet."), numbered: true)
                if !viewModel.plan.spareParts.isEmpty {
                    AdminMaintenanceListCard(title: "Spare parts", systemImage: "shippingbox", items: viewModel.plan.spareParts,
                                             emptyText: "", numbered: false)
                }
                if viewModel.showsWorkOrders { AdminMaintenanceWorkOrdersCard(viewModel: viewModel) }
                if let files = viewModel.files { AdminMaintenanceFilesCard(viewModel: files) }
                if let history = viewModel.history { AdminMaintenanceHistoryCard(viewModel: history) }
                if !viewModel.detailFields.isEmpty { detailsCard }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        // Spazio sotto l'ultimo contenuto: il pulsante di Aria non copre niente.
        .contentMargins(.bottom, viewModel.canEdit ? 96 : 0, for: .scrollContent)
        .overlay(alignment: .bottomTrailing) {
            if viewModel.canEdit {
                AdminWorkOrderAssistantButton(label: "Improve with AI") { improveModel = viewModel.makeImproveViewModel() }
                    .padding(.trailing, 20)
                    .padding(.bottom, 12)
                    .ignoresSafeArea(.keyboard)
            }
        }
        .ariaBottomBar {
            if viewModel.showsReview {
                AdminReviewDecisionBar(actions: viewModel.reviewActions, running: viewModel.reviewing,
                                       error: viewModel.reviewError, perform: { viewModel.requestReview($0) })
            }
        }
        .liteBackground()
        // L'asset è già nell'intestazione: il titolo dice solo dove si è.
        .navigationTitle("Maintenance plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                    .disabled(!viewModel.canEdit)
            }
            if viewModel.canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isDeleting {
                        ProgressView()
                    } else {
                        Menu("More", systemImage: "ellipsis.circle") {
                            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.showsDeleteConfirmation = true }
                        }
                    }
                }
            }
        }
        .refreshable { await viewModel.reloadAll() }
        .task { await viewModel.load() }
        .sheet(isPresented: $isEditing) {
            AdminMaintenanceFormView(viewModel: viewModel.makeForm()) { viewModel.planSaved($0) }
        }
        .sheet(item: $improveModel) { model in
            AdminMaintenanceImproveView(viewModel: model)
        }
        .adminReviewConfirmation(isPresented: $viewModel.isConfirmingReview, action: viewModel.confirmingReview) { action in
            Task { await viewModel.review(action) }
        }
        .alert("Delete this plan?", isPresented: $viewModel.showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(viewModel.plan.name)” will be removed, with its history. This can't be undone.")
        }
        .alert("Couldn't delete the plan", isPresented: $viewModel.isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.deleteError ?? "")
        }
    }

    // MARK: Schede

    private var detailsCard: some View {
        AdminCard(title: "Details", systemImage: "info.circle") {
            let fields = viewModel.detailFields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }
}
