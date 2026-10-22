//
//  AdminWorkOrderCostsTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Costi di un ordine: manodopera (/labor), ricambi usati (/parts-used) e costi aggiuntivi (/additional-costs).
//  In cima i totali, poi una scheda per sezione col "+" per aggiungere. Ogni riga ha il menu "…" (e lo
//  swipe dove il sistema lo consente) per eliminare, con conferma; un ricambio si tocca per modificarlo.
//  Tutta la logica è in AdminWorkOrderCostsViewModel.
//

import SwiftUI

struct AdminWorkOrderCostsTab: View {
    @Bindable var viewModel: AdminWorkOrderCostsViewModel

    init(viewModel: AdminWorkOrderCostsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content
            .task { await viewModel.loadIfNeeded() }
            .sheet(item: $viewModel.laborForm) { AdminWorkOrderLaborFormView(viewModel: $0) }
            .sheet(item: $viewModel.partForm) { AdminWorkOrderPartFormView(viewModel: $0) }
            .sheet(item: $viewModel.extraForm) { AdminWorkOrderCostExtraFormView(viewModel: $0) }
            .confirmationDialog("Delete this cost?", isPresented: $viewModel.isConfirmingDelete,
                                titleVisibility: .visible, presenting: viewModel.pendingDelete) { row in
                Button("Delete", role: .destructive) { Task { await viewModel.delete(row) } }
            } message: { row in
                Text("\(row.title) · \(row.amount) will be removed from this work order.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
        } else {
            sections
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminWorkOrderCostTotalsStrip(totals: viewModel.totals)
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            ForEach(AdminWorkOrderCostKind.allCases) { kind in
                let rows = viewModel.rows(kind)
                AdminWorkOrderCostSectionCard(kind: kind, subtotal: viewModel.subtotal(kind), isEmpty: rows.isEmpty,
                                              error: viewModel.sectionErrors[kind], canAdd: viewModel.canAdd(kind),
                                              onAdd: { viewModel.startAdding(kind) }) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider() }
                        costRow(row)
                    }
                }
            }
        }
        .modifier(AdminWorkOrderCostSwipeContainer())
    }

    private func costRow(_ row: AdminWorkOrderCostRowItem) -> some View {
        let isDeleting = viewModel.deletingIds.contains(row.id)
        return HStack(spacing: 4) {
            if row.isEditable {
                Button { viewModel.startEditing(row) } label: {
                    AdminWorkOrderCostRowView(item: row, isDeleting: isDeleting)
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            } else {
                AdminWorkOrderCostRowView(item: row, isDeleting: isDeleting)
            }
            Menu {
                rowActions(row)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Actions"))
            .disabled(isDeleting)
        }
        .contextMenu { rowActions(row) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.confirmDelete(row) }
        }
    }

    @ViewBuilder
    private func rowActions(_ row: AdminWorkOrderCostRowItem) -> some View {
        if row.isEditable {
            Button("Edit", systemImage: "pencil") { viewModel.startEditing(row) }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.confirmDelete(row) }
    }
}

/// Fuori da una List lo swipe delle righe funziona solo dentro un contenitore che lo gestisce (iOS 27).
private struct AdminWorkOrderCostSwipeContainer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
    }
}
