//
//  AdminCraftedExampleRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un esempio del composer: il tipo con la sua frase. Toccarlo la scrive nel campo.
//

import SwiftUI

struct AdminCraftedExampleRow: View {
    let example: AdminCraftedKind.Example
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 34

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: AdminCraftedKind.systemImage(example.kind))
                    .font(.subheadline)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AdminCraftedKind.label(example.kind))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(example.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
