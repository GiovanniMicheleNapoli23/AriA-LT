//
//  AdminPurchaseOrderLineRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga dell'ordine: nome o codice del ricambio, note, quantità × costo unitario e totale di riga. Con le righe modificabili c'è il pulsante per toglierla (anche dal menu contestuale), che mostra il progresso mentre la chiamata gira.
//

import SwiftUI

struct AdminPurchaseOrderLineRow: View {
    let line: AdminPurchaseOrderDetailLine
    let canRemove: Bool
    let isRemoving: Bool
    let isDisabled: Bool
    let onRemove: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            details
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            trailing
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isRemoving ? 0.5 : 1)
        .contentShape(Rectangle())
        .contextMenu {
            if canRemove {
                Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
                    .disabled(isDisabled)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: line.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let code = line.code {
                Text(verbatim: code)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: quantityText)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let notes = line.notes {
                Text(verbatim: notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var quantityText: String {
        guard let unitCost = line.unitCost else { return line.quantity }
        return "\(line.quantity) × \(unitCost)"
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            if let total = line.total {
                Text(verbatim: total)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            if canRemove {
                if isRemoving {
                    ProgressView().controlSize(.small)
                } else {
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove", systemImage: "trash").labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isDisabled)
                }
            }
        }
    }
}
