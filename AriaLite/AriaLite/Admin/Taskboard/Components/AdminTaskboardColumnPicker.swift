//
//  AdminTaskboardColumnPicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il selettore di colonna su telefono: una chip per stato con il conteggio, nel colore dello stato.
//  Le chip scorrono in orizzontale (va bene per i filtri); le card sotto no. In kanban le chip accolgono
//  anche le card trascinate: su telefono le colonne lontane non sono a schermo, le chip sì.
//

import SwiftUI

struct AdminTaskboardColumnPicker: View {
    let columns: [AdminWorkOrderStatus]
    @Binding var selection: AdminWorkOrderStatus
    let count: (AdminWorkOrderStatus) -> Int
    /// Le card lasciate su una chip (solo in kanban); `false` se lo spostamento non è permesso.
    var onDrop: ((AdminWorkOrderStatus, [String]) -> Bool)?

    @State private var targeted: AdminWorkOrderStatus?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(columns, id: \.self) { status in
                        droppable(chip(status), on: status).id(status)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            .onChange(of: selection) { _, status in
                withAnimation { proxy.scrollTo(status, anchor: .center) }
            }
            .animation(.snappy(duration: 0.2), value: targeted)
        }
    }

    @ViewBuilder
    private func droppable(_ chip: some View, on status: AdminWorkOrderStatus) -> some View {
        if let onDrop {
            chip.dropDestination(for: String.self) { ids, _ in
                onDrop(status, ids)
            } isTargeted: { isOn in
                if isOn { targeted = status } else if targeted == status { targeted = nil }
            }
        } else {
            chip
        }
    }

    private func chip(_ status: AdminWorkOrderStatus) -> some View {
        let isOn = selection == status || targeted == status
        return Button {
            selection = status
        } label: {
            HStack(spacing: 6) {
                Text(status.localized).fontWeight(.semibold)
                Text(count(status), format: .number)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(status.tint.opacity(isOn ? 0.25 : 0.14), in: Capsule())
            }
            .font(.footnote)
            .foregroundStyle(isOn ? status.tint : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), tint: isOn ? status.tint.opacity(0.14) : nil)
            .overlay { Capsule().strokeBorder(status.tint.opacity(targeted == status ? 0.6 : 0), lineWidth: 2) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
