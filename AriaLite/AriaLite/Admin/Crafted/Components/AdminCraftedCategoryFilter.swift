//
//  AdminCraftedCategoryFilter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il filtro per categoria di Crafted: "Tutti" e solo le categorie in cui sta qualcosa, ognuna col suo
//  conteggio sulla ricerca di adesso. I chip vanno a capo (niente scorrimento orizzontale).
//

import SwiftUI

struct AdminCraftedCategoryFilter: View {
    let chips: [AdminCraftedCategoryChip]
    let total: Int
    let selected: AdminCraftedCategory?
    let onSelect: (AdminCraftedCategory?) -> Void

    var body: some View {
        AdminMobileUserFlowLayout(spacing: 8) {
            chip(title: String(localized: "All"), systemImage: "square.grid.2x2", count: total, isSelected: selected == nil) {
                onSelect(nil)
            }
            ForEach(chips) { item in
                chip(title: item.category.label, systemImage: item.category.systemImage, count: item.count,
                     isSelected: selected == item.category) {
                    onSelect(item.category)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(title: String, systemImage: String, count: Int, isSelected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).accessibilityHidden(true)
                Text(title)
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.footnote.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.liteAccent : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), tint: isSelected ? Color.liteAccent.opacity(0.12) : nil)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
