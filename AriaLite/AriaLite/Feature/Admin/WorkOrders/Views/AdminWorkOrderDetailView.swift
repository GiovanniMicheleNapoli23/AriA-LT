//
//  AdminWorkOrderDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ordine per l'admin: intestazione, testi, assegnazione, date, dettagli, costi e la
//  procedura in sola lettura. Dal menu in alto si modifica o si elimina (con conferma).
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let message = viewModel.errorMessage { errorCard(message) }
                ForEach(viewModel.textBlocks) { AdminWorkOrderTextCard(block: $0) }
                ForEach(viewModel.fieldGroups) { AdminWorkOrderFieldCard(group: $0) }
                procedure
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Work Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { actions }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editForm) { form in
            AdminWorkOrderFormView(viewModel: form)
        }
        .confirmationDialog("Delete this work order?", isPresented: $viewModel.isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
        } message: {
            Text("It will be removed for everyone. This can't be undone.")
        }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { dismiss() }
        }
        .disabled(viewModel.isDeleting)
    }

    // MARK: Intestazione

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let status = viewModel.status { AdminWorkOrderStatusBadge(status: status) }
                if let priority = viewModel.priority { AdminWorkOrderPriorityBadge(priority: priority) }
                if let type = viewModel.typeLabel {
                    Text(type).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if viewModel.isLoading || viewModel.isDeleting { ProgressView().controlSize(.small) }
            }
            Text(viewModel.order.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if !viewModel.place.isEmpty {
                Label(viewModel.place, systemImage: "gearshape.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let due = viewModel.dueLabel {
                Label(due, systemImage: viewModel.isOverdue ? "exclamationmark.clock.fill" : "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.isOverdue ? Color.red : Color.secondary)
            }
        }
    }

    private var actions: some View {
        Menu {
            Button("Edit", systemImage: "pencil") { viewModel.startEditing() }
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.confirmDelete() }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
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
        if !viewModel.steps.isEmpty {
            AdminWorkOrderStepsCard(steps: viewModel.steps, progress: viewModel.progress)
        } else if viewModel.isLoadingSteps {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
        } else {
            Label("This work order has no procedure steps.", systemImage: "list.bullet.clipboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
