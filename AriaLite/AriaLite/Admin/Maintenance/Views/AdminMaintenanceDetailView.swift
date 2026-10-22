//
//  AdminMaintenanceDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un piano, come /maintenance/{id} della web: intestazione, programmazione, passi, ricambi,
//  ordini di lavoro generati, allegati, storico e scheda. In alto "Improve with AI" e "Edit".
//

import SwiftUI

struct AdminMaintenanceDetailView: View {
    @State private var viewModel: AdminMaintenanceDetailViewModel

    @State private var isEditing = false
    @State private var improveModel: AdminMaintenanceImproveViewModel?

    init(viewModel: AdminMaintenanceDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminMaintenanceHeader(plan: viewModel.plan, place: viewModel.placeLine)
                if let message = viewModel.planError {
                    AdminSectionNotice(text: message, isError: true)
                }
                scheduleCard
                if let description = viewModel.plan.description { descriptionCard(description) }
                AdminMaintenanceListCard(title: "Steps", systemImage: "checklist", items: viewModel.plan.tasks,
                                         emptyText: String(localized: "No steps yet."), numbered: true)
                if !viewModel.plan.spareParts.isEmpty {
                    AdminMaintenanceListCard(title: "Spare parts", systemImage: "shippingbox", items: viewModel.plan.spareParts,
                                             emptyText: "", numbered: false)
                }
                AdminMaintenanceWorkOrdersCard(viewModel: viewModel)
                if let files = viewModel.files { AdminMaintenanceFilesCard(viewModel: files) }
                if let history = viewModel.history { AdminMaintenanceHistoryCard(viewModel: history) }
                detailsCard
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.plan.assetTag ?? String(localized: "Plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Improve with AI", systemImage: "sparkles") { improveModel = viewModel.makeImproveViewModel() }
                    .disabled(!viewModel.canEdit)
                Button("Edit") { isEditing = true }
                    .disabled(!viewModel.canEdit)
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
    }

    // MARK: Schede

    private var scheduleCard: some View {
        AdminCard(title: "Schedule", systemImage: "calendar.badge.clock") {
            let fields = viewModel.scheduleFields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }

    private func descriptionCard(_ text: String) -> some View {
        AdminCard(title: "Description", systemImage: "text.alignleft") {
            Text(text)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

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
