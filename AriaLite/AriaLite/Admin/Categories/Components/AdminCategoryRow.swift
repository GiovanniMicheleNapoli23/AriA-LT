//
//  AdminCategoryRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della lista: pallino del colore, icona, nome, descrizione, tipo e stabilimento.
//

import SwiftUI

struct AdminCategoryRow: View {
    let category: AdminCategory
    let plantName: String?

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: AdminCategoryIcon.symbolName(for: category.icon))
                .font(.body)
                .foregroundStyle(dotColor)
                .frame(width: iconSize, height: iconSize)
                .background(dotColor.opacity(0.12), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let description = category.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(category.entityTypeLabel)
                    if let plantName {
                        Text("·")
                        Text(plantName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// Il colore della categoria, o il colore secondario se non è leggibile.
    private var dotColor: Color {
        AdminCategoryColor.color(from: category.color) ?? .secondary
    }
}
