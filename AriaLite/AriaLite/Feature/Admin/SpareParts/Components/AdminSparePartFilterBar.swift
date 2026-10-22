//
//  AdminSparePartFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La fila di filtri sopra la lista: scorta bassa (con il conteggio), stato e categoria (menu con le
//  sole voci presenti), e "Clear" quando c'è qualcosa di attivo. Scorre in orizzontale se non ci sta.
//

import SwiftUI

struct AdminSparePartFilterBar: View {
    let viewModel: AdminSparePartsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                lowStockChip
                statusMenu
                categoryMenu
                if viewModel.hasActiveFilters {
                    Button {
                        withAnimation(.snappy) { viewModel.clearFilters() }
                    } label: {
                        AdminSparePartFilterChip(title: String(localized: "Clear"), systemImage: "xmark", tint: .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private var lowStockChip: some View {
        let title = viewModel.lowStockCount.map { String(localized: "Low stock (\($0))") } ?? String(localized: "Low stock")
        return Button {
            withAnimation(.snappy) { viewModel.toggleLowStock() }
        } label: {
            AdminSparePartFilterChip(title: title, systemImage: "exclamationmark.triangle",
                                     isSelected: viewModel.showLowStockOnly, tint: .red)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.showLowStockOnly ? .isSelected : [])
    }

    private var statusMenu: some View {
        Menu {
            Picker("Status", selection: Binding(get: { viewModel.statusFilter },
                                                set: { viewModel.selectStatus($0) })) {
                Text("All statuses").tag(AdminSparePartStatus?.none)
                ForEach(viewModel.statusOptions, id: \.self) { status in
                    Text(verbatim: status.localized).tag(Optional(status))
                }
            }
        } label: {
            AdminSparePartFilterChip(title: viewModel.statusFilter?.localized ?? String(localized: "Status"),
                                     isSelected: viewModel.statusFilter != nil, showsMenuIndicator: true)
        }
        .buttonStyle(.plain)
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: Binding(get: { viewModel.categoryFilter },
                                                  set: { viewModel.selectCategory($0) })) {
                Text("All categories").tag(AdminSparePartCategory?.none)
                ForEach(viewModel.categoryOptions, id: \.self) { category in
                    Text(verbatim: category.localized).tag(Optional(category))
                }
            }
        } label: {
            AdminSparePartFilterChip(title: viewModel.categoryFilter?.localized ?? String(localized: "Category"),
                                     isSelected: viewModel.categoryFilter != nil, showsMenuIndicator: true)
        }
        .buttonStyle(.plain)
    }
}
