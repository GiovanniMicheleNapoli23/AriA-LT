//
//  AdminTaskboardColumnPicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il selettore di colonna su telefono: una chip per stato con il conteggio, nel colore dello stato.
//  Le chip scorrono in orizzontale (va bene per i filtri); le card sotto no.
//

import SwiftUI

struct AdminTaskboardColumnPicker: View {
    let columns: [AdminWorkOrderStatus]
    @Binding var selection: AdminWorkOrderStatus
    let count: (AdminWorkOrderStatus) -> Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(columns, id: \.self) { status in
                        chip(status).id(status)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            .onChange(of: selection) { _, status in
                withAnimation { proxy.scrollTo(status, anchor: .center) }
            }
        }
    }

    private func chip(_ status: AdminWorkOrderStatus) -> some View {
        let isOn = selection == status
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
