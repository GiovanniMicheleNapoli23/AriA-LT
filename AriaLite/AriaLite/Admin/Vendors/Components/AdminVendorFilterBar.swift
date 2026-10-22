//
//  AdminVendorFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La fila di filtri sopra la lista: "All" e un chip per ogni tipo presente. Scorre in orizzontale se non ci sta.
//

import SwiftUI

struct AdminVendorFilterBar: View {
    let viewModel: AdminVendorsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy) { viewModel.selectType(nil) }
                } label: {
                    AdminVendorFilterChip(title: String(localized: "All"), count: viewModel.vendors.count,
                                          isSelected: viewModel.typeFilter == nil)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.typeFilter == nil ? .isSelected : [])
                ForEach(viewModel.typeOptions) { option in
                    let isSelected = viewModel.typeFilter == option.key
                    Button {
                        withAnimation(.snappy) { viewModel.selectType(isSelected ? nil : option.key) }
                    } label: {
                        AdminVendorFilterChip(title: option.label, count: option.count, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}
