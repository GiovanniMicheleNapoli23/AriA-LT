//
//  AdminInspectionFormItemRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della checklist nel form: il testo del controllo e tre pulsanti espliciti (su, giù, togli).
//  Niente swipe: il form è una scroll view, non una lista.
//

import SwiftUI

struct AdminInspectionFormItemRow: View {
    let number: Int
    @Binding var item: AdminInspectionFormItem
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isDisabled: Bool
    var focus: FocusState<String?>.Binding
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20)
                    .padding(.top, 12)
                TextField("Check description", text: $item.description, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.subheadline)
                    .focused(focus, equals: item.id)
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Move up", systemImage: "arrow.up", action: onMoveUp)
                    .disabled(!canMoveUp || isDisabled)
                Button("Move down", systemImage: "arrow.down", action: onMoveDown)
                    .disabled(!canMoveDown || isDisabled)
                Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
                    .disabled(isDisabled)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Color.liteAccent)
        }
    }
}
