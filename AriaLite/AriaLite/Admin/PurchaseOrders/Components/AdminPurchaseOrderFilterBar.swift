//
//  AdminPurchaseOrderFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La fila di filtri sopra la lista: stato e fornitore (menu) e "Clear" quando c'è qualcosa di attivo.
//  Scorre in orizzontale se non ci sta.
//

import SwiftUI

struct AdminPurchaseOrderFilterBar: View {
    let viewModel: AdminPurchaseOrdersViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusMenu
                vendorMenu
                if viewModel.hasActiveFilters {
                    Button {
                        withAnimation(.snappy) { viewModel.clearFilters() }
                    } label: {
                        AdminPurchaseOrderFilterChip(title: String(localized: "Clear"), systemImage: "xmark",
                                                     tint: .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private var statusMenu: some View {
        Menu {
            Picker("Status", selection: Binding(get: { viewModel.statusFilter },
                                                set: { viewModel.selectStatus($0) })) {
                Text("All statuses").tag(AdminPurchaseOrderStatus?.none)
                ForEach(viewModel.statusOptions, id: \.self) { status in
                    Label(status.label, systemImage: status.systemImage).tag(Optional(status))
                }
            }
        } label: {
            AdminPurchaseOrderFilterChip(title: viewModel.statusFilterTitle,
                                         isSelected: viewModel.statusFilter != nil, showsMenuIndicator: true)
        }
        .buttonStyle(.plain)
    }

    private var vendorMenu: some View {
        Menu {
            Picker("Vendor", selection: Binding(get: { viewModel.vendorFilter },
                                                set: { viewModel.selectVendor($0) })) {
                Text("All vendors").tag(String?.none)
                ForEach(viewModel.vendorOptions) { vendor in
                    Text(verbatim: vendor.name).tag(Optional(vendor.id))
                }
            }
        } label: {
            AdminPurchaseOrderFilterChip(title: viewModel.vendorFilterTitle,
                                         isSelected: viewModel.vendorFilter != nil, showsMenuIndicator: true)
        }
        .buttonStyle(.plain)
    }
}
